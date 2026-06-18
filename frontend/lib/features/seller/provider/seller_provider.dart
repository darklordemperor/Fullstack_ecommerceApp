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
  final data = DioClient.payload(response) as List? ?? const [];
  return data
      .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

final sellerOrdersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await DioClient.dio.get('/seller/orders');
  final data = DioClient.payload(response) as List? ?? const [];
  return data.map((e) => Map<String, dynamic>.from(e)).toList();
});

Future<void> refreshSeller(WidgetRef ref, {String? productId}) async {
  ref.invalidate(sellerStatsProvider);
  ref.invalidate(sellerProductsProvider);
  ref.invalidate(sellerOrdersProvider);
  refreshProductCaches(ref, productId: productId);
}
