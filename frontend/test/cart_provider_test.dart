import 'package:dio/dio.dart';
import 'package:ecommerce_frontend/features/cart/domain/repositories/cart_repository.dart';
import 'package:ecommerce_frontend/features/cart/model/cart_model.dart';
import 'package:ecommerce_frontend/features/cart/provider/cart_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer containerWith(CartRepository repository) {
    final container = ProviderContainer(
      overrides: [cartRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('quantity update applies optimistically and keeps the server result',
      () async {
    final container = containerWith(_FakeCartRepository());
    await container.read(cartProvider.future);

    await container.read(cartProvider.notifier).updateQuantity('p1', 5);

    final cart = container.read(cartProvider).requireValue;
    expect(cart.items.single.quantity, 5);
  });

  test('failed quantity update rolls back to the previous cart', () async {
    final repository = _FakeCartRepository()..failMutations = true;
    final container = containerWith(repository);
    await container.read(cartProvider.future);

    await expectLater(
      container.read(cartProvider.notifier).updateQuantity('p1', 5),
      throwsA(isA<DioException>()),
    );

    final cart = container.read(cartProvider).requireValue;
    expect(cart.items.single.quantity, 1, reason: 'optimistic change undone');
  });

  test('removing an item drops it from state', () async {
    final container = containerWith(_FakeCartRepository());
    await container.read(cartProvider.future);

    await container.read(cartProvider.notifier).remove('p1');

    expect(container.read(cartProvider).requireValue.items, isEmpty);
  });
}

class _FakeCartRepository implements CartRepository {
  bool failMutations = false;
  CartModel cart = CartModel.fromJson({
    'id': 'cart1',
    'items': [
      {
        'product_id': 'p1',
        'seller_id': 's1',
        'seller_name': 'Mouse Shop',
        'name': 'Mouse',
        'price': 450.5,
        'image': '',
        'quantity': 1,
      },
    ],
  });

  @override
  Future<CartModel> get() async => cart;

  @override
  Future<CartModel> update(String productId, int quantity) async {
    _maybeFail('/cart/update');
    cart = CartModel(
      id: cart.id,
      items: [
        for (final item in cart.items)
          if (item.productId == productId)
            item.copyWith(quantity: quantity)
          else
            item,
      ],
    );
    return cart;
  }

  @override
  Future<CartModel> remove(String productId) async {
    _maybeFail('/cart/remove');
    cart = CartModel(
      id: cart.id,
      items: cart.items.where((item) => item.productId != productId).toList(),
    );
    return cart;
  }

  @override
  Future<CartModel> add(String productId, int quantity) =>
      throw UnimplementedError();

  @override
  Future<CartModel> clear() => throw UnimplementedError();

  @override
  Future<CartModel> checkout(List<String> productIds) =>
      throw UnimplementedError();

  @override
  Future<void> buyNow(String productId, int quantity) =>
      throw UnimplementedError();

  void _maybeFail(String path) {
    if (failMutations) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(path: path),
        reason: 'offline',
      );
    }
  }
}
