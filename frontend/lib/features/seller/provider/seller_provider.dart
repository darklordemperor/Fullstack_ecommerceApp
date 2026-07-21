import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../product/model/product_model.dart';
import '../../product/provider/product_provider.dart';
import '../data/repositories/seller_repository_impl.dart';
import '../domain/repositories/seller_repository.dart';

final sellerRepositoryProvider = Provider<SellerRepository>(
    (ref) => SellerRepositoryImpl(ref.watch(dioProvider)));

final sellerStatsProvider = FutureProvider<Map<String, dynamic>>(
    (ref) => ref.watch(sellerRepositoryProvider).stats());

final sellerProductsProvider = FutureProvider<List<ProductModel>>(
    (ref) => ref.watch(sellerRepositoryProvider).products());

final sellerOrdersProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(sellerRepositoryProvider).orders());

void refreshSeller(WidgetRef ref, {String? productId}) {
  ref.invalidate(sellerStatsProvider);
  ref.invalidate(sellerProductsProvider);
  ref.invalidate(sellerOrdersProvider);
  refreshProductCaches(ref, productId: productId);
}
