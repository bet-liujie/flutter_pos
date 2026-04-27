import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

class ApiService {
  // 确保这是你的局域网 IP
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

    // ✨ 统一给所有请求挂上 SaaS Token
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer test-token-123';
          return handler.next(options);
        },
      ),
    );
  }

  // ✨ 核心防弹防御：把后端真正的中文错误提炼出来，不让 Dio 吞噬
  String _handleDioError(DioException e) {
    if (e.response?.data != null) {
      if (e.response!.data is Map && e.response!.data['error'] != null) {
        return e.response!.data['error'].toString();
      }
      return '服务器响应异常 (${e.response?.statusCode})';
    }
    return '网络异常: ${e.message}';
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final resp = await dio.get('/products');
      if (resp.data is Map) {
        if (resp.data['success'] == true) {
          return List<Map<String, dynamic>>.from(resp.data['data'] ?? []);
        }
        if (resp.data.containsKey('items')) {
          return List<Map<String, dynamic>>.from(resp.data['items'] ?? []);
        }
      }
      throw Exception('加载失败，返回格式未知');
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<void> addProduct(
    String name,
    double price,
    int stock,
    String desc,
    bool isActive,
    XFile? image,
  ) async {
    try {
      FormData formData = FormData.fromMap({
        'name': name,
        'price': price,
        'stock': stock,
        'description': desc,
        'is_active': isActive,
        if (image != null)
          'image': await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
      });
      final resp = await dio.post('/products', data: formData);
      if (resp.data is Map && resp.data['success'] == false) {
        throw Exception(resp.data['error']);
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<void> updateProduct(
    int id,
    String name,
    double price,
    int stock,
    String desc,
    bool isActive,
    XFile? image,
  ) async {
    try {
      FormData formData = FormData.fromMap({
        'id': id,
        'name': name,
        'price': price,
        'stock': stock,
        'description': desc,
        'is_active': isActive,
        if (image != null)
          'image': await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
      });
      final resp = await dio.put('/products', data: formData);
      if (resp.data is Map && resp.data['success'] == false) {
        throw Exception(resp.data['error']);
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      final resp = await dio.delete('/products', queryParameters: {'id': id});
      if (resp.data is Map && resp.data['success'] == false) {
        throw Exception(resp.data['error']);
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<void> toggleStatus(int id, bool isActive) async {
    try {
      // 快捷上下架直接传 JSON
      final resp = await dio.patch(
        '/products/$id/status',
        data: {'is_active': isActive},
      );
      if (resp.data is Map && resp.data['success'] == false) {
        throw Exception(resp.data['error']);
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<Map<String, dynamic>> createOrder(
    List<Map<String, dynamic>> items, {
    String paymentMethod = 'cash',
    String orderStatus = 'completed',
    required String idempotencyKey,
  }) async {
    try {
      final payload = {
        'payment_method': paymentMethod,
        'order_status': orderStatus,
        'items': items,
        'idempotency_key': idempotencyKey,
      };
      final response = await dio.post('/orders', data: payload);
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] ?? {};
      }
      throw Exception(response.data['error'] ?? '未知错误');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) throw Exception('订单已存在，请勿重复结账');
      throw Exception(_handleDioError(e));
    }
  }

  /// 获取设备激活码（硬件信息 → 后端生成）
  Future<Map<String, dynamic>> getActivationCode({
    required String deviceId,
    String manufacturer = '',
    String model = '',
  }) async {
    try {
      final resp = await dio.post('/activate/code', data: {
        'device_id': deviceId,
        'manufacturer': manufacturer,
        'model': model,
      });
      if (resp.data['success'] == true) {
        return Map<String, dynamic>.from(resp.data['data']);
      }
      throw Exception(resp.data['error'] ?? '获取激活码失败');
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }
}
