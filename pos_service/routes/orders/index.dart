import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.post) {
    return _createOrder(context);
  }
  return Response(statusCode: 405, body: 'Method Not Allowed');
}

Future<Response> _createOrder(RequestContext context) async {
  final body = await context.request.json() as Map<String, dynamic>;

  // 这里的 items 需要指定类型以方便后续排序
  final rawItems = (body['items'] as List<dynamic>?) ?? [];
  final paymentMethod = body['payment_method'] ?? 'unpaid';

  if (rawItems.isEmpty) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'error': '创建失败：订单明细不能为空！'},
    );
  }

  // ✨ 防护 1：预防死锁 (Deadlock)。对输入商品按 ID 排序，保证并发时加锁的顺序始终一致。
  final items = List<Map<String, dynamic>>.from(rawItems);
  items.sort((a, b) {
    final idA = int.parse(a['products_id'].toString());
    final idB = int.parse(b['products_id'].toString());
    return idA.compareTo(idB);
  });

  final now = DateTime.now();
  final dateStr =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  final orderNo =
      'POS-$dateStr-${now.millisecondsSinceEpoch.toString().substring(9)}';

  final pool = context.read<Pool>();

  try {
    final result = await pool.runTx((ctx) async {
      final orderResult = await ctx.execute(
        r'''
          INSERT INTO orders (order_no, total_amount, order_status, payment_method) 
          VALUES ($1, 0, 'pending', $2) 
          RETURNING id, order_no
        ''',
        parameters: [orderNo, paymentMethod],
      );

      final newOrderId = orderResult[0][0]! as int;
      final generatedOrderNo = orderResult[0][1]! as String;
      num realTotalAmount = 0;

      for (final item in items) {
        final productsId = int.parse(item['products_id'].toString());
        final quantity = int.parse(item['quantity'].toString());

        if (quantity <= 0) throw Exception('商品数量异常');

        // ✨ 防护 2：使用 FOR UPDATE 施加悲观锁（排他锁），彻底杜绝并发超卖
        final productCheck = await ctx.execute(
          r'''
            SELECT name, price, stock, is_active 
            FROM products 
            WHERE id = $1 AND is_deleted = FALSE 
            FOR UPDATE
          ''',
          parameters: [productsId],
        );

        if (productCheck.isEmpty) {
          throw Exception('商品不存在或已被删除 (ID: $productsId)');
        }

        final realName = productCheck[0][0]! as String;
        final rawPrice = productCheck[0][1];
        final realPrice = rawPrice is num
            ? rawPrice
            : num.parse(rawPrice.toString());
        final stock = productCheck[0][2]! as int;
        final isActive = productCheck[0][3]! as bool;

        if (!isActive) throw Exception('商品 [$realName] 已下架');
        if (stock < quantity) {
          throw Exception('商品 [$realName] 库存不足 (剩余: $stock)');
        }

        // ✨ 防护 3：不要在内存中算减法，让数据库用原子递减去执行，同时加上 stock >= 条件做双保险
        final updateRes = await ctx.execute(
          r'''
            UPDATE products 
            SET 
              stock = stock - $1, 
              is_active = (CASE WHEN stock - $1 = 0 THEN FALSE ELSE is_active END) 
            WHERE id = $2 AND stock >= $1
          ''',
          parameters: [quantity, productsId],
        );

        // 如果受影响行数为0，说明在你更新的瞬间，库存被其他人改小了（虽然有 FOR UPDATE 一般不会走到这里，但这叫极致防御）
        if (updateRes.affectedRows == 0) {
          throw Exception('商品 [$realName] 库存扣减失败');
        }

        final secureSubtotal = quantity * realPrice;
        realTotalAmount += secureSubtotal;

        await ctx.execute(
          r'''
            INSERT INTO order_items 
            (order_id, products_id, snapshot_name, snapshot_price, quantity, subtotal)
            VALUES ($1, $2, $3, $4, $5, $6)
          ''',
          parameters: [
            newOrderId,
            productsId,
            realName,
            realPrice,
            quantity,
            secureSubtotal,
          ],
        );
      }

      await ctx.execute(
        r'UPDATE orders SET total_amount = $1 WHERE id = $2',
        parameters: [realTotalAmount, newOrderId],
      );

      return {
        'id': newOrderId,
        'orderNo': generatedOrderNo,
        'realTotalAmount': realTotalAmount,
      };
    });

    return Response.json(
      body: {
        'success': true,
        'message': '订单创建成功',
        'data': {
          'order_id': result['id'],
          'order_no': result['orderNo'],
          'total_amount': result['realTotalAmount'],
        },
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
