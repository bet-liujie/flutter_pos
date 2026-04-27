import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/hardware_service.dart';
import '../../services/api_service.dart';
import '../../services/mdm_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isActivated;

  bool get isActivated => _isActivated;
  AuthProvider({required bool initialStatus}) : _isActivated = initialStatus;

  Future<void> activateDevice(String activationCode) async {
    if (activationCode.isNotEmpty) {
      final deviceId = await HardwareService.getDeviceId();
      debugPrint('[AuthProvider] Activating device with ID: $deviceId');

      // 调用后端激活接口
      final apiService = ApiService();
      try {
        final resp = await apiService.dio.post('/activate', data: {
          'device_id': deviceId,
          'license_key': activationCode,
        });

        if (resp.data['success'] != true) {
          throw Exception(resp.data['error'] ?? '激活失败');
        }

        debugPrint('[AuthProvider] Activation response: ${resp.data}');

        // 激活成功后启动心跳
        final mdmService = MdmService();
        if (mdmService.isAndroid) {
          await mdmService.initHeartbeat(baseUrl: 'http://192.168.43.251:8080');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_device_activated', true);
        _isActivated = true;
        notifyListeners();
      } catch (e) {
        debugPrint('[AuthProvider] Activation failed: $e');
        rethrow;
      }
    }
  }

  Future<void> deactivateDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_device_activated');
    _isActivated = false;
    notifyListeners();
  }
}
