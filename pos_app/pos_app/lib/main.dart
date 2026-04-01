import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

// 1. 标准入口函数
void main() {
  // 确保 Flutter 引擎初始化
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS 管理系统',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ProductPage(),
    );
  }
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final String apiBase = 'http://localhost:8080/products';
  final dio = Dio();
  List<Map<String, dynamic>> _products = [];
  bool _loading = false;
  bool _btnLoading = false;
  String? _error;
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await dio.get(apiBase);
      if (resp.statusCode == 200) {
        final data = resp.data;
        setState(() {
          _products = List<Map<String, dynamic>>.from(data['items'] ?? []);
        });
      }
    } catch (e) {
      setState(() => _error = '无法连接后端，请确保 dart_frog 已启动');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addProduct() async {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.trim();
    final price = double.tryParse(priceStr);
    if (name.isEmpty || price == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('名称或价格格式错误')));
      return;
    }
    setState(() => _btnLoading = true);
    try {
      final resp = await dio.post(
        apiBase,
        data: {'name': name, 'price': price},
      );
      if (resp.statusCode == 200) {
        _nameController.clear();
        _priceController.clear();
        _fetchProducts();
      }
    } catch (e) {
      setState(() => _error = '添加失败，请检查后端');
    } finally {
      setState(() => _btnLoading = false);
    }
  }

  Future<void> _deleteProduct(int id) async {
    setState(() => _btnLoading = true);
    try {
      final resp = await dio.delete('$apiBase?id=$id');
      if (resp.statusCode == 200) {
        _fetchProducts();
      }
    } catch (e) {
      setState(() => _error = '删除失败');
    } finally {
      setState(() => _btnLoading = false);
    }
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final name = await _showEditDialog(product['name']);
    if (name == null || name.isEmpty) return;
    setState(() => _btnLoading = true);
    try {
      await dio.put(
        apiBase,
        data: {'id': product['id'], 'name': name, 'price': product['price']},
      );
      _fetchProducts();
    } catch (e) {
      setState(() => _error = '修改失败');
    } finally {
      setState(() => _btnLoading = false);
    }
  }

  Future<String?> _showEditDialog(String oldName) async {
    final controller = TextEditingController(text: oldName);
    return showDialog<String>(
      context: context,
      builder: (ctx) => EditProductDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS 商品管理'),
        actions: [
          IconButton(
            onPressed: _fetchProducts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ProductInputArea(
                    nameController: _nameController,
                    priceController: _priceController,
                    btnLoading: _btnLoading,
                    onAdd: _addProduct,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ProductList(
                      products: _products,
                      btnLoading: _btnLoading,
                      onEdit: _editProduct,
                      onDelete: _deleteProduct,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class ProductInputArea extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final bool btnLoading;
  final VoidCallback onAdd;
  const ProductInputArea({
    super.key,
    required this.nameController,
    required this.priceController,
    required this.btnLoading,
    required this.onAdd,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: '商品名'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: priceController,
                decoration: const InputDecoration(hintText: '价格'),
                keyboardType: TextInputType.number,
              ),
            ),
            ElevatedButton(
              onPressed: btnLoading ? null : onAdd,
              child: btnLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductList extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final bool btnLoading;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(int) onDelete;
  const ProductList({
    super.key,
    required this.products,
    required this.btnLoading,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const Center(child: Text('暂无商品，请先添加'));
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, i) {
        final p = products[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${p['id']}')),
            title: Text(p['name'] ?? '未知'),
            subtitle: Text('价格: ￥${p['price']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: btnLoading ? null : () => onEdit(p),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: btnLoading ? null : () => onDelete(p['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class EditProductDialog extends StatelessWidget {
  final TextEditingController controller;
  const EditProductDialog({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改商品名'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '新商品名'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
