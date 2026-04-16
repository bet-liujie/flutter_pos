import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getProducts(context);
    case HttpMethod.post:
      return _addProduct(context);
    case HttpMethod.put:
      return _updateProduct(context);
    case HttpMethod.delete:
      return _deleteProduct(context);
    default:
      return Response(statusCode: 405, body: 'Method Not Allowed');
  }
}

// ✨ 安全辅助：智能提取 FormData (有图片) 或 JSON 数据
Future<Map<String, dynamic>> _parseBody(RequestContext context) async {
  final contentType = context.request.headers['content-type'] ?? '';
  if (contentType.contains('multipart/form-data')) {
    final formData = await context.request.formData();
    return formData.fields;
  }
  return await context.request.json() as Map<String, dynamic>;
}

Future<Response> _getProducts(RequestContext context) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final result = await pool.execute(
      r'SELECT id, name, price, stock, description, is_active, image_url FROM products WHERE is_deleted = FALSE AND merchant_id = $1 ORDER BY id DESC',
      parameters: [merchantId],
    );

    final products = result
        .map(
          (row) => {
            'id': row[0],
            'name': row[1],
            'price': double.parse(row[2].toString()),
            'stock': row[3],
            'description': row[4],
            'is_active': row[5],
            'image_url': row[6],
          },
        )
        .toList();

    return Response.json(body: {'success': true, 'data': products});
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}

Future<Response> _deleteProduct(RequestContext context) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>(); // 注入的商户 ID 防线

  // 1. 解析前端传来的 Query Parameter: ?id=xxx
  final idString = context.request.url.queryParameters['id'];
  if (idString == null || idString.isEmpty) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'error': '缺少商品 ID 参数'},
    );
  }

  final productId = int.tryParse(idString);
  if (productId == null) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'error': '无效的商品 ID'},
    );
  }

  try {
    // 2. 核心架构逻辑：软删除 + 强制下架 + 释放图片资源 + 商户防越权
    final result = await pool.execute(
      r'''
      UPDATE products 
      SET is_deleted = TRUE, 
          is_active = FALSE, 
          image_url = NULL 
      WHERE id = $1 AND merchant_id = $2 
      RETURNING id
      ''',
      parameters: [productId, merchantId],
    );

    // 3. 如果影响行数为 0，说明么有该商品，或者这是别的商户的商品
    if (result.isEmpty) {
      return Response.json(
        statusCode: 403,
        body: {'success': false, 'error': '该商品不存在或无权跨商户删除'},
      );
    }

    return Response.json(body: {'success': true, 'message': '已安全删除并释放资源'});
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': '后端数据库异常: ${e}'},
    );
  }
}

Future<Response> _addProduct(RequestContext context) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final body = await _parseBody(context);
    final stock = int.tryParse(body['stock'].toString()) ?? 0;
    final isActive = body['is_active']?.toString() == 'true';

    if (isActive && stock <= 0) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '库存为 0 时不允许上架'},
      );
    }

    final result = await pool.execute(
      r'''
      INSERT INTO products (name, price, stock, description, is_active, merchant_id)
      VALUES ($1, $2, $3, $4, $5, $6) RETURNING id
      ''',
      parameters: [
        body['name'],
        double.tryParse(body['price'].toString()) ?? 0.0,
        stock,
        body['description'] ?? '',
        isActive,
        merchantId,
      ],
    );
    return Response.json(
      body: {
        'success': true,
        'data': {'id': result[0][0]},
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'error': e.toString()},
    );
  }
}

Future<Response> _updateProduct(RequestContext context) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final body = await _parseBody(context);
    final stock = int.tryParse(body['stock'].toString()) ?? 0;
    final isActive = body['is_active']?.toString() == 'true';

    // ✨ 业务底线 3：在详情页修改商品时，也绝不允许无库存强行上架
    if (isActive && stock <= 0) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '库存为 0 时不允许设置为上架状态'},
      );
    }

    final result = await pool.execute(
      r'''
      UPDATE products 
      SET name = $1, price = $2, stock = $3, description = $4, is_active = $5 
      WHERE id = $6 AND merchant_id = $7
      ''',
      parameters: [
        body['name'],
        double.tryParse(body['price'].toString()) ?? 0.0,
        stock,
        body['description'] ?? '',
        isActive,
        int.parse(body['id'].toString()),
        merchantId,
      ],
    );

    if (result.affectedRows == 0) {
      return Response.json(
        statusCode: 403,
        body: {'success': false, 'error': '无权修改该商品或商品不存在'},
      );
    }
    return Response.json(body: {'success': true, 'message': '修改成功'});
  } catch (e) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
