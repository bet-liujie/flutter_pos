import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.patch)
    return Response(statusCode: 405, body: 'Method Not Allowed');

  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    // 兼容 true 和 "true" 的字符串解析防御
    final isActive = body['is_active']?.toString() == 'true';
    final productId = int.parse(id);

    // ✨ 业务底线 1：如果试图上架，必须严查库存和软删除
    if (isActive) {
      final checkResult = await pool.execute(
        r'SELECT stock, is_deleted FROM products WHERE id = $1 AND merchant_id = $2',
        parameters: [productId, merchantId],
      );

      if (checkResult.isEmpty)
        return Response.json(
          statusCode: 403,
          body: {'success': false, 'error': '该商品不存在或无权操作'},
        );

      final stock = int.parse(checkResult[0][0].toString());
      final isDeleted = checkResult[0][1] as bool;

      if (isDeleted)
        return Response.json(
          statusCode: 400,
          body: {'success': false, 'error': '商品已被删除，无法上架'},
        );
      if (stock <= 0)
        return Response.json(
          statusCode: 400,
          body: {'success': false, 'error': '库存为 0，无法上架！'},
        );
    }

    // ✨ 业务底线 2：强制匹配商户 ID 的更新
    final updateResult = await pool.execute(
      r'UPDATE products SET is_active = $1 WHERE id = $2 AND merchant_id = $3',
      parameters: [isActive, productId, merchantId],
    );

    if (updateResult.affectedRows == 0)
      return Response.json(
        statusCode: 403,
        body: {'success': false, 'error': '状态更新失败，可能是跨租户越权'},
      );

    return Response.json(body: {'success': true});
  } catch (e) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
