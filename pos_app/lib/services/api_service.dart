import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

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
  Future<void> addProduct(
    String name,
    double price,
    int stock,
    String desc,
    bool isActive,
    XFile? image,
  ) async {
    FormData formData = FormData.fromMap({
      'name': name,
      'price': price,
      'stock': stock,
      'description': desc,
      'is_active': isActive,
      if (image != null)
        'image': await MultipartFile.fromFile(image.path, filename: image.name),
    });
    await dio.post('/products', data: formData);
  }

  /// 3. 更新商品 (PUT)
  Future<void> updateProduct(
    int id,
    String name,
    double price,
    int stock,
    String desc,
    bool isActive,
    XFile? image,
  ) async {
    FormData formData = FormData.fromMap({
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
      'description': desc,
      'is_active': isActive,
      if (image != null)
        'image': await MultipartFile.fromFile(image.path, filename: image.name),
    });
    await dio.put('/products', data: formData);
  }

  /// 4. 删除商品 (DELETE)
  Future<void> deleteProduct(int id) async {
    await dio.delete('/products', queryParameters: {'id': id});
  }

  // 新增：快捷切换上下架状态 (PATCH 请求)
  Future<void> toggleStatus(int id, bool isActive) async {
    await dio.patch('/products/$id/status', data: {'is_active': isActive});
  }

  // 5. 创建订单 (POST)
  Future<Map<String, dynamic>> createOrder(
    List<Map<String, dynamic>> items, {
    String paymentMethod = 'cash',
    String orderStatus = 'pending',
  }) async {
    final payload = {
      'payment_method': paymentMethod,
      'order_status': orderStatus,
      'items': items,
    };

    try {
      final response = await dio.post('/orders', data: payload);
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']; // 返回订单详情
      } else {
        throw Exception(response.data['error'] ?? '未知错误');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['error'] ?? '网络请求失败');
      }
      throw Exception('网络连接异常');
    }
  }
}
