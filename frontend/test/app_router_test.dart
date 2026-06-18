import 'package:ecommerce_frontend/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login redirect keeps the requested product deep link', () {
    expect(
      loginLocationFor('/products/p1'),
      '/login?next=%2Fproducts%2Fp1',
    );
  });

  test('post login target only accepts internal app paths', () {
    expect(postLoginLocation('/products/p1'), '/products/p1');
    expect(postLoginLocation('https://example.com/products/p1'), '/home');
    expect(postLoginLocation('//example.com/products/p1'), '/home');
    expect(postLoginLocation('/login'), '/home');
  });
}
