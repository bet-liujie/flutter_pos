import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.post) return _createOrder(context);
  return Response(statusCode: 405, body: 'Method Not Allowed');
}

Future<Response> _createOrder(RequestContext context) async {
  final body = await context.request.json() as Map<String, dynamic>;
  final rawItems = (body['items'] as List<dynamic>?) ?? [];
  final paymentMethod = body['payment_method'] ?? 'cash';
  final expectedStatus = body['order_status']?.toString() ?? 'completed';
  final idempotencyKey = body['idempotency_key']?.toString();

  if (rawItems.isEmpty || idempotencyKey == null) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'error': '必填参数缺失'},
    );
  }

  // 数据预处理：转换为强类型 Map，合并相同商品的数量（防御性编程：防止前端重复传同个 ID）
  final itemQuantities = <int, int>{};
  for (final item in rawItems) {
    final id = int.parse(item['products_id'].toString());
    final qty = int.parse(item['quantity'].toString());
    itemQuantities[id] = (itemQuantities[id] ?? 0) + qty;
  }
  final productIds = itemQuantities.keys.toList();

  final pool = context.read<Pool>();

  try {
    final result = await pool.runTx((ctx) async {
      // 1. 插入订单并校验幂等（UNIQUE 约束会自动拦截）
      final orderResult = await ctx.execute(
        r'''
        INSERT INTO orders (order_no, total_amount, order_status, payment_method, idempotency_key)
        VALUES ($1, 0, $3, $2, $4) RETURNING id, order_no
        ''',
        parameters: [
          'POS-${DateTime.now().millisecondsSinceEpoch}',
          paymentMethod,
          expectedStatus,
          idempotencyKey,
        ],
      );
      final newOrderId = orderResult[0][0] as int;

      // 2. 批量锁定并查询商品信息（解决 N+1 读）
      final products = await ctx.execute(
        r'SELECT id, name, price, stock, is_active FROM products WHERE id = ANY($1) FOR UPDATE',
        parameters: [productIds],
      );

      final productMap = {for (final r in products) r[0] as int: r};
      num totalAmount = 0;

      // 3. 准备批量更新库存的数据（PostgreSQL CTE 技巧）
      // 我们将使用 unnest 配合 UPDATE 来实现一次性更新所有行
      final updateIds = <int>[];
      final updateQtys = <int>[];
      final insertItems = <List<dynamic>>[];

      for (final id in productIds) {
        final p = productMap[id];
        if (p == null || !(p[4] as bool)) throw Exception('商品(ID:$id)不存在或已下架');

        final qty = itemQuantities[id]!;
        final stock = p[3] as int;
        if (stock < qty) throw Exception('商品[${p[1]}]库存不足');

        final price = p[2] is num ? p[2] as num : num.parse(p[2].toString());
        final subtotal = price * qty;
        totalAmount += subtotal;

        updateIds.add(id);
        updateQtys.add(qty);
        insertItems.add([newOrderId, id, p[1], price, qty, subtotal]);
      }

      // 4. ✨ 核心性能优化：单条 SQL 批量更新库存
      await ctx.execute(
        r'''
        UPDATE products 
        SET 
          stock = stock - t.qty,
          is_active = CASE WHEN stock - t.qty = 0 THEN FALSE ELSE is_active END
        FROM (SELECT unnest($1::int[]) as id, unnest($2::int[]) as qty) AS t
        WHERE products.id = t.id AND products.stock >= t.qty
        ''',
        parameters: [updateIds, updateQtys],
      );

      // 5. ✨ 核心性能优化：批量插入订单明细
      // 使用 unnest 进行矩阵式插入，效率远高于循环 INSERT
      await ctx.execute(
        r'''
        INSERT INTO order_items (order_id, products_id, snapshot_name, snapshot_price, quantity, subtotal)
        SELECT $1, * FROM unnest($2::int[], $3::text[], $4::numeric[], $5::int[], $6::numeric[])
        ''',
        parameters: [
          newOrderId,
          insertItems.map((e) => e[1]).toList(), // products_id
          insertItems.map((e) => e[2]).toList(), // name
          insertItems.map((e) => e[3]).toList(), // price
          insertItems.map((e) => e[4]).toList(), // quantity
          insertItems.map((e) => e[5]).toList(), // subtotal
        ],
      );

      // 6. 更新订单总额
      await ctx.execute(
        r'''UPDATE orders SET total_amount = $1 WHERE id = $2''',
        parameters: [totalAmount, newOrderId],
      );

      return {'id': newOrderId, 'total': totalAmount};
    });

    return Response.json(body: {'success': true, 'data': result});
  } catch (e) {
    // 针对商家的友好错误提示
    final errorMsg = e.toString().contains('unique_violation')
        ? '订单已存在，请勿重复结账'
        : e.toString().replaceAll('Exception: ', '');
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'error': errorMsg},
    );
  }
}
