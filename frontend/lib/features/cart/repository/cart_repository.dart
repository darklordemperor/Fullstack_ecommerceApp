import '../../../core/dio/dio_client.dart';
import '../model/cart_model.dart';

class CartRepository {
  Future<CartModel> get() async {
    final response = await DioClient.dio.get('/cart');
    return CartModel.fromJson(DioClient.payload(response));
  }

  Future<CartModel> add(String productId, int quantity) async {
    final response = await DioClient.dio.post('/cart/add',
        data: {'product_id': productId, 'quantity': quantity});
    return CartModel.fromJson(DioClient.payload(response));
  }

  Future<CartModel> update(String productId, int quantity) async {
    final response = await DioClient.dio.put('/cart/update',
        data: {'product_id': productId, 'quantity': quantity});
    return CartModel.fromJson(DioClient.payload(response));
  }

  Future<CartModel> remove(String productId) async {
    final response = await DioClient.dio.delete('/cart/remove/$productId');
    return CartModel.fromJson(DioClient.payload(response));
  }

  Future<CartModel> clear() async {
    final response = await DioClient.dio.delete('/cart/clear');
    return CartModel.fromJson(DioClient.payload(response));
  }

  Future<CartModel> checkout() async {
    final response = await DioClient.dio.post('/cart/checkout');
    final data = DioClient.payload(response);
    return CartModel.fromJson(data['cart']);
  }

  Future<void> buyNow(String productId, int quantity) async {
    await DioClient.dio.post('/cart/buy-now',
        data: {'product_id': productId, 'quantity': quantity});
  }
}
