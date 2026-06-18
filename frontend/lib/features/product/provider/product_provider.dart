import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/product_model.dart';
import '../repository/product_repository.dart';

final productRepositoryProvider = Provider((ref) => ProductRepository());
final categoryProvider = StateProvider<String>((ref) => 'All');
final searchProvider = StateProvider<String>((ref) => '');

final productsProvider = FutureProvider<List<ProductModel>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.list(
      category: ref.watch(categoryProvider), search: ref.watch(searchProvider));
});

final productDetailProvider =
    FutureProvider.family<ProductModel, String>((ref, id) {
  return ref.watch(productRepositoryProvider).detail(id);
});

void refreshProductCaches(dynamic ref, {String? productId}) {
  ref.invalidate(productsProvider);
  if (productId != null && productId.isNotEmpty) {
    ref.invalidate(productDetailProvider(productId));
  }
}
