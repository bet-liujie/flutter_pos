import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context, String deviceId) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getDeviceDetail(context, deviceId);
    case HttpMethod.put:
      return _updateDevice(context, deviceId);
    case HttpMethod.delete:
      return _deleteDevice(context, deviceId);
    default:
      return Response(statusCode: 405, body: 'Method Not Allowed');
  }
}

Future<Response> _getDeviceDetail(RequestContext context, String deviceId) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final result = await pool.execute(
      'SELECT d.device_id, d.merchant_id, d.status, d.last_active_at FROM devices d WHERE d.device_id = \$1 AND d.merchant_id = \$2',
      parameters: [deviceId, merchantId],
    );

    if (result.isEmpty) {
      return Response.json(
        statusCode: 404,
        body: {'success': false, 'error': '设备不存在'},
      );
    }

    final row = result[0];

    // 查询绑定的策略
    final policiesResult = await pool.execute(
      'SELECT dp.id, dp.policy_name, dp.policy_data, dp.version, pb.status AS bind_status FROM policy_bindings pb JOIN device_policies dp ON dp.id = pb.policy_id WHERE pb.device_id = \$1 AND pb.merchant_id = \$2',
      parameters: [deviceId, merchantId],
    );

    final policies = policiesResult.map((p) => {
      'id': p[0],
      'policy_name': p[1],
      'policy_data': p[2],
      'version': p[3],
      'bind_status': p[4],
    }).toList();

    // 查询待处理命令
    final commandsResult = await pool.execute(
      "SELECT id, command, params, status, created_at FROM command_queue WHERE device_id = \$1 AND merchant_id = \$2 AND status IN ('pending', 'sent') ORDER BY created_at DESC LIMIT 10",
      parameters: [deviceId, merchantId],
    );

    final pendingCommands = commandsResult.map((c) => {
      'id': c[0],
      'command': c[1],
      'params': c[2],
      'status': c[3],
      'created_at': c[4].toString(),
    }).toList();

    return Response.json(body: {
      'success': true,
      'data': {
        'device_id': row[0],
        'merchant_id': row[1],
        'status': row[2],
        'last_active_at': row[3]?.toString(),
        'policies': policies,
        'pending_commands': pendingCommands,
      },
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}

Future<Response> _updateDevice(RequestContext context, String deviceId) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final newStatus = body['status']?.toString();

    if (newStatus == null) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '缺少 status 参数'},
      );
    }

    final validStatuses = ['active', 'suspended', 'lost', 'retired'];
    if (!validStatuses.contains(newStatus)) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '无效的状态值，有效值: ${validStatuses.join(", ")}'},
      );
    }

    final result = await pool.execute(
      'UPDATE devices SET status = \$1 WHERE device_id = \$2 AND merchant_id = \$3',
      parameters: [newStatus, deviceId, merchantId],
    );

    if (result.affectedRows == 0) {
      return Response.json(
        statusCode: 404,
        body: {'success': false, 'error': '设备不存在或无权操作'},
      );
    }

    return Response.json(body: {'success': true, 'message': '设备状态已更新'});
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}

Future<Response> _deleteDevice(RequestContext context, String deviceId) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    await pool.execute(
      'DELETE FROM policy_bindings WHERE device_id = \$1 AND merchant_id = \$2',
      parameters: [deviceId, merchantId],
    );

    final result = await pool.execute(
      'DELETE FROM devices WHERE device_id = \$1 AND merchant_id = \$2',
      parameters: [deviceId, merchantId],
    );

    if (result.affectedRows == 0) {
      return Response.json(
        statusCode: 404,
        body: {'success': false, 'error': '设备不存在或无权操作'},
      );
    }

    return Response.json(body: {'success': true, 'message': '设备已解绑'});
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
