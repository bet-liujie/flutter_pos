import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/policy.dart';
import '../services/api_service.dart';

class PolicyProvider extends ChangeNotifier {
  List<Policy> _policies = [];
  PolicyDetail? _policyDetail;
  bool _isLoading = false;
  String? _error;

  int _total = 0;
  int _page = 1;
  final int _pageSize = 20;

  // Getters
  List<Policy> get policies => _policies;
  PolicyDetail? get policyDetail => _policyDetail;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get total => _total;
  int get page => _page;
  int get pageSize => _pageSize;
  int get totalPages => (_total / _pageSize).ceil();

  /// 加载策略列表
  Future<void> loadPolicies({int? page}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (page != null) _page = page;

      final api = ApiService();
      final data = await api.getPolicies(page: _page, pageSize: _pageSize);

      final list = (data['policies'] as List)
          .map((e) => Policy.fromJson(e as Map<String, dynamic>))
          .toList();

      _total = data['total'] as int? ?? 0;
      _policies = list;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 加载策略详情
  Future<void> loadPolicyDetail(int policyId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final data = await api.getPolicyDetail(policyId);
      _policyDetail = PolicyDetail.fromJson(data);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 创建策略
  Future<bool> createPolicy({
    required String policyName,
    Map<String, dynamic> policyData = const {},
    bool isActive = true,
  }) async {
    try {
      final api = ApiService();
      await api.createPolicy(
        policyName: policyName,
        policyData: policyData,
        isActive: isActive,
      );
      await loadPolicies();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 更新策略
  Future<bool> updatePolicy(int policyId, {
    String? policyName,
    Map<String, dynamic>? policyData,
    bool? isActive,
  }) async {
    try {
      final api = ApiService();
      await api.updatePolicy(policyId,
        policyName: policyName,
        policyData: policyData,
        isActive: isActive,
      );
      await loadPolicyDetail(policyId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 删除策略
  Future<bool> deletePolicy(int policyId) async {
    try {
      final api = ApiService();
      await api.deletePolicy(policyId);
      _policyDetail = null;
      await loadPolicies();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 绑定策略到设备
  Future<bool> bindDevices(int policyId, List<String> deviceIds) async {
    try {
      final api = ApiService();
      await api.bindDevices(policyId, deviceIds);
      await loadPolicyDetail(policyId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 解绑设备
  Future<bool> unbindDevice(int policyId, String deviceId) async {
    try {
      final api = ApiService();
      await api.unbindDevice(policyId, deviceId);
      await loadPolicyDetail(policyId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 翻页
  void goToPage(int page) {
    if (page < 1 || page > totalPages) return;
    loadPolicies(page: page);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
