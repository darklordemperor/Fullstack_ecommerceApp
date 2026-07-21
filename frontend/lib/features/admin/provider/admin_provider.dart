import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../auth/model/user_model.dart';
import '../../product/model/product_model.dart';
import '../data/repositories/admin_repository_impl.dart';
import '../domain/repositories/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
    (ref) => AdminRepositoryImpl(ref.watch(dioProvider)));

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
