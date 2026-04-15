import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.post) return _createOrder(context);
  return Response(statusCode: 405, body: 'Method Not Allowed');
}

Future<Response> _createOrder(RequestContext context) async {
  final merchantId = context.read<int>();
  final pool = context.read<Pool>();

  final body = await context.request.json() as Map<String, dynamic>;
  final rawItems = (body['items'] as List<dynamic>?) ?? [];
  final idempotencyKey = body['idempotency_key']?.toString();
  final paymentMethod = body['payment_method']?.toString() ?? 'cash';
  final orderStatus = body['order_status']?.toString() ?? 'completed';

  if (rawItems.isEmpty || idempotencyKey == null) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'error': '订单参数不完整'},
    );
  }

  final itemQuantities = <int, int>{};
  for (final item in rawItems) {
    final id = int.parse(item['products_id'].toString());
    final qty = int.parse(item['quantity'].toString());
    if (qty <= 0)
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '恶意请求：商品数量不能为负数或0'},
      );
    itemQuantities[id] = (itemQuantities[id] ?? 0) + qty;
  }
  final productIds = itemQuantities.keys.toList();

  try {
    final result = await pool.runTx((ctx) async {
      // 1. 生成订单主体
      final orderResult = await ctx.execute(
        r'''
        INSERT INTO orders (order_no, total_amount, order_status, payment_method, idempotency_key, merchant_id)
        VALUES ($1, 0, $2, $3, $4, $5) RETURNING id
        ''',
        parameters: [
          'POS-${DateTime.now().millisecondsSinceEpoch}',
          orderStatus,
          paymentMethod,
          idempotencyKey,
          merchantId,
        ],
      );
      final newOrderId = int.parse(orderResult[0][0].toString());

      // 2. 动态拼接防崩溃 SQL 锁定库存 (例如: id IN ($1, $2) AND merchant_id = $3)
      final placeholders = List.generate(
        productIds.length,
        (i) => '\$${i + 1}',
      ).join(', ');
      final products = await ctx.execute(
        'SELECT id, name, price, stock, is_active FROM products WHERE id IN ($placeholders) AND merchant_id = \$${productIds.length + 1} FOR UPDATE',
        parameters: [...productIds, merchantId],
      );

      if (products.length != productIds.length)
        throw Exception('检测到无效商品，可能存在跨商户越权或商品已被删除');

      final productMap = {
        for (final r in products) int.parse(r[0].toString()): r,
      };
      double totalAmount = 0.0;

      for (final id in productIds) {
        final p = productMap[id]!;
        final name = p[1].toString();
        final stock = int.parse(p[3].toString());
        final isActive = p[4] as bool;
        final qty = itemQuantities[id]!;

        // ✨ 业务底线 4：结账时的双保险
        if (!isActive) throw Exception('商品 [$name] 已临时下架，无法结账');
        if (stock < qty) throw Exception('商品 [$name] 库存不足，当前剩余: $stock');

        final price = double.parse(p[2].toString());
        final subtotal = price * qty;
        totalAmount += subtotal;

        // 3. 安全单行更新 (绝对稳定)
        await ctx.execute(
          r'UPDATE products SET stock = stock - $1 WHERE id = $2 AND merchant_id = $3 AND stock >= $1',
          parameters: [qty, id, merchantId],
        );

        await ctx.execute(
          r'''
          INSERT INTO order_items (order_id, products_id, snapshot_name, snapshot_price, quantity, subtotal)
          VALUES ($1, $2, $3, $4, $5, $6)
          ''',
          parameters: [newOrderId, id, name, price, qty, subtotal],
        );
      }

      await ctx.execute(
        r'UPDATE orders SET total_amount = $1 WHERE id = $2',
        parameters: [totalAmount, newOrderId],
      );

      return totalAmount;
    });

    return Response.json(
      body: {
        'success': true,
        'data': {'total_amount': result},
      },
    );
  } catch (e) {
    if (e.toString().contains('unique constraint'))
      return Response.json(
        statusCode: 409,
        body: {'success': false, 'error': '手速太快了，请勿重复结账'},
      );
    return Response.json(
      statusCode: 400,
      body: {
        'success': false,
        'error': e.toString().replaceAll('Exception: ', ''),
      },
    );
  }
}
