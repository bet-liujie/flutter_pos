import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

// 处理 /products 路由的所有 HTTP 请求（增删查改）
Future<Response> onRequest(RequestContext context) async {
  // 从 context 获取数据库连接池
  final pool = context.read<Pool>();

  try {
    switch (context.request.method) {
      case HttpMethod.get:
        // 查询商品（支持通过 id 查询单个商品，也支持查询全部商品）
        final id = context.request.uri.queryParameters['id'];
        if (id != null) {
          // serial4 实际就是 int，类型安全建议依然转 int 校验
          final pid = int.tryParse(id);
          if (pid == null) {
            return Response.json(
              statusCode: 400,
              body: {'status': 'error', 'message': 'Invalid id'},
            );
          }
          // SQL 占位符用 $1，参数用 List
          final result = await pool.execute(
            r'SELECT * FROM products WHERE id = $1',
            parameters: [pid],
          );
          final data = result.map((row) => row.toColumnMap()).toList();
          if (data.isEmpty) {
            return Response.json(
              statusCode: 404,
              body: {'status': 'error', 'message': 'Product not found'},
            );
          }
          return Response.json(
            body: {'status': 'ok', 'item': data.first},
          );
        } else {
          final result = await pool.execute('SELECT * FROM products');
          final data = result.map((row) => row.toColumnMap()).toList();
          return Response.json(body: {'status': 'ok', 'items': data});
        }

      case HttpMethod.post:
        // 新增商品，直接用 context.request.json() 解析 body
        final data = await context.request.json() as Map<String, dynamic>;
        final name = data['name']?.toString();
        final price = num.tryParse(data['price']?.toString() ?? '');
        if (name == null || name.isEmpty || price == null) {
          return Response.json(
            statusCode: 400,
            body: {'status': 'error', 'message': 'Invalid name or price'},
          );
        }
        final result = await pool.execute(
          r'INSERT INTO products (name, price) VALUES ($1, $2) RETURNING id',
          parameters: [name, price],
        );
        final insertedId = result.firstOrNull?.toColumnMap()['id'];
        return Response.json(body: {'status': 'created', 'id': insertedId});

      case HttpMethod.put:
        // 更新商品
        final data = await context.request.json() as Map<String, dynamic>;
        final id = int.tryParse(data['id']?.toString() ?? '');
        final name = data['name']?.toString();
        final price = num.tryParse(data['price']?.toString() ?? '');
        if (id == null || name == null || name.isEmpty || price == null) {
          return Response.json(
            statusCode: 400,
            body: {'status': 'error', 'message': 'Invalid id, name or price'},
          );
        }
        final result = await pool.execute(
          r'UPDATE products SET name = $1, price = $2 WHERE id = $3',
          parameters: [name, price, id],
        );
        if (result.affectedRows == 0) {
          return Response.json(
            statusCode: 404,
            body: {'status': 'error', 'message': 'Product not found'},
          );
        }
        return Response.json(body: {'status': 'updated', 'id': id});

      case HttpMethod.delete:
        // 删除商品
        final id = context.request.uri.queryParameters['id'];
        final pid = int.tryParse(id ?? '');
        if (pid == null) {
          return Response.json(
            statusCode: 400,
            body: {'status': 'error', 'message': 'Invalid id'},
          );
        }
        final result = await pool.execute(
          r'DELETE FROM products WHERE id = $1',
          parameters: [pid],
        );
        if (result.affectedRows == 0) {
          return Response.json(
            statusCode: 404,
            body: {'status': 'error', 'message': 'Product not found'},
          );
        }
        return Response.json(body: {'status': 'deleted', 'id': pid});

      default:
        return Response.json(
          statusCode: 405,
          body: {'status': 'error', 'message': 'Method not allowed'},
        );
    }
  } catch (e) {
    // 捕获所有异常，返回通用错误信息，避免泄露细节
    return Response.json(
      statusCode: 500,
      body: {'status': 'error', 'message': 'Internal server error'},
    );
  }
}
