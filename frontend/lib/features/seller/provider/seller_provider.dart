import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dio/dio_client.dart';
import '../../product/model/product_model.dart';
import '../../product/provider/product_provider.dart';

final sellerStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await DioClient.dio.get('/seller/stats');
  return Map<String, dynamic>.from(DioClient.payload(response));
});

final sellerProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final response = await DioClient.dio.get('/seller/products');
  return (DioClient.payload(response) as List).map((e) => ProductModel.fromJson(e)).toList();
});

final sellerOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await DioClient.dio.get('/seller/orders');
  return (DioClient.payload(response) as List).map((e) => Map<String, dynamic>.from(e)).toList();
});

Future<void> refreshSeller(WidgetRef ref) async {
  ref.invalidate(sellerStatsProvider);
  ref.invalidate(sellerProductsProvider);
  ref.invalidate(sellerOrdersProvider);
  ref.invalidate(productsProvider);
}
