import '../../model/product_model.dart';

/// Domain contract for product data access (storefront reads + seller CRUD).
abstract interface class ProductRepository {
  Future<List<ProductModel>> list({
    String? category,
    String? search,
    int? page,
    int? limit,
  });
  Future<ProductModel> detail(String id);
  Future<ProductModel> create(Map<String, dynamic> body);
  Future<ProductModel> update(String id, Map<String, dynamic> body);
  Future<void> delete(String id);
}
