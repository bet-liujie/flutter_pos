import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  final pool = context.read<Pool>();
  final method = context.request.method;

  return pool.withConnection((connection) async {
    try {
      if (method == HttpMethod.get) return await _getProducts(connection);
      if (method == HttpMethod.post) {
        return await _addProduct(context, connection);
      }
      if (method == HttpMethod.put) {
        return await _updateProduct(context, connection);
      }
      if (method == HttpMethod.delete) {
        return await _deleteProduct(context, connection);
      }

      return Response(statusCode: HttpStatus.methodNotAllowed);
    } catch (e) {
      return Response.json(statusCode: 500, body: {'error': e.toString()});
    }
  });
}

// --- 以下是具体的实现函数 ---

// 1. 获取列表
Future<Response> _getProducts(Connection connection) async {
  final result = await connection.execute(
    'SELECT * FROM products WHERE is_deleted = FALSE ORDER BY id DESC',
  );
  return Response.json(
    body: {'items': result.map((r) => r.toColumnMap()).toList()},
  );
}

// 2. 新增商品
Future<Response> _addProduct(
  RequestContext context,
  Connection connection,
) async {
  final formData = await context.request.formData();
  final fields = formData.fields;

  // ✨ 解析库存，并执行“零库存强制下架”逻辑
  final stock = int.tryParse(fields['stock'] ?? '0') ?? 0;
  final isActive = (fields['is_active'] == 'true') && stock > 0;

  String? imageUrl;
  if (formData.files['image'] != null) {
    imageUrl = await _saveFile(context.request, formData.files['image']!);
  }

  await connection.execute(
    r'INSERT INTO products (name, price, description, is_active, image_url, stock) VALUES ($1, $2, $3, $4, $5, $6)',
    parameters: [
      fields['name'],
      double.tryParse(fields['price'] ?? '0'),
      fields['description'],
      isActive,
      imageUrl,
      stock, // 👈 写入库存
    ],
  );
  return Response.json(body: {'message': '添加成功'});
}

// 3. 更新商品 (增加防脏写保护与库存逻辑)
Future<Response> _updateProduct(
  RequestContext context,
  Connection connection,
) async {
  final formData = await context.request.formData();
  final fields = formData.fields;
  final id = int.tryParse(fields['id'] ?? '');

  if (id == null) return Response(statusCode: 400, body: '缺失商品ID');

  // 修改前先检查该商品是否还存活
  final checkData = await connection.execute(
    r'SELECT is_deleted, image_url FROM products WHERE id = $1',
    parameters: [id],
  );

  // 如果找不到数据，或者已经被标记为假删除，直接阻断
  if (checkData.isEmpty || checkData.first[0] == true) {
    return Response.json(statusCode: 400, body: {'error': '修改失败：该商品已被删除'});
  }

  // ✨ 解析新库存与状态逻辑
  final stock = int.tryParse(fields['stock'] ?? '0') ?? 0;
  final isActive = (fields['is_active'] == 'true') && stock > 0;

  // 获取旧图片地址，用于后续的清理逻辑
  final oldImageUrl = checkData.first[1] as String?;

  String? newImageUrl;
  if (formData.files['image'] != null) {
    // 物理删除旧文件并保存新文件
    await _physicalDeleteFile(oldImageUrl);
    newImageUrl = await _saveFile(context.request, formData.files['image']!);

    await connection.execute(
      r'UPDATE products SET name=$1, price=$2, description=$3, is_active=$4, image_url=$5, stock=$6 WHERE id=$7',
      parameters: [
        fields['name'],
        double.tryParse(fields['price'] ?? '0'),
        fields['description'],
        isActive,
        newImageUrl,
        stock,
        id,
      ],
    );
  } else {
    // 仅更新文字信息和库存
    await connection.execute(
      r'UPDATE products SET name=$1, price=$2, description=$3, is_active=$4, stock=$5 WHERE id=$6',
      parameters: [
        fields['name'],
        double.tryParse(fields['price'] ?? '0'),
        fields['description'],
        isActive,
        stock,
        id,
      ],
    );
  }
  return Response.json(body: {'message': '更新成功'});
}

// 4. 删除商品 (软删除记录 + 物理删除图片释放资源)
Future<Response> _deleteProduct(
  RequestContext context,
  Connection connection,
) async {
  final id = int.tryParse(context.request.url.queryParameters['id'] ?? '');
  if (id == null) return Response(statusCode: 400);

  // A. 先查询该商品的图片地址
  final data = await connection.execute(
    r'SELECT image_url FROM products WHERE id = $1',
    parameters: [id],
  );

  if (data.isEmpty) return Response(statusCode: 404, body: '商品不存在');
  final imageUrl = data.first[0] as String?;

  // B. 物理删除磁盘文件，释放资源
  await _physicalDeleteFile(imageUrl);

  // C. 软删除数据库记录，同时清空图片链接
  await connection.execute(
    r'UPDATE products SET is_deleted = TRUE, image_url = NULL WHERE id = $1',
    parameters: [id],
  );

  return Response.json(body: {'message': '删除成功'});
}

// --- 辅助工具函数 ---

// 保存文件到磁盘 (增加目录存在性检查)
Future<String> _saveFile(Request request, UploadedFile file) async {
  final ext = file.name.split('.').last;
  final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
  final targetFile = File('public/uploads/$fileName');

  if (!await targetFile.parent.exists()) {
    await targetFile.parent.create(recursive: true);
  }

  await targetFile.writeAsBytes(await file.readAsBytes());
  return 'http://${request.headers['host']}/uploads/$fileName';
}

// 物理删除磁盘文件
Future<void> _physicalDeleteFile(String? url) async {
  if (url == null || url.isEmpty) return;
  try {
    final fileName = Uri.parse(url).pathSegments.last;
    final file = File('public/uploads/$fileName');
    if (await file.exists()) await file.delete();
  } catch (e) {
    print('清理文件失败: $e');
  }
}
