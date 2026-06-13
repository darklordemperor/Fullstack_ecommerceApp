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
  int get count => items.fold(0, (sum, item) => sum + item.quantity);
  double get total => items.fold(0, (sum, item) => sum + item.subtotal);

  factory CartModel.empty() => const CartModel(id: '', items: []);
  factory CartModel.fromJson(Map<String, dynamic> json) => CartModel(
        id: json['id'] ?? '',
        items: (json['items'] as List? ?? const [])
            .map((e) => CartItemModel.fromJson(e))
            .toList(),
      );
}
