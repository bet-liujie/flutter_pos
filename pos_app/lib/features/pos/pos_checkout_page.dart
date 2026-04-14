import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'product_provider.dart';
import 'cart_provider.dart';
import 'product_models.dart';
import '../activation/auth_provider.dart';

class PosCheckoutPage extends StatefulWidget {
  const PosCheckoutPage({super.key});

  @override
  State<PosCheckoutPage> createState() => _PosCheckoutPageState();
}

class _PosCheckoutPageState extends State<PosCheckoutPage> {
  @override
  void initState() {
    super.initState();
    // 进入收银台时，主动拉取一次最新商品数据，并同步校验购物车
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final productProvider = context.read<ProductProvider>();
      await productProvider.fetchProducts();
      if (mounted) {
        context.read<CartProvider>().validateCartAgainstLatestProducts(
          productProvider.filteredProducts,
        );
      }
    });
  }

  void _handleAddToCart(Product product) {
    final cartProvider = context.read<CartProvider>();
    final errorMsg = cartProvider.addItem(product);

    if (errorMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: GestureDetector(
          onDoubleTap: () {
            context.read<AuthProvider>().deactivateDevice();
            context.go('/activation');
          },
          child: const Text(
            '收银台',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          // 跳转到商品管理后台的入口
          TextButton.icon(
            icon: const Icon(Icons.inventory),
            label: const Text('商品管理', style: TextStyle(fontSize: 16)),
            onPressed: () => context.push('/products'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            return _buildTabletLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: _buildProductSection(isMobile: false)),
        const VerticalDivider(width: 1, color: Colors.grey),
        Expanded(flex: 4, child: _buildCartPanel()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(child: _buildProductSection(isMobile: true)),
        _buildMobileCartBar(),
      ],
    );
  }

  // ================= 左侧：商品网格区 =================
  Widget _buildProductSection({required bool isMobile}) {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        // 只展示已上架的商品
        final activeProducts = provider.filteredProducts
            .where((p) => p.isActive)
            .toList();

        if (provider.isLoading && activeProducts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (activeProducts.isEmpty) {
          return const Center(
            child: Text(
              '暂无上架商品',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        return Column(
          children: [
            // 搜索栏
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: TextField(
                onChanged: (val) => provider.runFilter(val),
                decoration: InputDecoration(
                  hintText: '搜索商品...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // 网格
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 2 : 4,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: activeProducts.length,
                itemBuilder: (context, index) {
                  final product = activeProducts[index];
                  final isOutOfStock = product.stock <= 0;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: isOutOfStock
                          ? null
                          : () => _handleAddToCart(product),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 3,
                                child: product.imageUrl != null
                                    ? Image.network(
                                        product.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _fallbackIcon(),
                                      )
                                    : _fallbackIcon(),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        '¥ ${product.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.orangeAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // 库存角标
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isOutOfStock
                                    ? Colors.red
                                    : (product.stock <= 10
                                          ? Colors.orange
                                          : Colors.green),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isOutOfStock ? '售罄' : '余 ${product.stock}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // 售罄遮罩
                          if (isOutOfStock)
                            Container(color: Colors.white.withOpacity(0.6)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _fallbackIcon() => Container(
    color: Colors.grey[200],
    child: const Icon(Icons.fastfood, color: Colors.grey, size: 40),
  );

  // ================= 右侧：购物车面板 =================
  Widget _buildCartPanel() {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return Container(
          color: Colors.white,
          child: Column(
            children: [
              // 头部
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '当前订单 (${cart.totalItemCount}件)',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!cart.isEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.red),
                        onPressed: cart.isSubmitting
                            ? null
                            : () => _confirmClearCart(cart),
                        tooltip: '清空购物车',
                      ),
                  ],
                ),
              ),
              // 列表
              Expanded(
                child: cart.isEmpty
                    ? const Center(
                        child: Text(
                          '购物车为空\n请点击左侧商品添加',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          // ✨ 性能优化：在 builder 外部先将 Map 转换为 List，将时间复杂度从 O(n²) 降为 O(1)
                          final cartItemsList = cart.items.values.toList();

                          return ListView.separated(
                            itemCount: cartItemsList.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = cartItemsList[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  item.product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '¥ ${item.product.price.toStringAsFixed(2)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () =>
                                          cart.removeItemCount(item.product.id),
                                    ),
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        '${item.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () =>
                                          _handleAddToCart(item.product),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              // 结算底部
              _buildCheckoutFooter(cart),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckoutFooter(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '总计',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                '¥ ${cart.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              onPressed: cart.isEmpty || cart.isSubmitting
                  ? null
                  : () => _executeCheckout(cart),
              child: cart.isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      '确认结账',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 手机端底部悬浮条（用于弹出弹窗，这里暂时用简单的按钮替代，后续可完善 BottomSheet）
  Widget _buildMobileCartBar() {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        if (cart.isEmpty) return const SizedBox.shrink();
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '共 ${cart.totalItemCount} 件 | ¥ ${cart.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _showMobileCartSheet(context),
                child: const Text('查看购物车'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMobileCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          FractionallySizedBox(heightFactor: 0.8, child: _buildCartPanel()),
    );
  }

  void _confirmClearCart(CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空购物车'),
        content: const Text('确定要移除所有已选商品吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              cart.clearCart();
              Navigator.of(ctx).pop();
            },
            child: const Text('清空', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeCheckout(CartProvider cart) async {
    final messenger = ScaffoldMessenger.of(context);
    // ✨ 提前捕获 ProductProvider
    final productProvider = context.read<ProductProvider>();

    final (success, msg) = await cart.checkout();

    if (success) {
      //  核心 Bug 修复：结算成功后，主动拉取最新库存，刷新左侧商品网格
      if (mounted) {
        await productProvider.fetchProducts();
      }
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
