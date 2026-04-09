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
  final items = body['items'] as List<dynamic>;
  final paymentMethod = body['payment_method'] ?? 'unpaid';

  // 1. 生成商业级流水号
  final now = DateTime.now();
  final dateStr =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  final orderNo =
      'POS-$dateStr-${now.millisecondsSinceEpoch.toString().substring(9)}';

  final pool = context.read<Pool>();

  try {
    // 开启数据库事务
    final result = await pool.runTx((ctx) async {
      // 2. 写入主表
      final orderResult = await ctx.execute(
        r'''
          INSERT INTO orders (order_no, total_amount, order_status, payment_method) 
          VALUES ($1, 0, 'pending', $2) 
          RETURNING id, order_no
        ''',
        parameters: [orderNo, paymentMethod],
      );

      final newOrderId = orderResult[0][0] as int;
      final generatedOrderNo = orderResult[0][1] as String;

      num realTotalAmount = 0;

      // 3. 循环写入明细表
      for (final item in items) {
        final productsId = int.parse(item['products_id'].toString());
        final quantity = int.parse(item['quantity'].toString());

        // ✨ 审阅修复：精确使用 is_deleted = FALSE，配合绝对可靠的 $1 位置参数
        final productCheck = await ctx.execute(
          r'SELECT name, price FROM products WHERE id = $1 AND is_deleted = FALSE',
          parameters: [productsId],
        );

        // 如果连 $1 写法都查不到，说明数据库里真的没有或者已经被软删除
        if (productCheck.isEmpty) {
          throw Exception('检测到异常：商品不存在或已被删除 (ID: $productsId)');
        }

        final realName = productCheck[0][0] as String;
        // 兼容数字和字符串类型的价格
        final rawPrice = productCheck[0][1];
        final realPrice = rawPrice is num
            ? rawPrice
            : num.parse(rawPrice.toString());

        // 后端绝对控制小计
        final secureSubtotal = quantity * realPrice;
        realTotalAmount += secureSubtotal;

        // 写入明细表
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

      // 4. 更新订单真实总金额
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
    print('订单事务创建失败: $e');
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
