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

  String get mainImage => images.isEmpty ? 'https://picsum.photos/seed/$id/600' : images.first;

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] ?? '',
        sellerId: json['seller_id'] ?? '',
        sellerName: json['seller_name'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        price: (json['price'] ?? 0).toDouble(),
        stock: json['stock'] ?? 0,
        category: json['category'] ?? '',
        images: List<String>.from(json['images'] ?? const []),
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
