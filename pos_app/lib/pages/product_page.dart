import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  // 这里的弹出表单逻辑和之前一样，只是提交时调用 provider
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? '编辑商品' : '新增商品',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '商品名称',
                prefixIcon: Icon(Icons.shopping_bag_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '商品价格',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final price = double.tryParse(priceCtrl.text.trim());
                  if (name.isNotEmpty && price != null) {
                    Navigator.pop(ctx);
                    context.read<ProductProvider>().saveProduct(
                      name,
                      price,
                      id: existingProduct?['id'],
                      context: context,
                    );
                  }
                },
                child: Text(isEditing ? '保存修改' : '确认添加'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 👇 补充缺失的空状态视图
  Widget _buildEmptyState() {
    return ListView(
      children: const [
        SizedBox(height: 100),
        Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
        SizedBox(height: 16),
        Center(
          child: Text(
            '没有找到相关商品',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. 使用 read，这样 provider 更新时，整个 Scaffold 不会重绘
    final provider = context.read<ProductProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('商品库', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        // 👇 把搜索框补回来，它不需要放进 Consumer，因为它只是触发动作
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              onChanged: provider.runFilter,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(context),
        icon: const Icon(Icons.add),
        label: const Text('添加商品'),
      ),
      // 2. 只在需要变动的列表区域使用 Consumer
      // 2. 只在需要变动的列表区域使用 Consumer
      body: Consumer<ProductProvider>(
        builder: (context, pro, child) {
          // 状态 1：正在首次加载中
          if (pro.isLoading && pro.filteredProducts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // 状态 2：💥 拦截并展示网络错误！
          // 如果 provider 里存了错误信息，且当前屏幕上没有数据，就显示断网插画
          if (pro.errorMessage != null && pro.filteredProducts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 80,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    pro.errorMessage!, // 加上感叹号，表示我们确定它此时不为空
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => pro.fetchProducts(showLoading: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新连接'),
                  ),
                ],
              ),
            );
          }

          // 状态 3：正常渲染商品列表（包含完全搜索不到时的空状态）
          return RefreshIndicator(
            onRefresh: () => pro.fetchProducts(showLoading: true),
            child: pro.filteredProducts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemExtent: 90, // 提升 POS 机滑动性能
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 80,
                    ),
                    itemCount: pro.filteredProducts.length,
                    itemBuilder: (context, index) {
                      return ProductCard(
                        product: pro.filteredProducts[index],
                        onEdit: (p) => _showProductForm(context, p),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 👇 补充缺失的独立卡片组件（放在同一个文件最底下即可）
// ==========================================
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final Function(Map<String, dynamic>) onEdit; // 用于接收编辑事件

  const ProductCard({super.key, required this.product, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0, // 去掉阴影减轻 GPU 负担
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.coffee,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          product['name'] ?? '未知商品',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '￥${product['price']}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              onEdit(product); // 触发外界传进来的弹窗回调
            }
            if (value == 'delete') {
              // 触发删除逻辑
              context.read<ProductProvider>().deleteProduct(
                product['id'],
                product['name'],
                context,
              );
            }
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
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('删除', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
