import 'package:dio/dio.dart';

import '../../../core/network/dio_provider.dart';
import '../../auth/model/user_model.dart';
import '../../product/model/product_model.dart';

class AdminRepository {
  AdminRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> stats() async {
    final response = await _dio.get<dynamic>('/admin/stats');
    return apiPayload<Map<String, dynamic>>(response);
  }

  Future<List<UserModel>> users() async {
    final response = await _dio.get<dynamic>('/admin/users');
    final data = apiPayload<List<dynamic>?>(response) ?? const <dynamic>[];
    return data
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ProductModel>> products() async {
    final response = await _dio.get<dynamic>('/admin/products');
    final data = apiPayload<List<dynamic>?>(response) ?? const <dynamic>[];
    return data
        .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> setBanned(String userId, bool banned) async {
    await _dio.put<dynamic>('/admin/users/$userId/ban',
        data: {'banned': banned});
  }

  Future<void> deleteProduct(String productId) async {
    await _dio.delete<dynamic>('/admin/products/$productId');
  }
}
