class CartItemModel {
  const CartItemModel({
    required this.productId,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    required this.price,
    required this.image,
    required this.quantity,
  });

  final String productId;
  final String sellerId;
  final String sellerName;
  final String name;
  final double price;
  final String image;
  final int quantity;
  double get subtotal => price * quantity;

  CartItemModel copyWith({
    String? productId,
    String? sellerId,
    String? sellerName,
    String? name,
    double? price,
    String? image,
    int? quantity,
  }) =>
      CartItemModel(
        productId: productId ?? this.productId,
        sellerId: sellerId ?? this.sellerId,
        sellerName: sellerName ?? this.sellerName,
        name: name ?? this.name,
        price: price ?? this.price,
        image: image ?? this.image,
        quantity: quantity ?? this.quantity,
      );

  factory CartItemModel.fromJson(Map<String, dynamic> json) => CartItemModel(
        productId: json['product_id'] ?? '',
        sellerId: json['seller_id'] ?? '',
        sellerName: json['seller_name'] ?? 'Shop',
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
  List<CartItemModel> selectedItems(Set<String> selectedProductIds) => items
      .where((item) => selectedProductIds.contains(item.productId))
      .toList();
  int selectedCount(Set<String> selectedProductIds) =>
      selectedItems(selectedProductIds).length;
  double selectedTotal(Set<String> selectedProductIds) =>
      selectedItems(selectedProductIds)
          .fold(0, (sum, item) => sum + item.subtotal);
  List<CartShopGroup> get shopGroups {
    final groups = <String, CartShopGroup>{};
    for (final item in items) {
      final key = item.sellerId.isEmpty ? item.sellerName : item.sellerId;
      final existing = groups[key];
      if (existing == null) {
        groups[key] = CartShopGroup(
          sellerId: item.sellerId,
          sellerName: item.sellerName,
          items: [item],
        );
      } else {
        existing.items.add(item);
      }
    }
    return groups.values.toList();
  }

  factory CartModel.empty() => const CartModel(id: '', items: []);
  factory CartModel.fromJson(Map<String, dynamic> json) => CartModel(
        id: json['id'] ?? '',
        items: _mergeDuplicateItems((json['items'] as List? ?? const [])
            .map((e) => CartItemModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()),
      );
}

class CartShopGroup {
  CartShopGroup({
    required this.sellerId,
    required this.sellerName,
    required this.items,
  });

  final String sellerId;
  final String sellerName;
  final List<CartItemModel> items;

  Set<String> get productIds => items.map((item) => item.productId).toSet();
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
