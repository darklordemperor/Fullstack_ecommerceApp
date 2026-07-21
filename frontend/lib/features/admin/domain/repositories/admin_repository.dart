import '../../../auth/model/user_model.dart';
import '../../../product/model/product_model.dart';

/// Domain contract for platform administration reads and moderation actions.
abstract interface class AdminRepository {
  Future<Map<String, dynamic>> stats();
  Future<List<UserModel>> users();
  Future<List<ProductModel>> products();
  Future<void> setBanned(String userId, bool banned);
  Future<void> deleteProduct(String productId);
}
