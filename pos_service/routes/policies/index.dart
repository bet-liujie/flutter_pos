import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _listPolicies(context);
    case HttpMethod.post:
      return _createPolicy(context);
    default:
      return Response(statusCode: 405, body: 'Method Not Allowed');
  }
}

/// GET /policies - 获取策略列表
Future<Response> _listPolicies(RequestContext context) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final params = context.request.uri.queryParameters;
    final page = int.tryParse(params['page'] ?? '1') ?? 1;
    final pageSize = int.tryParse(params['page_size'] ?? '20') ?? 20;
    final offset = (page - 1) * pageSize;

    // 查询总数
    final countResult = await pool.execute(
      'SELECT COUNT(*) FROM device_policies WHERE merchant_id = \$1',
      parameters: [merchantId],
    );
    final total = countResult[0][0] as int;

    // 查询策略列表
    final result = await pool.execute(
      'SELECT id, policy_name, policy_data, version, is_active, created_at, updated_at FROM device_policies WHERE merchant_id = \$1 ORDER BY updated_at DESC LIMIT \$2 OFFSET \$3',
      parameters: [merchantId, pageSize, offset],
    );

    final policies = result.map((row) => {
      'id': row[0],
      'policy_name': row[1],
      'policy_data': row[2],
      'version': row[3],
      'is_active': row[4],
      'created_at': (row[5] as DateTime?)?.toUtc().toIso8601String(),
      'updated_at': (row[6] as DateTime?)?.toUtc().toIso8601String(),
    }).toList();

    return Response.json(body: {
      'success': true,
      'data': {
        'policies': policies,
        'total': total,
        'page': page,
        'page_size': pageSize,
      },
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}

/// POST /policies - 创建策略
Future<Response> _createPolicy(RequestContext context) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final policyName = body['policy_name']?.toString();

    if (policyName == null || policyName.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '策略名称不能为空'},
      );
    }

    final policyData = body['policy_data'] as Map<String, dynamic>? ?? {};
    final isActive = body['is_active'] as bool? ?? true;

    final result = await pool.execute(
      "INSERT INTO device_policies (merchant_id, policy_name, policy_data, is_active) VALUES (\$1, \$2, \$3::jsonb, \$4) RETURNING id, created_at",
      parameters: [merchantId, policyName, jsonEncode(policyData), isActive],
    );

    final id = result[0][0] as int;
    final createdAt = (result[0][1] as DateTime?)?.toUtc().toIso8601String();

    return Response.json(body: {
      'success': true,
      'data': {
        'id': id,
        'policy_name': policyName,
        'policy_data': policyData,
        'version': 1,
        'is_active': isActive,
        'created_at': createdAt,
      },
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
