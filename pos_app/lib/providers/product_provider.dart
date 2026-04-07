import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:image_picker/image_picker.dart';

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
    double price,
    String desc,
    bool isActive,
    XFile? image, {
    int? id,
    required BuildContext context,
  }) async {
    try {
      if (id == null) {
        await _api.addProduct(name, price, desc, isActive, image);
      } else {
        await _api.updateProduct(id, name, price, desc, isActive, image);
      }
      await fetchProducts(showLoading: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(id == null ? '添加成功' : '更新成功'),
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

  // 💥 新增：快捷切换上下架
  Future<void> toggleProductStatus(
    int id,
    bool currentStatus,
    BuildContext context,
  ) async {
    final newStatus = !currentStatus;
    // 先在本地 UI 乐观更新（让开关瞬间拨过去，不卡顿）
    final index = _allProducts.indexWhere((p) => p['id'] == id);
    if (index != -1) {
      _allProducts[index]['is_active'] = newStatus;
      runFilter(_searchQuery);
    }

    try {
      await _api.toggleStatus(id, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? '已上架' : '已下架'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // 如果后端请求失败，把状态回滚
      if (index != -1) {
        _allProducts[index]['is_active'] = currentStatus;
        runFilter(_searchQuery);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('状态切换失败'),
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
