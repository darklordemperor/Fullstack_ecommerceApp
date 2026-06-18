import 'package:ecommerce_frontend/features/product/model/product_model.dart';
import 'package:ecommerce_frontend/features/product/provider/product_provider.dart';
import 'package:ecommerce_frontend/features/product/repository/product_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refreshes cached product detail after seller updates a product',
      () async {
    final repository = _FakeProductRepository(
      const ProductModel(
        id: 'p1',
        sellerId: 's1',
        sellerName: 'Seller Shop',
        name: 'Old name',
        description: 'Old description',
        price: 50,
        stock: 3,
        category: 'Food',
        images: ['old-image'],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        productRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect((await container.read(productDetailProvider('p1').future)).name,
        'Old name');

    repository.product = const ProductModel(
      id: 'p1',
      sellerId: 's1',
      sellerName: 'Seller Shop',
      name: 'New name',
      description: 'New description',
      price: 55,
      stock: 4,
      category: 'Sports',
      images: ['new-image', 'second-image'],
    );

    refreshProductCaches(container, productId: 'p1');

    final updated = await container.read(productDetailProvider('p1').future);
    expect(updated.name, 'New name');
    expect(updated.images, ['new-image', 'second-image']);
    expect(repository.detailCalls, 2);
  });
}

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository(this.product);

  ProductModel product;
  int detailCalls = 0;

  @override
  Future<ProductModel> detail(String id) async {
    detailCalls++;
    return product;
  }
}
