import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  bool _isActivated = false;
  
  bool get isActivated => _isActivated;

  AuthProvider() {
    _loadActivationStatus();
  }

  // 初始化时读取硬盘状态
  Future<void> _loadActivationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isActivated = prefs.getBool('is_device_activated') ?? false;
    notifyListeners(); // 状态加载完后，通知界面和路由刷新
  }

  // 模拟激活设备的方法
  Future<void> activateDevice(String activationCode) async {
    // 假设调用了后端 API 并验证成功
    if (activationCode.isNotEmpty) { 
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_device_activated', true);
      _isActivated = true;
      notifyListeners(); // 通知路由：状态变了，该放行了！
    }
  }

  // 未来可能会用到的：解绑/退出设备
  Future<void> deactivateDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_device_activated');
    _isActivated = false;
    notifyListeners(); // 💥 通知路由：设备已下线，踢回激活页！
  }
}