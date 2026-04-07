import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> filteredProducts = [];
  bool isLoading = false;
  String? errorMessage;
  String _searchQuery = '';
  Timer? _timer;

  ProductProvider() {
    print('🚀 ProductProvider 初始化，启动定时器...');
    fetchProducts(showLoading: true);

    // 启动 5 秒一次的定时器
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      print('⏰ 定时器触发：正在静默检查数据更新...');
      fetchProducts(showLoading: false);
    });
  }

  @override
  void dispose() {
    print('🛑 ProductProvider 被销毁，关闭定时器');
    _timer?.cancel();
    super.dispose();
  }

  void runFilter(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      filteredProducts = _allProducts;
    } else {
      filteredProducts = _allProducts
          .where(
            (p) => p['name'].toString().toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
    }
    // 关键：必须通知 UI 刷新
    notifyListeners();
  }

  Future<void> fetchProducts({bool showLoading = false}) async {
    if (showLoading) {
      isLoading = true;
      notifyListeners();
    }

    try {
      final newData = await _api.getProducts();
      // 这里可以对比一下新老数据，如果没变就不跑 runFilter 了（可选优化）
      _allProducts = newData;
      errorMessage = null;
      runFilter(_searchQuery); // runFilter 内部会执行 notifyListeners()
      print('✅ 数据已同步，当前商品数：${_allProducts.length}');
    } catch (e) {
      print('❌ 定时刷新失败: $e');
      errorMessage = '数据加载失败，请检查网络';
    } finally {
      if (showLoading) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveProduct(
    String name,
    double price, {
    int? id,
    required BuildContext context,
  }) async {
    try {
      if (id == null) {
        // 调用 Service 新增
        await _api.addProduct(name, price);
      } else {
        // 调用 Service 更新
        await _api.updateProduct(id, name, price);
      }

      // 操作成功后，手动触发一次带 Loading 的刷新
      await fetchProducts(showLoading: true);

      // 成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(id == null ? '添加成功: $name' : '更新成功: $name'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('保存失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('操作失败，请检查网络'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// 删除商品
  Future<void> deleteProduct(int id, String name, BuildContext context) async {
    try {
      await _api.deleteProduct(id);
      await fetchProducts(showLoading: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除: $name'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('删除失败'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
