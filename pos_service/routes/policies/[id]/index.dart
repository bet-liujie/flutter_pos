import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context, String policyId) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getPolicyDetail(context, policyId);
    case HttpMethod.put:
      return _updatePolicy(context, policyId);
    case HttpMethod.delete:
      return _deletePolicy(context, policyId);
    default:
      return Response(statusCode: 405, body: 'Method Not Allowed');
  }
}

/// GET /policies/[id] - 策略详情
Future<Response> _getPolicyDetail(RequestContext context, String policyId) async {
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

    final result = await pool.execute(
      'SELECT id, policy_name, policy_data, version, is_active, created_at, updated_at FROM device_policies WHERE id = \$1 AND merchant_id = \$2',
      parameters: [id, merchantId],
    );

    if (result.isEmpty) {
      return Response.json(
        statusCode: 404,
        body: {'success': false, 'error': '策略不存在'},
      );
    }

    final row = result[0];

    // 查询绑定的设备
    final bindResult = await pool.execute(
      'SELECT pb.device_id, d.status AS device_status, pb.status AS bind_status, pb.synced_at FROM policy_bindings pb LEFT JOIN devices d ON d.device_id = pb.device_id WHERE pb.policy_id = \$1 AND pb.merchant_id = \$2',
      parameters: [id, merchantId],
    );

    final boundDevices = bindResult.map((b) => {
      'device_id': b[0],
      'device_status': b[1],
      'bind_status': b[2],
      'synced_at': (b[3] as DateTime?)?.toUtc().toIso8601String(),
    }).toList();

    return Response.json(body: {
      'success': true,
      'data': {
        'id': row[0],
        'policy_name': row[1],
        'policy_data': row[2],
        'version': row[3],
        'is_active': row[4],
        'created_at': (row[5] as DateTime?)?.toUtc().toIso8601String(),
        'updated_at': (row[6] as DateTime?)?.toUtc().toIso8601String(),
        'bound_devices': boundDevices,
      },
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}

/// PUT /policies/[id] - 更新策略
Future<Response> _updatePolicy(RequestContext context, String policyId) async {
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
    final policyName = body['policy_name']?.toString();
    final policyData = body['policy_data'] as Map<String, dynamic>?;
    final isActive = body['is_active'] as bool?;

    // 构建动态更新
    final setClauses = <String>[];
    final params = <dynamic>[];
    var paramIndex = 1;

    if (policyName != null && policyName.isNotEmpty) {
      setClauses.add('policy_name = \$$paramIndex');
      params.add(policyName);
      paramIndex++;
    }
    if (policyData != null) {
      setClauses.add('policy_data = \$$paramIndex::jsonb');
      params.add(jsonEncode(policyData));
      paramIndex++;
    }
    if (isActive != null) {
      setClauses.add('is_active = \$$paramIndex');
      params.add(isActive);
      paramIndex++;
    }

    if (setClauses.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '没有要更新的字段'},
      );
    }

    setClauses.add('version = version + 1');
    setClauses.add("updated_at = CURRENT_TIMESTAMP");

    params.add(id);
    params.add(merchantId);

    final result = await pool.execute(
      'UPDATE device_policies SET ${setClauses.join(', ')} WHERE id = \$$paramIndex AND merchant_id = \$${paramIndex + 1} RETURNING id, policy_name, policy_data, version, is_active, updated_at',
      parameters: params,
    );

    if (result.isEmpty) {
      return Response.json(
        statusCode: 404,
        body: {'success': false, 'error': '策略不存在或无权操作'},
      );
    }

    final row = result[0];
    return Response.json(body: {
      'success': true,
      'data': {
        'id': row[0],
        'policy_name': row[1],
        'policy_data': row[2],
        'version': row[3],
        'is_active': row[4],
        'updated_at': (row[5] as DateTime?)?.toUtc().toIso8601String(),
      },
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}

/// DELETE /policies/[id] - 删除策略
Future<Response> _deletePolicy(RequestContext context, String policyId) async {
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

    // 先删除绑定关系（外键约束 ON DELETE CASCADE 会自动处理）
    await pool.execute(
      'DELETE FROM policy_bindings WHERE policy_id = \$1 AND merchant_id = \$2',
      parameters: [id, merchantId],
    );

    final result = await pool.execute(
      'DELETE FROM device_policies WHERE id = \$1 AND merchant_id = \$2',
      parameters: [id, merchantId],
    );

    if (result.affectedRows == 0) {
      return Response.json(
        statusCode: 404,
        body: {'success': false, 'error': '策略不存在或无权操作'},
      );
    }

    return Response.json(body: {
      'success': true,
      'message': '策略已删除',
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
