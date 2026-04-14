import 'package:flutter/material.dart';
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

    //优雅的 Map 更新语法，结合 copyWith
    _items.update(
      product.id,
      (existingItem) =>
          existingItem.copyWith(quantity: existingItem.quantity + 1),
      ifAbsent: () => CartItem(product: product),
    );

    notifyListeners();
    return null; // null 代表添加成功，无错误
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

  // 直接设置商品的指定数量 (用于弹窗手动输入)
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

  /// 🌟 数据同步自检：清除购物车中已经失效的商品（配合定时刷新使用）
  void validateCartAgainstLatestProducts(List<Product> latestProducts) {
    bool hasChanged = false;
    final keysToRemove = <int>[];

    for (var entry in _items.entries) {
      final cartItem = entry.value;
      // 在最新列表里找这个商品
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

    for (var key in keysToRemove) {
      _items.remove(key);
    }

    if (hasChanged) notifyListeners();
  }

  // ==== 结算引擎 ====

  /// 🌟 极简返回：封装结算结果给 UI 层处理。返回：(是否成功, 提示/错误信息)
  Future<(bool, String)> checkout({String paymentMethod = 'cash'}) async {
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

      final result = await _api.createOrder(
        payloadItems,
        paymentMethod: paymentMethod,
        orderStatus: 'completed',
      );
      clearCart();

      final finalTotal = result['total_amount'] ?? totalAmount;
      return (true, '交易成功！收款: ¥$finalTotal');
    } catch (e) {
      return (false, e.toString());
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
