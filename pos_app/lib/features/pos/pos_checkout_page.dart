import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final TextEditingController _searchCtrl;

  // ✨ 需求 2：新增支付方式本地状态
  String _selectedPaymentMethod = 'wechat_pay';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
          // 仅在Android平台显示MDM管理按钮
          if (!kIsWeb && Platform.isAndroid)
            TextButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('设备管理', style: TextStyle(fontSize: 16)),
              onPressed: () => context.push('/mdm'),
            ),
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
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: _buildProductSection(isMobile: false)),
                const VerticalDivider(width: 1, color: Colors.grey),
                Expanded(flex: 4, child: _buildCartPanel()),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(child: _buildProductSection(isMobile: true)),
                _buildMobileCartBar(),
              ],
            );
          }
        },
      ),
    );
  }

  // ================= 左侧：商品网格区 =================
  Widget _buildProductSection({required bool isMobile}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (val) => context.read<ProductProvider>().runFilter(val),
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
        Expanded(
          child: Consumer<ProductProvider>(
            builder: (context, productProvider, child) {
              final activeProducts = productProvider.filteredProducts
                  .where((p) => p.isActive)
                  .toList();

              if (productProvider.isLoading && activeProducts.isEmpty) {
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

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 2 : 4,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: activeProducts.length,
                itemBuilder: (context, index) {
                  return ProductCardWidget(product: activeProducts[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ================= 右侧：购物车面板 =================
  Widget _buildCartPanel() {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return Container(
          color: Colors.white,
          child: Column(
            children: [
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
                          final cartItemsList = cart.items.values.toList();
                          return ListView.separated(
                            itemCount: cartItemsList.length,
                            separatorBuilder: (_, _) =>
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
                                    // ✨ 需求 1：替换为支持长按连发的减号按钮
                                    ContinuousPressIcon(
                                      icon: Icons.remove_circle_outline,
                                      color: Colors.blue,
                                      onTrigger: () =>
                                          cart.removeItemCount(item.product.id),
                                    ),

                                    InkWell(
                                      onTap: () => _showEditQuantityDialog(
                                        context,
                                        item.product,
                                        item.quantity,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        width: 40,
                                        height: 30,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.blue.shade200,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          color: Colors.blue.shade50,
                                        ),
                                        child: Text(
                                          '${item.quantity}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // ✨ 需求 1：替换为支持长按连发的加号按钮
                                    ContinuousPressIcon(
                                      icon: Icons.add_circle_outline,
                                      color: Colors.blue,
                                      onTrigger: () {
                                        final errorMsg = cart.addItem(
                                          item.product,
                                        );
                                        if (errorMsg != null) {
                                          // ✨ 防御性编程：发生错误前先清空堆积的 SnackBar，防止提示霸屏
                                          ScaffoldMessenger.of(
                                            context,
                                          ).clearSnackBars();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(errorMsg),
                                              backgroundColor: Colors.orange,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              _buildCheckoutFooter(cart),
            ],
          ),
        );
      },
    );
  }

  // ✨ 需求 2：重构的结算底部，带支付方式选择
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
          const SizedBox(height: 16),

          // 支付方式选择区
          Wrap(
            spacing: 12.0,
            children: [
              _buildPaymentChip('wechat_pay', '微信支付', Icons.wechat),
              _buildPaymentChip('alipay', '支付宝', Icons.qr_code_scanner),
              _buildPaymentChip('cash', '现金', Icons.money),
            ],
          ),

          const SizedBox(height: 16),
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

  // 快捷生成支付标签组件
  Widget _buildPaymentChip(String value, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.blue : Colors.grey,
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() => _selectedPaymentMethod = value);
        }
      },
      selectedColor: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300),
    );
  }

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
    final productProvider = context.read<ProductProvider>();

    // ✨ 传入用户选择的支付方式
    final (success, msg) = await cart.checkout(
      paymentMethod: _selectedPaymentMethod,
    );

    if (success) {
      if (mounted) {
        await productProvider.fetchProducts();
      }
    }

    messenger.clearSnackBars(); // 防止覆盖
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEditQuantityDialog(
    BuildContext context,
    Product product,
    int currentQty,
  ) {
    showDialog(
      context: context,
      builder: (ctx) =>
          EditQuantityDialog(product: product, initialQty: currentQty),
    );
  }
}

// ================= 核心组件 1：极致局部刷新的商品卡片 =================
class ProductCardWidget extends StatelessWidget {
  final Product product;

  const ProductCardWidget({super.key, required this.product});

  void _showProductDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.imageUrl != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.imageUrl!,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              '💰 单价: ¥${product.price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '📦 库房总量: ${product.stock} 件',
              style: const TextStyle(fontSize: 16),
            ),
            const Divider(),
            const Text(
              '📝 描述:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              product.description.isEmpty ? '无商品描述' : product.description,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartQty = context.select<CartProvider, int>(
      (cart) => cart.items[product.id]?.quantity ?? 0,
    );
    final availableStock = product.stock - cartQty;
    final isOutOfStock = availableStock <= 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (isOutOfStock) {
            // ✨ 解决你说的“无反应”：给出明确的视觉反馈
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('商品 [${product.name}] 已售罄，请及时补货'),
                backgroundColor: Colors.orange.shade900,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(milliseconds: 1500),
              ),
            );
            return; // 拦截，不加入购物车
          }
          final errorMsg = context.read<CartProvider>().addItem(product);
          if (errorMsg != null) {
            ScaffoldMessenger.of(context).clearSnackBars(); // ✨ 防刷屏
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMsg),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },

        onLongPress: () => _showProductDetailsDialog(context),
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
                          errorBuilder: (_, _, _) => _fallbackIcon(),
                        )
                      : _fallbackIcon(),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? Colors.red
                      : (availableStock <= 10 ? Colors.orange : Colors.green),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isOutOfStock ? '售罄' : '余 $availableStock',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (isOutOfStock) Container(color: Colors.white.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  Widget _fallbackIcon() => Container(
    color: Colors.grey[200],
    child: const Icon(Icons.fastfood, color: Colors.grey, size: 40),
  );
}

// ================= 核心组件 2：安全的修改数量弹窗 =================
class EditQuantityDialog extends StatefulWidget {
  final Product product;
  final int initialQty;

  const EditQuantityDialog({
    super.key,
    required this.product,
    required this.initialQty,
  });

  @override
  State<EditQuantityDialog> createState() => _EditQuantityDialogState();
}

class _EditQuantityDialogState extends State<EditQuantityDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQty.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('修改【${widget.product.name}】数量'),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        autofocus: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: '购买数量',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            final newQty = int.tryParse(_ctrl.text) ?? 0;
            final cart = context.read<CartProvider>();
            final errorMsg = cart.setItemQuantity(widget.product, newQty);

            Navigator.of(context).pop();

            if (errorMsg != null && context.mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMsg),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

// ================= 核心组件 3：长按连续触发按钮 (需求 1) =================
class ContinuousPressIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTrigger;

  const ContinuousPressIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.onTrigger,
  });

  @override
  State<ContinuousPressIcon> createState() => _ContinuousPressIconState();
}

class _ContinuousPressIconState extends State<ContinuousPressIcon> {
  Timer? _timer;

  void _startTimer() {
    // 首次按下立即触发一次
    widget.onTrigger();
    // 延迟 300 毫秒后，开始每 100 毫秒连续触发（模拟操作系统的键位连发逻辑）
    _timer = Timer(const Duration(milliseconds: 300), () {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        widget.onTrigger();
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startTimer(),
      onTapUp: (_) => _stopTimer(),
      onTapCancel: () => _stopTimer(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Icon(widget.icon, color: widget.color),
      ),
    );
  }
}
