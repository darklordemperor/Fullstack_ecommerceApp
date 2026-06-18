class CartItemModel {
  const CartItemModel({
    required this.productId,
    required this.name,
    required this.price,
    required this.image,
    required this.quantity,
  });

  final String productId;
  final String name;
  final double price;
  final String image;
  final int quantity;
  double get subtotal => price * quantity;

  CartItemModel copyWith({
    String? productId,
    String? name,
    double? price,
    String? image,
    int? quantity,
  }) =>
      CartItemModel(
        productId: productId ?? this.productId,
        name: name ?? this.name,
        price: price ?? this.price,
        image: image ?? this.image,
        quantity: quantity ?? this.quantity,
      );

  factory CartItemModel.fromJson(Map<String, dynamic> json) => CartItemModel(
        productId: json['product_id'] ?? '',
        name: json['name'] ?? '',
        price: (json['price'] ?? 0).toDouble(),
        image: json['image'] ?? '',
        quantity: json['quantity'] ?? 0,
      );
}

class CartModel {
  const CartModel({required this.id, required this.items});
  final String id;
  final List<CartItemModel> items;
  int get count => items.map((item) => item.productId).toSet().length;
  double get total => items.fold(0, (sum, item) => sum + item.subtotal);

  factory CartModel.empty() => const CartModel(id: '', items: []);
  factory CartModel.fromJson(Map<String, dynamic> json) => CartModel(
        id: json['id'] ?? '',
        items: _mergeDuplicateItems((json['items'] as List? ?? const [])
            .map((e) => CartItemModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()),
      );
}

List<CartItemModel> _mergeDuplicateItems(List<CartItemModel> items) {
  final merged = <String, CartItemModel>{};
  for (final item in items) {
    final existing = merged[item.productId];
    if (existing == null) {
      merged[item.productId] = item;
      continue;
    }
    merged[item.productId] =
        existing.copyWith(quantity: existing.quantity + item.quantity);
  }
  return merged.values.toList();
}
