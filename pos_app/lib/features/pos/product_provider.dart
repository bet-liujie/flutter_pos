import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'product_models.dart'; // 👈 完美引入你的图纸

class ProductProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Product> _allProducts = [];
  List<Product> filteredProducts = [];
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
            // 💥 修复 1：使用强类型点语法 p.name
            (p) => p.name.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }
    notifyListeners();
  }

  Future<void> fetchProducts({bool showLoading = false}) async {
    if (showLoading) {
      isLoading = true;
      notifyListeners();
    }

    try {
      final newData = await _api.getProducts();
      // 💥 修复 2：把后端传来的 Map 列表，加工转换成 Product 对象列表
      _allProducts = newData.map((json) => Product.fromJson(json)).toList();

      errorMessage = null;
      runFilter(_searchQuery);
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

  /// 1. 新增商品
  Future<void> addProduct(
    String name,
    double price,
    int stock,
    String desc,
    bool isActive,
    XFile? image,
    BuildContext context,
  ) async {
    // ✨ 核心修复：在异步操作开始前，提前捕获 ScaffoldMessenger
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.addProduct(name, price, stock, desc, isActive, image);
      await fetchProducts(showLoading: true);
      messenger.showSnackBar(
        const SnackBar(content: Text('添加成功'), backgroundColor: Colors.green),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('添加失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// 2. 更新商品
  Future<void> updateProduct(
    int id,
    String name,
    double price,
    int stock,
    String desc,
    bool isActive,
    XFile? image,
    BuildContext context,
  ) async {
    final messenger = ScaffoldMessenger.of(context); // ✨ 提前捕获
    try {
      await _api.updateProduct(id, name, price, stock, desc, isActive, image);
      await fetchProducts(showLoading: true);
      messenger.showSnackBar(
        const SnackBar(content: Text('更新成功'), backgroundColor: Colors.green),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('更新失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 3. 快捷切换上下架
  Future<void> toggleProductStatus(
    int id,
    bool currentStatus,
    BuildContext context,
  ) async {
    final messenger = ScaffoldMessenger.of(context); // ✨ 提前捕获
    final newStatus = !currentStatus;

    final index = _allProducts.indexWhere((p) => p.id == id);
    if (index != -1) {
      final old = _allProducts[index];
      _allProducts[index] = Product(
        id: old.id,
        name: old.name,
        price: old.price,
        stock: old.stock,
        description: old.description,
        isActive: newStatus,
        imageUrl: old.imageUrl,
      );
      runFilter(_searchQuery);
    }

    try {
      await _api.toggleStatus(id, newStatus);
      messenger.showSnackBar(
        SnackBar(
          content: Text(newStatus ? '已上架' : '已下架'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (index != -1) {
        final old = _allProducts[index];
        _allProducts[index] = Product(
          id: old.id,
          name: old.name,
          price: old.price,
          stock: old.stock,
          description: old.description,
          isActive: currentStatus,
          imageUrl: old.imageUrl,
        );
        runFilter(_searchQuery);
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('状态切换失败'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// 4. 删除商品
  Future<void> deleteProduct(int id, String name, BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context); // ✨ 提前捕获，彻底解决卡死和报错
    try {
      await _api.deleteProduct(id);
      await fetchProducts(showLoading: true);
      messenger.showSnackBar(
        SnackBar(content: Text('已删除: $name'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('删除失败'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
