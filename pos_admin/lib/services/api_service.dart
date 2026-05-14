import 'package:dio/dio.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// API 基础地址，通过 --dart-define=API_BASE_URL=... 传入
  /// 默认值用于局域网调试
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.43.251:8080',
  );

  late Dio _dio;
  String? _token;

  Dio get dio => _dio;

  bool get isLoggedIn => _token != null;

  void setToken(String token) {
    _token = token;
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer $token';
          return handler.next(options);
        },
      ),
    );
  }

  void clearToken() {
    _token = null;
  }

  String _handleError(dynamic e) {
    if (e is DioException) {
      if (e.response?.data != null &&
          e.response!.data is Map &&
          e.response!.data['error'] != null) {
        return e.response!.data['error'].toString();
      }
      return '请求失败: ${e.message}';
    }
    return e.toString();
  }

  /// 管理员登录
  Future<Map<String, dynamic>> login(String username, String password) async {
    final tempDio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    try {
      final resp = await tempDio.post('/admin/login', data: {
        'username': username,
        'password': password,
      });
      if (resp.data['success'] == true) {
        return Map<String, dynamic>.from(resp.data['data']);
      }
      throw Exception(resp.data['error'] ?? '登录失败');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// 获取设备列表
  Future<Map<String, dynamic>> getDevices({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? keyword,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;

      final resp = await dio.get('/devices', queryParameters: params);
      if (resp.data['success'] == true) {
        return Map<String, dynamic>.from(resp.data['data']);
      }
      throw Exception(resp.data['error'] ?? '获取设备列表失败');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// 获取设备详情
  Future<Map<String, dynamic>> getDeviceDetail(String deviceId) async {
    try {
      final resp = await dio.get('/devices/$deviceId');
      if (resp.data['success'] == true) {
        return Map<String, dynamic>.from(resp.data);
      }
      throw Exception(resp.data['error'] ?? '获取设备详情失败');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// 更新设备状态
  Future<void> updateDeviceStatus(String deviceId, String status) async {
    try {
      final resp = await dio.put('/devices/$deviceId', data: {
        'status': status,
      });
      if (resp.data['success'] != true) {
        throw Exception(resp.data['error'] ?? '更新状态失败');
      }
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// 下发命令
  Future<int> sendCommand(
    String deviceId,
    String command, {
    Map<String, dynamic> params = const {},
  }) async {
    try {
      final resp = await dio.post('/devices/$deviceId/commands', data: {
        'command': command,
        'params': params,
      });
      if (resp.data['success'] == true) {
        return resp.data['data']['command_id'] as int;
      }
      throw Exception(resp.data['error'] ?? '下发命令失败');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// 获取命令历史
  Future<List<dynamic>> getCommandHistory(String deviceId) async {
    try {
      final resp = await dio.get('/devices/$deviceId/commands');
      if (resp.data['success'] == true) {
        return resp.data['data'] as List<dynamic>? ?? [];
      }
      throw Exception(resp.data['error'] ?? '获取命令历史失败');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // =================================================================
  // 策略管理 API
  // =================================================================

  /// 获取策略列表
  Future<Map<String, dynamic>> getPolicies({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final resp = await dio.get('/policies', queryParameters: {
        'page': page,
        'page_size': pageSize,
      });
      if (resp.data['success'] == true) {
        return Map<String, dynamic>.from(resp.data['data']);
      }
      throw Exception(resp.data['error'] ?? '获取策略列表失败');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// 获取策略详情
  Future<Map<String, dynamic>> getPolicyDetail(int policyId) async {
    try {
      final resp = await dio.get('/policies/$policyId');
      if (resp.data['success'] == true) {
        return Map<String, dynamic>.from(resp.data['data']);
      }
      throw Exception(resp.data['error'] ?? '获取策略详情失败');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// 创建策略
  Future<void> createPolicy({
    required String policyName,
    Map<String, dynamic> policyData = const {},
    bool isActive = true,
  }) async {
    try {
      final resp = await dio.post('/policies', data: {
        'policy_name': policyName,
        'policy_data': policyData,
        'is_active': isActive,
      });
      if (resp.data['success'] != true) {
        throw Exception(resp.data['error'] ?? '创建策略失败');
      }
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// 更新策略
  Future<void> updatePolicy(int policyId, {
    String? policyName,
    Map<String, dynamic>? policyData,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (policyName != null) data['policy_name'] = policyName;
      if (policyData != null) data['policy_data'] = policyData;
      if (isActive != null) data['is_active'] = isActive;

      final resp = await dio.put('/policies/$policyId', data: data);
      if (resp.data['success'] != true) {
        throw Exception(resp.data['error'] ?? '更新策略失败');
      }
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// 删除策略
  Future<void> deletePolicy(int policyId) async {
    try {
      final resp = await dio.delete('/policies/$policyId');
      if (resp.data['success'] != true) {
        throw Exception(resp.data['error'] ?? '删除策略失败');
      }
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// 绑定策略到设备
  Future<void> bindDevices(int policyId, List<String> deviceIds) async {
    try {
      final resp = await dio.post('/policies/$policyId/bind', data: {
        'device_ids': deviceIds,
      });
      if (resp.data['success'] != true) {
        throw Exception(resp.data['error'] ?? '绑定设备失败');
      }
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// 解绑设备
  Future<void> unbindDevice(int policyId, String deviceId) async {
    try {
      final resp = await dio.delete('/policies/$policyId/bind', queryParameters: {
        'device_id': deviceId,
      });
      if (resp.data['success'] != true) {
        throw Exception(resp.data['error'] ?? '解绑设备失败');
      }
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }
}
