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

  // 💥 安全防线：安全获取 items，如果为空或者没传，默认为空列表
  final items = (body['items'] as List<dynamic>?) ?? [];
  final paymentMethod = body['payment_method'] ?? 'unpaid';

  // 💥 严格校验：绝对不允许空订单混入数据库
  if (items.isEmpty) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'error': '创建失败：订单明细 (items) 不能为空！'},
    );
  }

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

      // 3. 循环处理明细并【扣减库存】
      for (final item in items) {
        final productsId = int.parse(item['products_id'].toString());
        final quantity = int.parse(item['quantity'].toString());

        // ✨ 核心升级：连同 stock 和 is_active 一起查出来
        final productCheck = await ctx.execute(
          r'SELECT name, price, stock, is_active FROM products WHERE id = $1 AND is_deleted = FALSE',
          parameters: [productsId],
        );

        if (productCheck.isEmpty) {
          throw Exception('检测到异常：商品不存在或已被删除 (ID: $productsId)');
        }

        final realName = productCheck[0][0] as String;
        final rawPrice = productCheck[0][1];
        final realPrice = rawPrice is num
            ? rawPrice
            : num.parse(rawPrice.toString());

        // 解析库存和状态
        final stock = productCheck[0][2] as int;
        final isActive = productCheck[0][3] as bool;

        // 💥 库存与上架状态检查
        if (!isActive) {
          throw Exception('商品 [$realName] 已下架，无法点单');
        }
        if (stock < quantity) {
          throw Exception('商品 [$realName] 库存不足 (剩余: $stock)');
        }

        // 💥 计算新库存并更新数据库（若减为0，自动触发下架）
        final newStock = stock - quantity;
        await ctx.execute(
          r'UPDATE products SET stock = $1, is_active = (CASE WHEN $1 = 0 THEN FALSE ELSE is_active END) WHERE id = $2',
          parameters: [newStock, productsId],
        );

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
