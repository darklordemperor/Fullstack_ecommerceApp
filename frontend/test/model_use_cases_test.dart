import 'package:ecommerce_frontend/features/auth/model/user_model.dart';
import 'package:ecommerce_frontend/features/cart/model/cart_model.dart';
import 'package:ecommerce_frontend/features/product/model/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel seller use cases', () {
    test('approved seller requires seller role and approved status', () {
      final user = UserModel.fromJson({
        'id': 'u1',
        'name': 'Ada',
        'lastname': 'Lovelace',
        'age': 28,
        'email': 'ada@example.com',
        'role': ['customer', 'seller'],
        'seller_status': 'approved',
      });

      expect(user.fullName, 'Ada Lovelace');
      expect(user.initials, 'AL');
      expect(user.isApprovedSeller, isTrue);
    });

    test('pending seller is not treated as approved seller', () {
      final user = UserModel.fromJson({
        'id': 'u2',
        'name': 'Grace',
        'lastname': 'Hopper',
        'age': 30,
        'email': 'grace@example.com',
        'role': ['customer', 'seller'],
        'seller_status': 'pending',
      });

      expect(user.isApprovedSeller, isFalse);
    });
  });

  group('CartModel checkout use cases', () {
    test('computes cart count, item subtotal, and grand total', () {
      final cart = CartModel.fromJson({
        'id': 'cart1',
        'items': [
          {
            'product_id': 'p1',
            'name': 'Keyboard',
            'price': 1200.0,
            'image': 'https://example.com/k.png',
            'quantity': 2
          },
          {
            'product_id': 'p2',
            'name': 'Mouse',
            'price': 450.5,
            'image': 'https://example.com/m.png',
            'quantity': 1
          },
        ],
      });

      expect(cart.count, 2);
      expect(cart.items.first.subtotal, 2400.0);
      expect(cart.total, 2850.5);
    });

    test('merges duplicate product rows into one cart item', () {
      final cart = CartModel.fromJson({
        'id': 'cart1',
        'items': [
          {
            'product_id': 'p1',
            'name': 'Keyboard',
            'price': 1200.0,
            'image': 'https://example.com/k.png',
            'quantity': 1
          },
          {
            'product_id': 'p1',
            'name': 'Keyboard',
            'price': 1200.0,
            'image': 'https://example.com/k.png',
            'quantity': 2
          },
        ],
      });

      expect(cart.count, 1);
      expect(cart.items, hasLength(1));
      expect(cart.items.single.quantity, 3);
      expect(cart.total, 3600.0);
    });

    test('empty cart has zero count and total', () {
      final cart = CartModel.empty();

      expect(cart.count, 0);
      expect(cart.total, 0);
      expect(cart.items, isEmpty);
    });

    test('computes selected cart item count and total only from checked items',
        () {
      final cart = CartModel.fromJson({
        'id': 'cart1',
        'items': [
          {
            'product_id': 'p1',
            'seller_id': 's1',
            'seller_name': 'Keyboard Shop',
            'name': 'Keyboard',
            'price': 1200.0,
            'image': 'https://example.com/k.png',
            'quantity': 2
          },
          {
            'product_id': 'p2',
            'seller_id': 's2',
            'seller_name': 'Mouse Shop',
            'name': 'Mouse',
            'price': 450.5,
            'image': 'https://example.com/m.png',
            'quantity': 1
          },
        ],
      });

      expect(cart.selectedCount({'p2'}), 1);
      expect(cart.selectedTotal({'p2'}), 450.5);
      expect(cart.selectedItems({'p2'}).map((item) => item.productId), ['p2']);
    });

    test('groups cart items by seller shop', () {
      final cart = CartModel.fromJson({
        'id': 'cart1',
        'items': [
          {
            'product_id': 'p1',
            'seller_id': 's1',
            'seller_name': 'Ada Shop',
            'name': 'Keyboard',
            'price': 1200.0,
            'image': 'https://example.com/k.png',
            'quantity': 1
          },
          {
            'product_id': 'p2',
            'seller_id': 's1',
            'seller_name': 'Ada Shop',
            'name': 'Mouse',
            'price': 450.5,
            'image': 'https://example.com/m.png',
            'quantity': 1
          },
          {
            'product_id': 'p3',
            'seller_id': 's2',
            'seller_name': 'Grace Store',
            'name': 'Monitor',
            'price': 3500.0,
            'image': 'https://example.com/m2.png',
            'quantity': 1
          },
        ],
      });

      final groups = cart.shopGroups;

      expect(groups, hasLength(2));
      expect(groups.first.sellerName, 'Ada Shop');
      expect(groups.first.items.map((item) => item.productId), ['p1', 'p2']);
      expect(groups.last.sellerName, 'Grace Store');
    });
  });

  group('ProductModel display use cases', () {
    test('uses first image as main image when images exist', () {
      final product = ProductModel.fromJson({
        'id': 'p1',
        'seller_id': 's1',
        'seller_name': 'Ada Shop',
        'name': 'Bag',
        'description': 'Everyday bag',
        'price': 799.0,
        'stock': 8,
        'category': 'Fashion',
        'images': [
          'https://example.com/main.png',
          'https://example.com/alt.png'
        ],
      });

      expect(product.mainImage, 'https://example.com/main.png');
      expect(product.toRequest()['category'], 'Fashion');
    });

    test('falls back to deterministic image URL when product has no images',
        () {
      final product = ProductModel.fromJson({
        'id': 'p2',
        'seller_id': 's1',
        'seller_name': 'Ada Shop',
        'name': 'Mystery Box',
        'description': 'Surprise item',
        'price': 99.0,
        'stock': 4,
        'category': 'Food',
        'images': [],
      });

      expect(product.mainImage, 'https://picsum.photos/seed/p2/600');
    });
  });
}
