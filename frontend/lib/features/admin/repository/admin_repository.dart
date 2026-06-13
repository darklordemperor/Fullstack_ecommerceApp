import '../../../core/dio/dio_client.dart';
import '../../auth/model/user_model.dart';
import '../../product/model/product_model.dart';

class AdminRepository {
  Future<Map<String, dynamic>> stats() async {
    final response = await DioClient.dio.get('/admin/stats');
    return Map<String, dynamic>.from(DioClient.payload(response));
  }

  Future<List<UserModel>> users() async {
    final response = await DioClient.dio.get('/admin/users');
    final data = DioClient.payload(response) as List? ?? const [];
    return data
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ProductModel>> products() async {
    final response = await DioClient.dio.get('/admin/products');
    final data = DioClient.payload(response) as List? ?? const [];
    return data
        .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> setBanned(String userId, bool banned) async {
    await DioClient.dio
        .put('/admin/users/$userId/ban', data: {'banned': banned});
  }

  Future<void> deleteProduct(String productId) async {
    await DioClient.dio.delete('/admin/products/$productId');
  }
}
