import 'package:ecommerce_frontend/features/cart/domain/repositories/cart_repository.dart';
import 'package:ecommerce_frontend/features/cart/model/cart_model.dart';
import 'package:ecommerce_frontend/features/cart/provider/cart_provider.dart';
import 'package:ecommerce_frontend/features/cart/screen/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cart total and checkout count follow checked products only',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartRepositoryProvider.overrideWithValue(_CartRepository()),
        ],
        child: const MaterialApp(home: CartScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mouse Shop'), findsOneWidget);
    expect(find.text('Checkout (0)'), findsOneWidget);
    expect(find.text('฿0.00'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('Checkout (1)'), findsOneWidget);
    expect(find.textContaining('450.50'), findsNWidgets(2));
  });
}

class _CartRepository implements CartRepository {
  @override
  Future<CartModel> get() async {
    return CartModel.fromJson({
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
  }

  @override
  Future<CartModel> add(String productId, int quantity) =>
      throw UnimplementedError();

  @override
  Future<CartModel> update(String productId, int quantity) =>
      throw UnimplementedError();

  @override
  Future<CartModel> remove(String productId) => throw UnimplementedError();

  @override
  Future<CartModel> clear() => throw UnimplementedError();

  @override
  Future<CartModel> checkout(List<String> productIds) =>
      throw UnimplementedError();

  @override
  Future<void> buyNow(String productId, int quantity) =>
      throw UnimplementedError();
}
