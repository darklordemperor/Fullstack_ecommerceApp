import '../../../product/model/product_model.dart';

/// Domain contract for seller dashboard data (own products, orders, stats).
abstract interface class SellerRepository {
  Future<Map<String, dynamic>> stats();
  Future<List<ProductModel>> products();
  Future<List<Map<String, dynamic>>> orders();
}
