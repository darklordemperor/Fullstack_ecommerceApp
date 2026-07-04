import 'package:dio/dio.dart';

import '../../../core/network/dio_provider.dart';
import '../model/cart_model.dart';

class CartRepository {
  CartRepository(this._dio);

  final Dio _dio;

  Future<CartModel> get() async {
    final response = await _dio.get<dynamic>('/cart');
    return CartModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  Future<CartModel> add(String productId, int quantity) async {
    final response = await _dio.post<dynamic>('/cart/add',
        data: {'product_id': productId, 'quantity': quantity});
    return CartModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  Future<CartModel> update(String productId, int quantity) async {
    final response = await _dio.put<dynamic>('/cart/update',
        data: {'product_id': productId, 'quantity': quantity});
    return CartModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  Future<CartModel> remove(String productId) async {
    final response = await _dio.delete<dynamic>('/cart/remove/$productId');
    return CartModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  Future<CartModel> clear() async {
    final response = await _dio.delete<dynamic>('/cart/clear');
    return CartModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  Future<CartModel> checkout([List<String> productIds = const []]) async {
    final response = await _dio.post<dynamic>('/cart/checkout',
        data: productIds.isEmpty ? null : {'product_ids': productIds});
    final data = apiPayload<Map<String, dynamic>>(response);
    return CartModel.fromJson(data['cart'] as Map<String, dynamic>);
  }

  Future<void> buyNow(String productId, int quantity) async {
    await _dio.post<dynamic>('/cart/buy-now',
        data: {'product_id': productId, 'quantity': quantity});
  }
}
