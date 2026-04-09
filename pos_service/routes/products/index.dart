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
        return await _updateProduct(context, connection); // 👈 在这里
      }
      if (method == HttpMethod.delete) {
        return await _deleteProduct(context, connection); // 👈 在这里
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
  String? imageUrl;
  if (formData.files['image'] != null) {
    imageUrl = await _saveFile(context.request, formData.files['image']!);
  }

  await connection.execute(
    r'INSERT INTO products (name, price, description, is_active, image_url) VALUES ($1, $2, $3, $4, $5)',
    parameters: [
      formData.fields['name'],
      double.tryParse(formData.fields['price'] ?? '0'),
      formData.fields['description'],
      formData.fields['is_active'] == 'true',
      imageUrl,
    ],
  );
  return Response.json(body: {'message': '添加成功'});
}

// 3. 更新商品 (增加防脏写保护)
Future<Response> _updateProduct(
  RequestContext context,
  Connection connection,
) async {
  final formData = await context.request.formData();
  final id = int.parse(formData.fields['id']!);

  // 💥 新增逻辑：修改前先检查该商品是否还存活
  final checkData = await connection.execute(
    r'SELECT is_deleted, image_url FROM products WHERE id = $1',
    parameters: [id],
  );

  // 如果找不到数据，或者已经被标记为假删除，直接阻断
  if (checkData.isEmpty || checkData.first[0] == true) {
    return Response.json(statusCode: 400, body: {'error': '修改失败：该商品已被删除'});
  }

  // 获取旧图片地址，用于后续的清理逻辑
  final oldImageUrl = checkData.first[1] as String?;

  String? newImageUrl;
  if (formData.files['image'] != null) {
    await _physicalDeleteFile(oldImageUrl);
    newImageUrl = await _saveFile(context.request, formData.files['image']!);

    await connection.execute(
      r'UPDATE products SET name=$1, price=$2, description=$3, is_active=$4, image_url=$5 WHERE id=$6',
      parameters: [
        formData.fields['name'],
        double.tryParse(formData.fields['price'] ?? '0'),
        formData.fields['description'],
        formData.fields['is_active'] == 'true',
        newImageUrl,
        id,
      ],
    );
  } else {
    await connection.execute(
      r'UPDATE products SET name=$1, price=$2, description=$3, is_active=$4 WHERE id=$5',
      parameters: [
        formData.fields['name'],
        double.tryParse(formData.fields['price'] ?? '0'),
        formData.fields['description'],
        formData.fields['is_active'] == 'true',
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
  final imageUrl = data.firstOrNull?.toColumnMap()['image_url'] as String?;

  // B. 物理删除磁盘文件，释放高占用资源
  await _physicalDeleteFile(imageUrl);

  // C. 软删除数据库记录，同时清空 image_url 字段防脏数据
  await connection.execute(
    r'UPDATE products SET is_deleted = TRUE, image_url = NULL WHERE id = $1',
    parameters: [id],
  );

  return Response.json(body: {'message': '删除成功'});
}

// --- 辅助工具函数 ---

// 保存文件到磁盘
// 保存文件到磁盘 (增加目录存在性检查)
Future<String> _saveFile(Request request, UploadedFile file) async {
  final ext = file.name.split('.').last;
  final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';

  final targetFile = File('public/uploads/$fileName');

  // 💥 修复：在写入前，检查父级目录是否存在。如果不存在则递归创建它。
  if (!await targetFile.parent.exists()) {
    await targetFile.parent.create(recursive: true);
  }

  // 写入文件
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
