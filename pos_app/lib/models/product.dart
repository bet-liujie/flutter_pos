import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

// 继承 ChangeNotifier，意味着它拥有了“通知界面刷新”的超能力
class ProductProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> allProducts = [];
  bool isLoading = false;
  Timer? _timer;

  ProductProvider() {
    fetchProducts(showLoading: true);
    _startPolling(); // 启动后台轮询
  }

  @override
  void dispose() {
    _timer?.cancel(); // 销毁时自动关闭定时器
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => fetchProducts(showLoading: false),
    );
  }

  Future<void> fetchProducts({bool showLoading = false}) async {
    if (showLoading) {
      isLoading = true;
      notifyListeners(); // 👈 告诉页面：开始转圈圈啦！
    }

    try {
      allProducts = await _api.getProducts();
    } catch (e) {
      print('网络错误: $e');
    } finally {
      isLoading = false;
      notifyListeners(); // 👈 告诉页面：数据拿到了，刷新列表吧！
    }
  }
}
