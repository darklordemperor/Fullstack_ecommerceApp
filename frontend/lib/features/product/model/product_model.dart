class ProductModel {
  const ProductModel({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
    required this.images,
  });

  final String id;
  final String sellerId;
  final String sellerName;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String category;
  final List<String> images;

  String get mainImage =>
      images.isEmpty ? 'https://picsum.photos/seed/$id/600' : images.first;

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String? ?? '',
        sellerId: json['seller_id'] as String? ?? '',
        sellerName: json['seller_name'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: (json['price'] as num? ?? 0).toDouble(),
        stock: (json['stock'] as num? ?? 0).toInt(),
        category: json['category'] as String? ?? '',
        images: (json['images'] as List<dynamic>? ?? const [])
            .map((image) => image.toString())
            .where((image) => image.isNotEmpty)
            .toList(),
      );

  Map<String, dynamic> toRequest() => {
        'name': name,
        'description': description,
        'price': price,
        'stock': stock,
        'category': category,
        'images': images,
      };
}
