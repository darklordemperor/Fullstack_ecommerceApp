import '../../model/cart_model.dart';

/// Domain contract for cart data access. The cart view model depends on this
/// abstraction, not on the Dio-backed implementation, so it can be faked in
/// tests and the data source swapped without touching the optimistic-update
/// logic that lives in the notifier.
abstract interface class CartRepository {
  Future<CartModel> get();
  Future<CartModel> add(String productId, int quantity);
  Future<CartModel> update(String productId, int quantity);
  Future<CartModel> remove(String productId);
  Future<CartModel> clear();
  Future<CartModel> checkout(List<String> productIds);
  Future<void> buyNow(String productId, int quantity);
}
