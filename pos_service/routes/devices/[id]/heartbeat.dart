import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context, String deviceId) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _pollDevice(context, deviceId);
    case HttpMethod.post:
      return _heartbeat(context, deviceId);
    default:
      return Response(statusCode: 405, body: 'Method Not Allowed');
  }
}

/// 设备轮询 - 返回待执行命令和待同步策略
Future<Response> _pollDevice(RequestContext context, String deviceId) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    // 查询待处理命令
    final commandsResult = await pool.execute(
      "SELECT id, command, params, created_at FROM command_queue WHERE device_id = \$1 AND merchant_id = \$2 AND status = 'pending' ORDER BY created_at ASC LIMIT 10",
      parameters: [deviceId, merchantId],
    );

    final commands = commandsResult.map((c) => {
      'id': c[0],
      'command': c[1],
      'params': c[2],
      'created_at': c[3].toString(),
    }).toList();

    // 标记为已发送
    if (commands.isNotEmpty) {
      final ids = commandsResult.map((c) => c[0] as int).toList();
      // postgres 3.x 不支持 ANY(\$1) 传数组，逐条更新
      for (final id in ids) {
        await pool.execute(
          "UPDATE command_queue SET status = 'sent', sent_at = CURRENT_TIMESTAMP WHERE id = \$1",
          parameters: [id],
        );
      }
    }

    // 查询待同步策略
    final policyResult = await pool.execute(
      'SELECT dp.id, dp.policy_name, dp.policy_data, dp.version FROM policy_bindings pb JOIN device_policies dp ON dp.id = pb.policy_id WHERE pb.device_id = \$1 AND pb.merchant_id = \$2 AND pb.status = \'pending\'',
      parameters: [deviceId, merchantId],
    );

    Map<String, dynamic>? pendingPolicy;
    if (policyResult.isNotEmpty) {
      final p = policyResult[0];
      pendingPolicy = {
        'id': p[0],
        'policy_name': p[1],
        'policy_data': p[2],
        'version': p[3],
      };
    }

    return Response.json(body: {
      'success': true,
      'data': {
        'commands': commands,
        'policy': pendingPolicy,
        'sync_at': DateTime.now().toIso8601String(),
      },
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}

/// 心跳上报 - 设备定时上报状态
Future<Response> _heartbeat(RequestContext context, String deviceId) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;

    await pool.execute(
      'INSERT INTO heartbeat_log (device_id, merchant_id, storage_usage, memory_usage, network_type, signal_strength, app_version, latitude, longitude) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9)',
      parameters: [
        deviceId,
        merchantId,
        body['storage_usage'],
        body['memory_usage'],
        body['network_type'],
        body['signal_strength'],
        body['app_version'],
        body['latitude'],
        body['longitude'],
      ],
    );

    // 更新或自动注册设备
    final updateResult = await pool.execute(
      'UPDATE devices SET last_active_at = CURRENT_TIMESTAMP WHERE device_id = \$1 AND merchant_id = \$2',
      parameters: [deviceId, merchantId],
    );

    if (updateResult.affectedRows == 0) {
      // 设备不存在，自动注册（降低测试门槛）
      await pool.execute(
        'INSERT INTO devices (device_id, merchant_id, status, last_active_at) VALUES (\$1, \$2, \'active\', CURRENT_TIMESTAMP) ON CONFLICT (device_id) DO UPDATE SET last_active_at = CURRENT_TIMESTAMP',
        parameters: [deviceId, merchantId],
      );
    }

    return Response.json(body: {
      'success': true,
      'message': '心跳上报成功',
      'server_time': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': '心跳处理异常: ${e.toString()}'},
    );
  }
}
