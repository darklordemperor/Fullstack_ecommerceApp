import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../model/cart_model.dart';
import '../repository/cart_repository.dart';

final cartRepositoryProvider =
    Provider<CartRepository>((ref) => CartRepository(ref.watch(dioProvider)));

/// Owns all cart mutations so widgets never talk to the repository directly.
///
/// Quantity changes and removals are applied optimistically: the local state
/// updates immediately, then is replaced by the server's authoritative cart.
/// On failure the previous state is restored and the error is rethrown so the
/// caller can surface it.
class CartNotifier extends AsyncNotifier<CartModel> {
  CartRepository get _repository => ref.read(cartRepositoryProvider);

  @override
  Future<CartModel> build() => ref.watch(cartRepositoryProvider).get();

  Future<void> add(String productId, int quantity) async {
    state = AsyncData(await _repository.add(productId, quantity));
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    await _applyOptimistically(
      (cart) => CartModel(
        id: cart.id,
        items: [
          for (final item in cart.items)
            if (item.productId == productId)
              item.copyWith(quantity: quantity)
            else
              item,
        ],
      ),
      () => _repository.update(productId, quantity),
    );
  }

  Future<void> remove(String productId) async {
    await _applyOptimistically(
      (cart) => CartModel(
        id: cart.id,
        items:
            cart.items.where((item) => item.productId != productId).toList(),
      ),
      () => _repository.remove(productId),
    );
  }

  Future<void> checkout(List<String> productIds) async {
    state = AsyncData(await _repository.checkout(productIds));
  }

  Future<void> buyNow(String productId, int quantity) =>
      _repository.buyNow(productId, quantity);

  Future<void> _applyOptimistically(
    CartModel Function(CartModel cart) localChange,
    Future<CartModel> Function() request,
  ) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final previous = state;
    state = AsyncData(localChange(current));
    try {
      state = AsyncData(await request());
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final cartProvider =
    AsyncNotifierProvider<CartNotifier, CartModel>(CartNotifier.new);
