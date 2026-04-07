import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/product_provider.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  // 💥 改造后的表单弹窗
  void _showProductForm(
    BuildContext context, [
    Map<String, dynamic>? existingProduct,
  ]) {
    final isEditing = existingProduct != null;
    final nameCtrl = TextEditingController(text: existingProduct?['name']);
    final priceCtrl = TextEditingController(
      text: existingProduct?['price']?.toString(),
    );
    final descCtrl = TextEditingController(
      text: existingProduct?['description'],
    );

    // 默认新商品是上架状态 (true)
    bool isActive = existingProduct?['is_active'] ?? true;
    XFile? selectedImage;
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        // 使用 StatefulBuilder 让弹窗内部可以独立刷新状态（比如选中图片后）
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? '编辑商品' : '新增商品',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            isActive ? '售卖中' : '已下架',
                            style: TextStyle(
                              color: isActive ? Colors.green : Colors.grey,
                            ),
                          ),
                          Switch(
                            value: isActive,
                            activeColor: Colors.green,
                            onChanged: (val) =>
                                setModalState(() => isActive = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 图片上传区域
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (image != null)
                          setModalState(() => selectedImage = image);
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            style: BorderStyle.solid,
                          ),
                          image: selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(File(selectedImage!.path)),
                                  fit: BoxFit.cover,
                                )
                              : (isEditing &&
                                    existingProduct['image_url'] != null)
                              ? DecorationImage(
                                  image: NetworkImage(
                                    existingProduct['image_url'],
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child:
                            (selectedImage == null &&
                                (existingProduct?['image_url'] == null))
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Colors.grey),
                                  SizedBox(height: 4),
                                  Text(
                                    '上传图片',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '商品名称*',
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
                      labelText: '商品价格*',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '商品详情描述',
                      hintText: '例如：选用新鲜食材，纯手工制作...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orangeAccent.shade700,
                      ),
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        final price = double.tryParse(priceCtrl.text.trim());
                        if (name.isNotEmpty && price != null) {
                          Navigator.pop(ctx);
                          context.read<ProductProvider>().saveProduct(
                            name,
                            price,
                            descCtrl.text.trim(),
                            isActive,
                            selectedImage,
                            id: existingProduct?['id'],
                            context: context,
                          );
                        }
                      },
                      child: Text(isEditing ? '保存修改' : '确认上架'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: const [
        SizedBox(height: 100),
        Icon(Icons.fastfood_outlined, size: 80, color: Colors.grey),
        SizedBox(height: 16),
        Center(
          child: Text(
            '暂无商品，快去添加吧',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProductProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          '商品管理',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              onChanged: provider.runFilter,
              decoration: InputDecoration(
                hintText: '搜索商品...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
        backgroundColor: Colors.orangeAccent.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新增商品'),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, pro, child) {
          if (pro.isLoading && pro.filteredProducts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
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
                    pro.errorMessage!,
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

          return RefreshIndicator(
            onRefresh: () => pro.fetchProducts(showLoading: true),
            child: pro.filteredProducts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 12,
                      bottom: 80,
                    ),
                    itemCount: pro.filteredProducts.length,
                    itemBuilder: (context, index) {
                      return ProductCardMeituan(
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

// 💥 美团风商品卡片
class ProductCardMeituan extends StatelessWidget {
  final Map<String, dynamic> product;
  final Function(Map<String, dynamic>) onEdit;

  const ProductCardMeituan({
    super.key,
    required this.product,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // 解析状态，处理旧数据可能没有 is_active 字段的情况
    final bool isActive = product['is_active'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：商品图片
          Opacity(
            opacity: isActive ? 1.0 : 0.5, // 下架商品变灰
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 85,
                height: 85,
                color: Colors.grey[200],
                child: product['image_url'] != null
                    ? Image.network(
                        product['image_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      )
                    : const Icon(Icons.fastfood, color: Colors.grey, size: 40),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 右侧：商品信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题与删除按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product['name'] ?? '未知',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isActive ? Colors.black87 : Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isActive) // 只在下架状态显示删除按钮，防止误删热销商品
                      InkWell(
                        onTap: () =>
                            context.read<ProductProvider>().deleteProduct(
                              product['id'],
                              product['name'],
                              context,
                            ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // 描述信息
                Text(
                  product['description']?.isNotEmpty == true
                      ? product['description']
                      : '暂无商品描述',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // 底部：价格与上下架操作
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '￥${product['price']}',
                      style: TextStyle(
                        color: isActive ? Colors.redAccent : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Row(
                      children: [
                        // 编辑按钮
                        OutlinedButton(
                          onPressed: () => onEdit(product),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            minimumSize: const Size(0, 28),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '编辑',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 上下架快捷开关
                        OutlinedButton(
                          onPressed: () => context
                              .read<ProductProvider>()
                              .toggleProductStatus(
                                product['id'],
                                isActive,
                                context,
                              ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isActive
                                ? Colors.white
                                : Colors.grey[100],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            minimumSize: const Size(0, 28),
                            side: BorderSide(
                              color: isActive
                                  ? Colors.orangeAccent
                                  : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            isActive ? '下架' : '上架',
                            style: TextStyle(
                              fontSize: 12,
                              color: isActive
                                  ? Colors.orangeAccent.shade700
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
