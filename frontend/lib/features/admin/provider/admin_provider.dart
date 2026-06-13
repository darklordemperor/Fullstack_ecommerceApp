import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/model/user_model.dart';
import '../../product/model/product_model.dart';
import '../repository/admin_repository.dart';

final adminRepositoryProvider = Provider((ref) => AdminRepository());

final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(adminRepositoryProvider).stats();
});

final adminUsersProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.watch(adminRepositoryProvider).users();
});

final adminProductsProvider = FutureProvider<List<ProductModel>>((ref) {
  return ref.watch(adminRepositoryProvider).products();
});

void refreshAdmin(WidgetRef ref) {
  ref.invalidate(adminStatsProvider);
  ref.invalidate(adminUsersProvider);
  ref.invalidate(adminProductsProvider);
}
