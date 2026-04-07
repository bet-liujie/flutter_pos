import 'package:dio/dio.dart';

class ApiService {
  // 你的服务器局域网地址
  final String baseUrl = 'http://192.168.43.251:8080';
  late Dio dio;

  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
  }

  /// 1. 获取所有商品 (GET)
  Future<List<Map<String, dynamic>>> getProducts() async {
    final resp = await dio.get('/products');
    if (resp.statusCode == 200) {
      // 假设后端返回结构是 { "items": [...] }
      return List<Map<String, dynamic>>.from(resp.data['items'] ?? []);
    }
    throw Exception('加载失败');
  }

  /// 2. 新增商品 (POST)
  Future<void> addProduct(String name, double price) async {
    await dio.post('/products', data: {'name': name, 'price': price});
  }

  /// 3. 更新商品 (PUT)
  Future<void> updateProduct(int id, String name, double price) async {
    await dio.put('/products', data: {'id': id, 'name': name, 'price': price});
  }

  /// 4. 删除商品 (DELETE)
  Future<void> deleteProduct(int id) async {
    await dio.delete('/products', queryParameters: {'id': id});
  }
}
