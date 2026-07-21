import 'package:dio/dio.dart';

import '../../../../core/network/dio_provider.dart';
import '../../domain/repositories/product_repository.dart';
import '../../model/product_model.dart';

/// Dio-backed implementation of [ProductRepository].
class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<ProductModel>> list({
    String? category,
    String? search,
    int? page,
    int? limit,
  }) async {
    final response = await _dio.get<dynamic>('/products', queryParameters: {
      if (category != null && category != 'All') 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page ?? 1,
      'limit': limit ?? 20,
    });
    final data = apiPayload<List<dynamic>?>(response) ?? const <dynamic>[];
    return data
        .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<ProductModel> detail(String id) async {
    final response = await _dio.get<dynamic>('/products/$id');
    return ProductModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  @override
  Future<ProductModel> create(Map<String, dynamic> body) async {
    final response = await _dio.post<dynamic>('/products', data: body);
    return ProductModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  @override
  Future<ProductModel> update(String id, Map<String, dynamic> body) async {
    final response = await _dio.put<dynamic>('/products/$id', data: body);
    return ProductModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  @override
  Future<void> delete(String id) async {
    await _dio.delete<dynamic>('/products/$id');
  }
}
