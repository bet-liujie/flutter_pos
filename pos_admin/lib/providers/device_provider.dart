import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../services/api_service.dart';

class DeviceProvider extends ChangeNotifier {
  List<Device> _devices = [];
  DeviceDetail? _deviceDetail;
  List<CommandInfo> _commandHistory = [];

  bool _isLoading = false;
  String? _error;

  int _total = 0;
  int _page = 1;
  final int _pageSize = 20;
  String? _statusFilter;
  String? _keyword;

  Timer? _autoRefreshTimer;

  // Getters
  List<Device> get devices => _devices;
  DeviceDetail? get deviceDetail => _deviceDetail;
  List<CommandInfo> get commandHistory => _commandHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get total => _total;
  int get page => _page;
  int get pageSize => _pageSize;
  int get totalPages => (_total / _pageSize).ceil();
  String? get statusFilter => _statusFilter;
  String? get keyword => _keyword;

  /// 加载设备列表
  Future<void> loadDevices({
    int? page,
    String? status,
    String? keyword,
    bool append = false,
  }) async {
    _isLoading = true;
    _error = null;
    if (!append) notifyListeners();

    try {
      if (page != null) _page = page;
      if (status != null) _statusFilter = status;
      if (keyword != null) _keyword = keyword;

      final api = ApiService();
      final data = await api.getDevices(
        page: _page,
        pageSize: _pageSize,
        status: _statusFilter,
        keyword: _keyword,
      );

      final list = (data['devices'] as List)
          .map((e) => Device.fromJson(e as Map<String, dynamic>))
          .toList();

      _total = data['total'] as int? ?? 0;
      _devices = list;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 加载设备详情
  Future<void> loadDeviceDetail(String deviceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final data = await api.getDeviceDetail(deviceId);
      _deviceDetail = DeviceDetail.fromJson(data);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 加载命令历史
  Future<void> loadCommandHistory(String deviceId) async {
    try {
      final api = ApiService();
      final data = await api.getCommandHistory(deviceId);
      _commandHistory = data
          .map((e) => CommandInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('加载命令历史失败: $e');
    }
  }

  /// 下发命令
  Future<bool> sendCommand(
    String deviceId,
    String command, {
    Map<String, dynamic> params = const {},
  }) async {
    try {
      final api = ApiService();
      await api.sendCommand(deviceId, command, params: params);
      await loadCommandHistory(deviceId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 更新设备状态
  Future<bool> updateDeviceStatus(String deviceId, String status) async {
    try {
      final api = ApiService();
      await api.updateDeviceStatus(deviceId, status);
      await loadDeviceDetail(deviceId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 搜索
  void search(String keyword) {
    _keyword = keyword;
    _page = 1;
    loadDevices();
  }

  /// 筛选状态
  void filterStatus(String? status) {
    _statusFilter = status;
    _page = 1;
    loadDevices();
  }

  /// 翻页
  void goToPage(int page) {
    if (page < 1 || page > totalPages) return;
    loadDevices(page: page);
  }

  /// 启动自动刷新
  void startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      loadDevices();
    });
  }

  /// 停止自动刷新
  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
