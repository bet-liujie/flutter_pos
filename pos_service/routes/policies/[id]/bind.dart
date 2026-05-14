import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context, String policyId) async {
  switch (context.request.method) {
    case HttpMethod.post:
      return _bindDevices(context, policyId);
    case HttpMethod.delete:
      return _unbindDevice(context, policyId);
    default:
      return Response(statusCode: 405, body: 'Method Not Allowed');
  }
}

/// POST /policies/[id]/bind - 绑定策略到设备
Future<Response> _bindDevices(RequestContext context, String policyId) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final id = int.tryParse(policyId);
    if (id == null) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '无效的策略ID'},
      );
    }

    final body = await context.request.json() as Map<String, dynamic>;
    final deviceIds = (body['device_ids'] as List?)?.map((e) => e.toString()).toList();

    if (deviceIds == null || deviceIds.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '缺少 device_ids 参数'},
      );
    }

    // 验证策略存在且属于当前商户
    final policyResult = await pool.execute(
      'SELECT id FROM device_policies WHERE id = \$1 AND merchant_id = \$2',
      parameters: [id, merchantId],
    );
    if (policyResult.isEmpty) {
      return Response.json(
        statusCode: 404,
        body: {'success': false, 'error': '策略不存在'},
      );
    }

    // 逐设备绑定（跳过已绑定的设备）
    var boundCount = 0;
    for (final deviceId in deviceIds) {
      try {
        // 检查是否已绑定
        final existing = await pool.execute(
          'SELECT id FROM policy_bindings WHERE policy_id = \$1 AND device_id = \$2',
          parameters: [id, deviceId],
        );
        if (existing.isNotEmpty) continue;

        await pool.execute(
          "INSERT INTO policy_bindings (policy_id, device_id, merchant_id, status) VALUES (\$1, \$2, \$3, 'pending')",
          parameters: [id, deviceId, merchantId],
        );
        boundCount++;
      } catch (_) {
        // 跳过不存在的设备
      }
    }

    return Response.json(body: {
      'success': true,
      'data': {'bound_count': boundCount, 'total': deviceIds.length},
      'message': '成功绑定 $boundCount/${deviceIds.length} 台设备',
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}

/// DELETE /policies/[id]/bind - 解绑策略与设备
Future<Response> _unbindDevice(RequestContext context, String policyId) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final id = int.tryParse(policyId);
    if (id == null) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '无效的策略ID'},
      );
    }

    final queryParams = context.request.uri.queryParameters;
    final deviceId = queryParams['device_id'];

    if (deviceId == null || deviceId.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '缺少 device_id 参数'},
      );
    }

    final result = await pool.execute(
      'DELETE FROM policy_bindings WHERE policy_id = \$1 AND device_id = \$2 AND merchant_id = \$3',
      parameters: [id, deviceId, merchantId],
    );

    if (result.affectedRows == 0) {
      return Response.json(
        statusCode: 404,
        body: {'success': false, 'error': '绑定关系不存在'},
      );
    }

    return Response.json(body: {
      'success': true,
      'message': '设备已解绑策略',
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
