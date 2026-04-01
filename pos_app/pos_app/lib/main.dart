import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

/// 应用程序入口
void main() {
  // 确保 Flutter 绑定已初始化（用于异步操作等）
  WidgetsFlutterBinding.ensureInitialized();
  // 启动主应用
  runApp(const PosApp());
}

/// 主应用类，负责全局主题和首页配置
class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS 现代管理系统', // 应用标题
      debugShowCheckedModeBanner: false, // 关闭右上角 debug 标识
      theme: ThemeData(
        // 启用 Material 3 并设置主题色
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      home: const ProductPage(), // 设置首页为商品页
    );
  }
}

/// 商品页，支持商品的增删改查和搜索
class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  // API 基础地址
  final String apiBase = 'http://192.168.43.251:8080/products';
  // Dio 实例用于网络请求
  final dio = Dio();

  // 所有商品数据
  List<Map<String, dynamic>> _allProducts = [];
  // 搜索过滤后的商品数据
  List<Map<String, dynamic>> _filteredProducts = [];

  // 加载状态
  bool _isLoading = false;
  // 当前搜索关键字
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // 初始化时拉取商品数据
    _fetchProducts();
  }

  // ================== API 请求区 ==================

  /// 拉取商品列表
  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final resp = await dio.get(apiBase);
      if (resp.statusCode == 200) {
        // 从响应中提取商品列表
        final items = List<Map<String, dynamic>>.from(resp.data['items'] ?? []);
        setState(() {
          _allProducts = items;
          _runFilter(_searchQuery); // 保持当前搜索状态
        });
      }
    } catch (e) {
      _showSnackBar('网络连接失败，请检查后端服务', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 新增或更新商品
  Future<void> _saveProduct(String name, double price, {int? id}) async {
    try {
      if (id == null) {
        // 新增商品
        await dio.post(apiBase, data: {'name': name, 'price': price});
        _showSnackBar('添加成功: $name');
      } else {
        // 更新商品
        await dio.put(apiBase, data: {'id': id, 'name': name, 'price': price});
        _showSnackBar('更新成功: $name');
      }
      _fetchProducts(); // 操作后刷新列表
    } catch (e) {
      _showSnackBar(id == null ? '添加失败' : '更新失败', isError: true);
    }
  }

  /// 删除商品
  Future<void> _deleteProduct(int id, String name) async {
    try {
      await dio.delete('$apiBase?id=$id');
      _showSnackBar('已删除: $name');
      _fetchProducts();
    } catch (e) {
      _showSnackBar('删除失败', isError: true);
    }
  }

  // ================== 逻辑与交互区 ==================

  /// 根据关键字过滤商品
  void _runFilter(String enteredKeyword) {
    setState(() {
      _searchQuery = enteredKeyword;
      if (enteredKeyword.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts
            .where(
              (p) => (p['name'] ?? '').toString().toLowerCase().contains(
                enteredKeyword.toLowerCase(),
              ),
            )
            .toList();
      }
    });
  }

  /// 显示提示信息
  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating, // 悬浮样式
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// 显示商品表单（新增/编辑）
  void _showProductForm(
    BuildContext context, [
    Map<String, dynamic>? existingProduct,
  ]) {
    final nameCtrl = TextEditingController(text: existingProduct?['name']);
    final priceCtrl = TextEditingController(
      text: existingProduct?['price']?.toString(),
    );
    final isEditing = existingProduct != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允许弹窗高度自适应
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          // 处理键盘遮挡
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? '编辑商品' : '新增商品',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // 商品名称输入框
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: '商品名称',
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 商品价格输入框
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '商品价格 (￥)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 提交按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final price = double.tryParse(priceCtrl.text.trim());
                    if (name.isEmpty || price == null) {
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(const SnackBar(content: Text('请填写有效的信息')));
                      return;
                    }
                    Navigator.of(ctx).pop();
                    _saveProduct(name, price, id: existingProduct?['id']);
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEditing ? '保存修改' : '确认添加',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// 删除商品前的二次确认弹窗
  void _confirmDelete(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除?'),
        content: Text('您确定要删除商品 "${product['name']}" 吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteProduct(product['id'], product['name']);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // ================== UI 构建区 ==================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('商品库', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // 移除下拉时的蒙层颜色
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              onChanged: _runFilter,
              decoration: InputDecoration(
                hintText: '搜索商品名称...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      // 悬浮添加按钮
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(context),
        icon: const Icon(Icons.add),
        label: const Text('添加商品'),
      ),
      body: _isLoading
          // 加载中显示进度条
          ? const Center(child: CircularProgressIndicator())
          // 主体内容支持下拉刷新
          : RefreshIndicator(
              onRefresh: _fetchProducts,
              child: _filteredProducts.isEmpty
                  // 无数据时的占位界面
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.2,
                        ),
                        const Icon(
                          Icons.inbox_outlined,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            '没有找到相关商品',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  // 有数据时的商品列表
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: 80,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final p = _filteredProducts[index];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.coffee, // 商品图标（可自定义）
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            title: Text(
                              p['name'] ?? '未知商品',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '￥${p['price']}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // 操作菜单（编辑/删除）
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit')
                                  _showProductForm(context, p);
                                if (value == 'delete') _confirmDelete(p);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('编辑'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    title: Text(
                                      '删除',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
