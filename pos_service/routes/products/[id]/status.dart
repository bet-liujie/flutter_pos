import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  // 1. 必须检查请求方法
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // 2. 关键修复：从 context 读取 Pool 而不是 Connection
  final pool = context.read<Pool>();

  try {
    // 3. 解析请求体
    final body = await context.request.json() as Map<String, dynamic>;
    final isActive = body['is_active'] as bool?;

    if (isActive == null) {
      return Response(
        statusCode: HttpStatus.badRequest,
        body: '缺失 is_active 字段',
      );
    }

    // 4. 使用连接池执行更新
    return await pool.withConnection((connection) async {
      final result = await connection.execute(
        r'UPDATE products SET is_active = $1 WHERE id = $2',
        parameters: [isActive, int.parse(id)],
      );

      // 检查是否真的更新到了行
      if (result.affectedRows == 0) {
        return Response.json(
          statusCode: HttpStatus.notFound,
          body: {'error': '未找到该商品'},
        );
      }

      return Response.json(body: {'message': '状态更新成功'});
    });
  } catch (e) {
    print('❌ 状态更新报错: $e');
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'error': e.toString()},
    );
  }
}
