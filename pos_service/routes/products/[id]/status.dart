import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final pool = context.read<Pool>();
  final merchantId = context.read<int>(); // ✨ SaaS 身份标记

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final isActive = body['is_active'] as bool;
    final productId = int.parse(id);

    // ✨ 核心业务逻辑恢复：如果是请求“上架”，必须做前置校验！
    if (isActive) {
      // 携带 merchant_id 进行查询，防止越权查探其他商户的库存
      final checkResult = await pool.execute(
        r'SELECT stock, is_deleted FROM products WHERE id = $1 AND merchant_id = $2',
        parameters: [productId, merchantId],
      );

      // 1. 商品存在性与归属权校验
      if (checkResult.isEmpty) {
        return Response.json(
          statusCode: 403,
          body: {'success': false, 'error': '商品不存在或无权操作'},
        );
      }

      final stock = checkResult[0][0] as int;
      final isDeleted = checkResult[0][1] as bool;

      // 2. 软删除校验
      if (isDeleted) {
        return Response.json(
          statusCode: 400,
          body: {'success': false, 'error': '该商品已被删除，无法上架'},
        );
      }

      // 3. ✨ 恢复你的核心拦截：零库存防超卖
      if (stock <= 0) {
        return Response.json(
          statusCode: 400,
          body: {'success': false, 'error': '当前库存为 0，无法上架该商品！'},
        );
      }
    }

    // ✨ 执行状态更新（同样携带 merchant_id 作为双保险）
    final updateResult = await pool.execute(
      r'UPDATE products SET is_active = $1 WHERE id = $2 AND merchant_id = $3 RETURNING id',
      parameters: [isActive, productId, merchantId],
    );

    if (updateResult.isEmpty) {
      return Response.json(
        statusCode: 403,
        body: {'success': false, 'error': '状态更新失败，请重试'},
      );
    }

    return Response.json(
      body: {'success': true, 'message': isActive ? '上架成功' : '已下架'},
    );
  } catch (e) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
