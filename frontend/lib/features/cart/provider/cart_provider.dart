import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/cart_model.dart';
import '../repository/cart_repository.dart';

final cartRepositoryProvider = Provider((ref) => CartRepository());
final cartProvider = FutureProvider<CartModel>((ref) => ref.watch(cartRepositoryProvider).get());
