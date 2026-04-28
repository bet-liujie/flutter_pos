import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

/// MDM服务 - 仅在Android平台生效
/// 通过 MethodChannel 调用原生 DevicePolicyManager API
class MdmService {
  static final MdmService _instance = MdmService._internal();
  factory MdmService() => _instance;
  MdmService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const MethodChannel _channel = MethodChannel('com.example.pos_app/mdm');

  Timer? _heartbeatTimer;
  String? _deviceId;
  String? _appVersion;

  // Dio 实例用于心跳上报
  late Dio _dio;

  /// 初始化心跳上报
  Future<void> initHeartbeat({required String baseUrl}) async {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer test-token-123';
          return handler.next(options);
        },
      ),
    );

    if (!isAndroid) return;

    final info = await _deviceInfo.androidInfo;
    _deviceId = info.id;
    _appVersion = '1.0.0'; // TODO: 从 package_info_plus 获取

    // 提前请求位置权限（Activity 前台时），避免心跳定时器触发时弹窗
    await _requestLocationPermission();

    // 启动定时器，每 60 秒上报一次心跳
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _reportHeartbeat(),
    );

    debugPrint('MDM心跳上报已启动，设备ID: $_deviceId');
  }

  /// 停止心跳上报
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 执行一次心跳上报
  Future<void> _reportHeartbeat() async {
    if (!isAndroid || _deviceId == null) return;

    try {
      final location = await _getLocation();
      final storageInfo = await _getStorageInfo();
      final networkType = _getNetworkType();

      await _dio.post(
        '/devices/$_deviceId/heartbeat',
        data: {
          'storage_usage': storageInfo['storage_usage'],
          'memory_usage': storageInfo['memory_usage'],
          'network_type': networkType,
          'signal_strength': null,
          'app_version': _appVersion,
          'latitude': location['latitude'],
          'longitude': location['longitude'],
        },
      );
    } catch (e) {
      debugPrint('心跳上报失败: $e');
    }
  }

  /// 获取存储和内存使用率（粗略估算）
  Future<Map<String, double>> _getStorageInfo() async {
    // TODO: 通过 MethodChannel 获取精确的存储/内存数据
    // 目前返回默认值
    try {
      final stat = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStorageInfo');
      if (stat != null) {
        return Map<String, double>.from(stat);
      }
    } catch (_) {}
    return {'storage_usage': 0.0, 'memory_usage': 0.0};
  }

  /// 获取网络类型
  String _getNetworkType() {
    // TODO: 通过 connectivity_plus 获取实际网络类型
    return 'wifi';
  }

  /// 获取设备位置（GPS坐标）
  /// 收银机固定位置，获取一次后缓存，避免频繁GPS唤醒
  Future<Map<String, double?>> _getLocation() async {
    if (!isAndroid) return {'latitude': null, 'longitude': null};

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('位置服务未开启');
        return {'latitude': null, 'longitude': null};
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // 权限未决定，主动请求
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('位置权限未授予');
        return {'latitude': null, 'longitude': null};
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // 收银机位置固定，低精度省电
          timeLimit: Duration(seconds: 10),
        ),
      );

      return {'latitude': pos.latitude, 'longitude': pos.longitude};
    } catch (e) {
      debugPrint('获取位置失败: $e');
      return {'latitude': null, 'longitude': null};
    }
  }

  /// 在 Activity 前台时提前请求位置权限
  Future<void> _requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('请求位置权限失败: $e');
    }
  }

  /// 检查是否为Android平台
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// 获取设备信息
  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (!isAndroid) {
      return {'platform': 'non-android', 'supported': false};
    }

    try {
      final androidInfo = await _deviceInfo.androidInfo;
      return {
        'platform': 'android',
        'supported': true,
        'manufacturer': androidInfo.manufacturer,
        'model': androidInfo.model,
        'androidVersion': androidInfo.version.release,
        'sdkInt': androidInfo.version.sdkInt,
        'brand': androidInfo.brand,
        'device': androidInfo.device,
        'id': androidInfo.id,
      };
    } catch (e) {
      return {'platform': 'android', 'supported': false, 'error': e.toString()};
    }
  }

  /// 通过 DevicePolicyManager 锁定屏幕
  Future<bool> lockScreen() async {
    if (!isAndroid) return false;

    try {
      await _channel.invokeMethod('lockScreen');
      return true;
    } catch (e) {
      debugPrint('锁屏失败: $e');
      return false;
    }
  }

  /// 检查是否有设备管理员权限
  Future<bool> hasDeviceAdminPermission() async {
    if (!isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('hasDeviceAdminPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('检查设备管理员权限失败: $e');
      return false;
    }
  }

  /// 请求设备管理员权限（跳转系统授权页面）
  Future<void> requestDeviceAdminPermission() async {
    if (!isAndroid) return;

    try {
      await _channel.invokeMethod('requestDeviceAdminPermission');
    } catch (e) {
      debugPrint('请求设备管理员权限失败: $e');
    }
  }

  /// 检查是否处于 Kiosk 模式（锁定任务模式）
  Future<bool> isKioskModeEnabled() async {
    if (!isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('isKioskModeEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('检查Kiosk模式失败: $e');
      return false;
    }
  }

  /// 启用 Kiosk 模式（锁定当前应用）
  Future<bool> enableKioskMode() async {
    if (!isAndroid) return false;

    try {
      await _channel.invokeMethod('enableKioskMode');
      return true;
    } catch (e) {
      debugPrint('启用Kiosk模式失败: $e');
      return false;
    }
  }

  /// 退出 Kiosk 模式（解锁任务）
  Future<bool> disableKioskMode() async {
    if (!isAndroid) return false;

    try {
      await _channel.invokeMethod('disableKioskMode');
      return true;
    } catch (e) {
      debugPrint('退出Kiosk模式失败: $e');
      return false;
    }
  }

  /// 获取电池信息（通过原生方式）
  Future<Map<String, dynamic>> getBatteryInfo() async {
    if (!isAndroid) {
      return {'supported': false};
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getBatteryInfo');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return {'supported': false, 'error': '返回数据为空'};
    } catch (e) {
      debugPrint('获取电池信息失败: $e');
      return {'supported': false, 'error': e.toString()};
    }
  }

  /// 获取设备唯一标识符 (用于激活和心跳)
  Future<String?> getDeviceId() async {
    if (!isAndroid) return null;
    try {
      final info = await _deviceInfo.androidInfo;
      return info.id;
    } catch (e) {
      debugPrint('获取设备ID失败: $e');
      return null;
    }
  }

  /// 打开设备管理员设置页面
  Future<void> openDeviceAdminSettings() async {
    if (!isAndroid) return;

    try {
      const intent = AndroidIntent(
        action: 'android.settings.SECURITY_SETTINGS',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    } catch (e) {
      debugPrint('打开设备管理设置失败: $e');
    }
  }

  /// 打开应用详情页面
  Future<void> openAppSettings() async {
    if (!isAndroid) return;

    try {
      const intent = AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    } catch (e) {
      debugPrint('打开应用设置失败: $e');
    }
  }

  /// 打开WiFi设置
  Future<void> openWifiSettings() async {
    if (!isAndroid) return;

    try {
      const intent = AndroidIntent(
        action: 'android.settings.WIFI_SETTINGS',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    } catch (e) {
      debugPrint('打开WiFi设置失败: $e');
    }
  }

  // =================================================================
  // Device Owner (DPC) 能力—需要 adb shell dpm set-device-owner
  // =================================================================

  /// 检查是否已是 Device Owner
  Future<bool> isDeviceOwner() async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceOwner');
      return result ?? false;
    } catch (e) {
      debugPrint('检查Device Owner状态失败: $e');
      return false;
    }
  }

  /// 将指定包加入锁任务白名单（需 Device Owner）
  Future<bool> setLockTaskPackages(List<String> packages) async {
    if (!isAndroid) return false;
    try {
      await _channel.invokeMethod('setLockTaskPackages', {'packages': packages});
      return true;
    } catch (e) {
      debugPrint('设置锁任务白名单失败: $e');
      return false;
    }
  }

  /// 检查某包是否允许锁任务
  Future<bool> isLockTaskAllowed([String? package]) async {
    if (!isAndroid) return false;
    try {
      final args = package != null ? {'package': package} : null;
      final result = await _channel.invokeMethod<bool>('isLockTaskAllowed', args);
      return result ?? false;
    } catch (e) {
      debugPrint('检查锁任务权限失败: $e');
      return false;
    }
  }

  /// 启用 Kiosk 模式（先设锁任务白名单，再锁定）
  Future<bool> enableKioskModeWithLockTask() async {
    if (!isAndroid) return false;
    try {
      // 先将自己加入锁任务白名单
      await _channel.invokeMethod('setLockTaskPackages', {'packages': [await getPackageName()]});
      // 再进入锁任务模式
      await _channel.invokeMethod('enableKioskMode');
      return true;
    } catch (e) {
      debugPrint('启用Kiosk模式(DPC)失败: $e');
      return false;
    }
  }

  /// 获取当前包名（通过原生方式）
  Future<String> getPackageName() async {
    // 默认包名，实际使用时会由原生端返回正确值
    return 'com.example.pos_app';
  }

  /// 最后一次 MethodChannel 错误
  String? _lastError;
  String? get lastError => _lastError;

  /// 设置防卸载（需 Device Owner）
  Future<bool> setUninstallBlocked(bool blocked, {String? package}) async {
    if (!isAndroid) return false;
    try {
      await _channel.invokeMethod('setUninstallBlocked', {
        'blocked': blocked,
        if (package != null) 'package': package,
      });
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('设置防卸载失败: $_lastError');
      return false;
    }
  }

  /// 禁用/启用锁屏（需 Device Owner）
  Future<bool> setKeyguardDisabled(bool disabled) async {
    if (!isAndroid) return false;
    try {
      await _channel.invokeMethod('setKeyguardDisabled', {'disabled': disabled});
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('设置锁屏禁用失败: $_lastError');
      return false;
    }
  }

  /// 禁用/启用状态栏（需 Device Owner）
  Future<bool> setStatusBarDisabled(bool disabled) async {
    if (!isAndroid) return false;
    try {
      await _channel.invokeMethod('setStatusBarDisabled', {'disabled': disabled});
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('设置状态栏禁用失败: $_lastError');
      return false;
    }
  }

  /// 添加用户限制（需 Device Owner）
  /// 常用限制: 'no_usb_file_transfer', 'no_share_location', 'no_uninstall_apps',
  ///           'no_remove_managed_profile', 'no_modify_accounts', 'no_factory_reset'
  Future<bool> addUserRestriction(String restriction) async {
    if (!isAndroid) return false;
    try {
      await _channel.invokeMethod('addUserRestriction', {'restriction': restriction});
      return true;
    } catch (e) {
      debugPrint('添加用户限制失败: $e');
      return false;
    }
  }

  /// 移除用户限制（需 Device Owner）
  Future<bool> removeUserRestriction(String restriction) async {
    if (!isAndroid) return false;
    try {
      await _channel.invokeMethod('removeUserRestriction', {'restriction': restriction});
      return true;
    } catch (e) {
      debugPrint('移除用户限制失败: $e');
      return false;
    }
  }

  /// 恢复出厂设置（需 Device Admin）
  Future<bool> wipeData() async {
    if (!isAndroid) return false;
    try {
      await _channel.invokeMethod('wipeData');
      return true;
    } catch (e) {
      debugPrint('恢复出厂设置失败: $e');
      return false;
    }
  }
}
