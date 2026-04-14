import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // 注意：需在 pubspec.yaml 中添加 uuid 依赖
import 'cart_models.dart';
import 'product_models.dart';
import '../../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final Map<int, CartItem> _items = {};
  bool _isSubmitting = false;

  Map<int, CartItem> get items => _items;
  bool get isSubmitting => _isSubmitting;
  bool get isEmpty => _items.isEmpty;

  int get totalItemCount {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalAmount {
    return _items.values.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  // ==== 购物车操作逻辑 ====

  /// 极简更新：返回 String? 作为错误信息，解耦 BuildContext
  String? addItem(Product product) {
    if (!product.isActive) return '该商品已下架，无法购买';

    final currentQty = _items.containsKey(product.id)
        ? _items[product.id]!.quantity
        : 0;
    if (currentQty >= product.stock) {
      return '【${product.name}】库存不足 (剩余: ${product.stock})';
    }

    // 优雅的 Map 更新语法，结合 copyWith
    _items.update(
      product.id,
      (existingItem) =>
          existingItem.copyWith(quantity: existingItem.quantity + 1),
      ifAbsent: () => CartItem(product: product),
    );

    notifyListeners();
    return null;
  }

  void removeItemCount(int productId) {
    if (!_items.containsKey(productId)) return;

    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existing) => existing.copyWith(quantity: existing.quantity - 1),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  // 直接设置商品的指定数量 (用于弹窗手动输入或扫码枪连续扫入)
  String? setItemQuantity(Product product, int newQuantity) {
    if (!product.isActive) return '该商品已下架，无法购买';

    // 如果输入 <= 0，直接从购物车移除
    if (newQuantity <= 0) {
      removeProductCompletely(product.id);
      return null;
    }

    // 校验是否超出最大可用库存
    if (newQuantity > product.stock) {
      return '【${product.name}】库存不足 (最大可用: ${product.stock})';
    }

    _items.update(
      product.id,
      (existingItem) => existingItem.copyWith(quantity: newQuantity),
      ifAbsent: () => CartItem(product: product, quantity: newQuantity),
    );

    notifyListeners();
    return null;
  }

  void removeProductCompletely(int productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  /// 🌟 架构修复：安全的数据同步自检。
  /// 使用 .entries.toList() 创建副本进行遍历，彻底消除 ConcurrentModificationError 隐患。
  void validateCartAgainstLatestProducts(List<Product> latestProducts) {
    bool hasChanged = false;
    final keysToRemove = <int>[];

    // 必须生成一个静态列表副本用于遍历，因为下方逻辑会修改 _items 本身
    final currentEntries = _items.entries.toList();

    for (var entry in currentEntries) {
      final cartItem = entry.value;
      // 在最新列表里找这个商品 (强类型 Product 匹配)
      final latestProduct = latestProducts
          .where((p) => p.id == cartItem.product.id)
          .firstOrNull;

      if (latestProduct == null || !latestProduct.isActive) {
        keysToRemove.add(entry.key); // 商品被删除或下架
        hasChanged = true;
      } else if (cartItem.quantity > latestProduct.stock) {
        // 如果购物车里的数量超过了最新的库存，自动降为最新库存，为 0 则删除
        if (latestProduct.stock <= 0) {
          keysToRemove.add(entry.key);
        } else {
          _items[entry.key] = cartItem.copyWith(quantity: latestProduct.stock);
        }
        hasChanged = true;
      }
    }

    // 统一执行删除操作
    for (var key in keysToRemove) {
      _items.remove(key);
    }

    if (hasChanged) notifyListeners();
  }

  // ==== 结算引擎 ====

  /// 🌟 架构升级：带有状态机熔断和全局幂等键的收银台级结算
  Future<(bool, String)> checkout({String paymentMethod = 'cash'}) async {
    // 防护 1：状态机熔断，防止收银员因为网络卡顿疯狂点击导致的并发请求
    if (_isSubmitting) return (false, '正在处理中，请勿重复点击');
    if (_items.isEmpty) return (false, '购物车为空');

    _isSubmitting = true;
    notifyListeners();

    try {
      final payloadItems = _items.values
          .map(
            (item) => {
              'products_id': item.product.id,
              'quantity': item.quantity,
            },
          )
          .toList();

      // 防护 2：生成全局唯一幂等键 (Idempotency Key)，确保后端在任何异常重试下绝对不会产生重复订单
      final idempotencyKey = const Uuid().v4();

      final result = await _api.createOrder(
        payloadItems,
        paymentMethod: paymentMethod,
        orderStatus: 'completed', // 商家收银台直接走 completed 状态
        idempotencyKey: idempotencyKey, // 传递给 ApiService 层
      );

      clearCart();

      // 兼容后端返回结构，防御空指针
      final finalTotal =
          result['data']?['total_amount'] ??
          result['total_amount'] ??
          totalAmount;
      return (true, '交易成功！收款: ¥$finalTotal');
    } catch (e) {
      return (false, e.toString());
    } finally {
      // 无论成功失败，必须释放锁
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
