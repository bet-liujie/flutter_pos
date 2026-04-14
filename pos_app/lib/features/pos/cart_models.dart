import 'product_models.dart';

class CartItem {
  final Product product;
  final int quantity; // ✨ 改为 final，使其成为不可变对象

  CartItem({required this.product, this.quantity = 1});

  // ✨ 引入 copyWith 模式：每次数量变化都生成一个新对象，完美触发 UI 刷新
  CartItem copyWith({Product? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  double get subtotal => product.price * quantity;
}
