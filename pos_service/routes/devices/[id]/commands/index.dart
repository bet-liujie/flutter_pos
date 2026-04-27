import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context, String deviceId) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _listCommands(context, deviceId);
    case HttpMethod.post:
      return _sendCommand(context, deviceId);
    default:
      return Response(statusCode: 405, body: 'Method Not Allowed');
  }
}

Future<Response> _listCommands(RequestContext context, String deviceId) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final result = await pool.execute(
      'SELECT id, command, params, status, created_at, sent_at, done_at, error_msg FROM command_queue WHERE device_id = \$1 AND merchant_id = \$2 ORDER BY created_at DESC LIMIT 50',
      parameters: [deviceId, merchantId],
    );

    final commands = result.map((row) => {
      'id': row[0],
      'command': row[1],
      'params': row[2],
      'status': row[3],
      'created_at': row[4].toString(),
      'sent_at': row[5]?.toString(),
      'done_at': row[6]?.toString(),
      'error_msg': row[7],
    }).toList();

    return Response.json(body: {'success': true, 'data': commands});
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}

Future<Response> _sendCommand(RequestContext context, String deviceId) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final command = body['command']?.toString();
    final params = body['params'] as Map<String, dynamic>? ?? {};

    if (command == null || command.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '缺少 command 参数'},
      );
    }

    final validCommands = [
      'lock_screen', 'unlock_screen', 'reboot',
      'enable_kiosk', 'disable_kiosk', 'disable_camera', 'enable_camera',
      'wipe_data', 'sync_policy', 'install_app', 'uninstall_app',
    ];

    if (!validCommands.contains(command)) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '无效的命令类型，有效值: ${validCommands.join(", ")}'},
      );
    }

    // 验证设备存在
    final deviceResult = await pool.execute(
      'SELECT 1 FROM devices WHERE device_id = \$1 AND merchant_id = \$2',
      parameters: [deviceId, merchantId],
    );

    if (deviceResult.isEmpty) {
      return Response.json(
        statusCode: 404,
        body: {'success': false, 'error': '设备不存在'},
      );
    }

    final result = await pool.execute(
      'INSERT INTO command_queue (merchant_id, device_id, command, params) VALUES (\$1, \$2, \$3, \$4::jsonb) RETURNING id',
      parameters: [merchantId, deviceId, command, jsonEncode(params)],
    );

    return Response.json(body: {
      'success': true,
      'data': {'command_id': result[0][0]},
      'message': '命令已下发',
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
