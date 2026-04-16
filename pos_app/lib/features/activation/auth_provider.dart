import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/hardware_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isActivated;

  bool get isActivated => _isActivated;
  AuthProvider({required bool initialStatus}) : _isActivated = initialStatus;

  Future<void> activateDevice(String activationCode) async {
    if (activationCode.isNotEmpty) {
      final deviceId = await HardwareService.getDeviceId();
      debugPrint('[AuthProvider] Activating device with ID: $deviceId');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_device_activated', true);
      _isActivated = true;
      notifyListeners();
    }
  }

  Future<void> deactivateDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_device_activated');
    _isActivated = false;
    notifyListeners();
  }
}
