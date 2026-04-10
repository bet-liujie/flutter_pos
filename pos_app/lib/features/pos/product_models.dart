class Product {
  final int id;
  final String name;
  final double price;
  final String description;
  final bool isActive;
  final int stock;
  final String? imageUrl; // 图片可能是空的，所以加 ?

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.isActive,
    required this.stock,
    this.imageUrl,
  });

  // 1. 从后端 JSON (Map) 转换为 Dart 对象 (工厂方法)
  factory Product.fromJson(Map<String, dynamic> json) {
    // 💥 新增一个超级安全的数字解析器
    double parsedPrice = 0.0;
    if (json['price'] != null) {
      if (json['price'] is String) {
        parsedPrice = double.tryParse(json['price'] as String) ?? 0.0;
      } else if (json['price'] is num) {
        parsedPrice = (json['price'] as num).toDouble();
      }
    }

    int parsedStock = 0;
    if (json['stock'] != null) {
      parsedStock = int.tryParse(json['stock'].toString()) ?? 0;
    }

    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? '未知商品',
      price: parsedPrice,
      stock: parsedStock, // 👈 使用解析好的安全数字
      description: json['description'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
    );
  }

  // 2. 将 Dart 对象转换回 JSON (如果以后需要把数据存入本地或发给后端)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'is_active': isActive,
      'stock': stock,
      'image_url': imageUrl,
    };
  }
}
