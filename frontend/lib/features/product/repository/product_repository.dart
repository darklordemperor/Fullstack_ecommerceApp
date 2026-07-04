import 'package:dio/dio.dart';

import '../../../core/network/dio_provider.dart';
import '../model/product_model.dart';

class ProductRepository {
  ProductRepository(this._dio);

  final Dio _dio;

  Future<List<ProductModel>> list(
      {String? category, String? search, int page = 1, int limit = 20}) async {
    final response = await _dio.get<dynamic>('/products', queryParameters: {
      if (category != null && category != 'All') 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': limit,
    });
    final data = apiPayload<List<dynamic>?>(response) ?? const <dynamic>[];
    return data
        .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ProductModel> detail(String id) async {
    final response = await _dio.get<dynamic>('/products/$id');
    return ProductModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  Future<ProductModel> create(Map<String, dynamic> body) async {
    final response = await _dio.post<dynamic>('/products', data: body);
    return ProductModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  Future<ProductModel> update(String id, Map<String, dynamic> body) async {
    final response = await _dio.put<dynamic>('/products/$id', data: body);
    return ProductModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  Future<void> delete(String id) async {
    await _dio.delete<dynamic>('/products/$id');
  }
}
