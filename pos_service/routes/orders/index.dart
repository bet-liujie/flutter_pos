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
  final totalAmount = body['total_amount'] as num;
  final items = body['items'] as List<dynamic>;
  final paymentMethod = body['payment_method'] ?? 'unpaid';

  // 1. 生成商业级流水号 (格式: POS-20260409-1234)
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
        Sql.named('''
          INSERT INTO orders (order_no, total_amount, order_status, payment_method) 
          VALUES (@no, @total, 'pending', @payment) 
          RETURNING id, order_no
        '''),
        parameters: {
          'no': orderNo,
          'total': totalAmount,
          'payment': paymentMethod,
        },
      );

      final newOrderId = orderResult[0][0] as int;
      final generatedOrderNo = orderResult[0][1] as String;

      // 3. 循环写入明细表 (快照记录)
      for (final item in items) {
        final quantity = item['quantity'] as int;
        final snapshotPrice = item['snapshot_price'] as num;

        // 💥 安全底线：单行小计由后端绝对控制，强制重新计算！
        final subtotal = quantity * snapshotPrice;

        await ctx.execute(
          Sql.named('''
            INSERT INTO order_items 
            (order_id, product_id, snapshot_name, snapshot_price, quantity, subtotal)
            VALUES (@oid, @pid, @s_name, @s_price, @qty, @sub)
          '''),
          parameters: {
            'oid': newOrderId,
            'pid': item['product_id'],
            's_name': item['snapshot_name'],
            's_price': snapshotPrice,
            'qty': quantity,
            'sub': subtotal,
          },
        );
      }

      return {'id': newOrderId, 'orderNo': generatedOrderNo};
    });

    return Response.json(
      body: {
        'success': true,
        'message': '订单创建成功',
        'data': {
          'order_id': result['id'],
          'order_no': result['orderNo'],
          'total_amount': totalAmount,
        },
      },
    );
  } catch (e) {
    print('订单事务创建失败: $e');
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': '服务器内部错误，订单已安全回滚'},
    );
  }
}
