import 'package:dio/dio.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../product/model/product_model.dart';
import '../../domain/repositories/seller_repository.dart';

/// Dio-backed implementation of [SellerRepository].
class SellerRepositoryImpl implements SellerRepository {
  SellerRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> stats() async {
    final response = await _dio.get<dynamic>('/seller/stats');
    return apiPayload<Map<String, dynamic>>(response);
  }

  @override
  Future<List<ProductModel>> products() async {
    final response = await _dio.get<dynamic>('/seller/products');
    final data = apiPayload<List<dynamic>?>(response) ?? const <dynamic>[];
    return data
        .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> orders() async {
    final response = await _dio.get<dynamic>('/seller/orders');
    final data = apiPayload<List<dynamic>?>(response) ?? const <dynamic>[];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
