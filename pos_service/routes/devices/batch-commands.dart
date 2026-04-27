import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }
  return _batchCommand(context);
}

Future<Response> _batchCommand(RequestContext context) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final deviceIds = (body['device_ids'] as List).map((e) => e.toString()).toList();
    final command = body['command']?.toString();
    final params = body['params'] as Map<String, dynamic>? ?? {};

    if (deviceIds.isEmpty || command == null || command.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '缺少 device_ids 或 command 参数'},
      );
    }

    final insertedIds = <int>[];
    for (final deviceId in deviceIds) {
      final result = await pool.execute(
        'INSERT INTO command_queue (merchant_id, device_id, command, params) VALUES (\$1, \$2, \$3, \$4::jsonb) RETURNING id',
        parameters: [merchantId, deviceId, command, jsonEncode(params)],
      );
      insertedIds.add(result[0][0] as int);
    }

    return Response.json(body: {
      'success': true,
      'data': {'command_ids': insertedIds},
      'message': '批量命令已下发至 ${deviceIds.length} 台设备',
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
