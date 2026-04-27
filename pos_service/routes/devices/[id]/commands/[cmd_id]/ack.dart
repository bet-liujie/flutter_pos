import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context, String deviceId, String cmdId) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }
  return _ackCommand(context, deviceId, cmdId);
}

Future<Response> _ackCommand(RequestContext context, String deviceId, String cmdId) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final status = body['status']?.toString();
    final errorMsg = body['error_msg']?.toString();

    if (status == null || !['completed', 'failed'].contains(status)) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '无效的状态值，有效值: completed, failed'},
      );
    }

    final cmdIdInt = int.tryParse(cmdId);
    if (cmdIdInt == null) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '无效的命令 ID'},
      );
    }

    final result = await pool.execute(
      'UPDATE command_queue SET status = \$1, done_at = CURRENT_TIMESTAMP, error_msg = \$2 WHERE id = \$3 AND device_id = \$4 AND merchant_id = \$5',
      parameters: [status, errorMsg, cmdIdInt, deviceId, merchantId],
    );

    if (result.affectedRows == 0) {
      return Response.json(
        statusCode: 404,
        body: {'success': false, 'error': '命令不存在或无权操作'},
      );
    }

    return Response.json(body: {'success': true, 'message': '命令状态已更新'});
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
