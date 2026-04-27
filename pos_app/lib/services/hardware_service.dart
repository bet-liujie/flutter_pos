// 文件路径: pos_app/lib/services/hardware_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // 新增：引入跨端通信服务
import 'package:device_info_plus/device_info_plus.dart';

class HardwareService {
  // 新增：定义专属的 MethodChannel 通道标识，需与原生端严格一致
  static const platform = MethodChannel('com.example.pos_app/hardware');
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// 获取底层物理设备的唯一标识符
  static Future<String> getDeviceId() async {
    try {
      if (kIsWeb) {
        return 'web-dev-mock-device-id';
      }

      if (Platform.isLinux) {
        final file = File('/etc/machine-id');
        if (await file.exists()) {
          final machineId = await file.readAsString();
          return 'linux-${machineId.trim()}';
        }
        return 'linux-static-mock-id';
      } else if (Platform.isAndroid) {
        // --- 新增：Android 平台的 MethodChannel 调用逻辑 ---
        try {
          // 向 Android 原生端发送 'getAndroidNativeId' 方法请求
          final String result = await platform.invokeMethod(
            'getAndroidNativeId',
          );
          return 'android-$result';
        } on PlatformException catch (e) {
          debugPrint('[HardwareService] MethodChannel 调用失败: ${e.message}');
          // 使用 device_info_plus 作为降级
          try {
            final info = await _deviceInfo.androidInfo;
            return 'android-${info.id}';
          } catch (_) {
            return 'android-fallback-static-id';
          }
        }
        // ------------------------------------------------
      } else if (Platform.isWindows) {
        return 'windows-local-mock-id';
      }

      return 'unsupported-platform-static-id';
    } catch (e) {
      debugPrint('[HardwareService] 获取硬件 ID 全局异常: $e');
      return 'error-fallback-static-device-id';
    }
  }

  /// 获取设备详细信息（厂商、型号等）
  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      if (kIsWeb) {
        return {'manufacturer': 'web', 'model': 'browser'};
      }

      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return {
          'manufacturer': info.manufacturer,
          'model': info.model,
          'androidVersion': info.version.release,
        };
      } else if (Platform.isLinux) {
        return {'manufacturer': 'linux', 'model': 'pc'};
      }
      return {'manufacturer': 'unknown', 'model': 'unknown'};
    } catch (e) {
      debugPrint('[HardwareService] 获取设备信息失败: $e');
      return {'manufacturer': 'unknown', 'model': 'unknown'};
    }
  }
}
