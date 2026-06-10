import '../../../core/dio/dio_client.dart';
import '../model/product_model.dart';

class ProductRepository {
  Future<List<ProductModel>> list({String? category, String? search, int page = 1, int limit = 20}) async {
    final response = await DioClient.dio.get('/products', queryParameters: {
      if (category != null && category != 'All') 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': limit,
    });
    return (DioClient.payload(response) as List).map((e) => ProductModel.fromJson(e)).toList();
  }

  Future<ProductModel> detail(String id) async {
    final response = await DioClient.dio.get('/products/$id');
    return ProductModel.fromJson(DioClient.payload(response));
  }

  Future<ProductModel> create(Map<String, dynamic> body) async {
    final response = await DioClient.dio.post('/products', data: body);
    return ProductModel.fromJson(DioClient.payload(response));
  }

  Future<ProductModel> update(String id, Map<String, dynamic> body) async {
    final response = await DioClient.dio.put('/products/$id', data: body);
    return ProductModel.fromJson(DioClient.payload(response));
  }

  Future<void> delete(String id) async {
    await DioClient.dio.delete('/products/$id');
  }
}
