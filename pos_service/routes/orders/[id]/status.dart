import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  // 只允许 PATCH 方法进行部分更新
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final pool = context.read<Pool>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final newStatus = body['status'] as String?;

    // 校验传入的状态是否在规定的 4 种状态内
    const validStatuses = ['pending', 'processing', 'completed', 'cancelled'];
    if (newStatus == null || !validStatuses.contains(newStatus)) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {
          'error': '无效的订单状态。允许的值: pending, processing, completed, cancelled',
        },
      );
    }

    return await pool.withConnection((connection) async {
      final result = await connection.execute(
        r'UPDATE orders SET order_status = $1 WHERE id = $2',
        parameters: [newStatus, int.parse(id)],
      );

      if (result.affectedRows == 0) {
        return Response.json(
          statusCode: HttpStatus.notFound,
          body: {'error': '未找到该订单'},
        );
      }

      return Response.json(body: {'message': '订单状态已成功更新为: $newStatus'});
    });
  } catch (e) {
    print('订单状态更新失败: $e');
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'error': '服务器内部错误'},
    );
  }
}
