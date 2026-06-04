import '../../../core/dio/dio_client.dart';
import '../model/user_model.dart';

class AuthRepository {
  Future<UserModel> register(Map<String, dynamic> body) async {
    final response = await DioClient.dio.post('/auth/register', data: body);
    return UserModel.fromJson(DioClient.payload(response));
  }

  Future<({String token, UserModel user})> login(String email, String password) async {
    final response = await DioClient.dio.post('/auth/login', data: {'email': email, 'password': password});
    final data = DioClient.payload(response);
    return (token: data['token'] as String, user: UserModel.fromJson(data['user']));
  }

  Future<UserModel> me() async {
    final response = await DioClient.dio.get('/users/me');
    return UserModel.fromJson(DioClient.payload(response));
  }

  Future<UserModel> updateProfile(String name, String lastname, int age) async {
    final response = await DioClient.dio.put('/users/me', data: {'name': name, 'lastname': lastname, 'age': age});
    return UserModel.fromJson(DioClient.payload(response));
  }

  Future<void> applySeller(String shopName, String shopLocation, String taxPayerNumber) async {
    await DioClient.dio.post('/users/seller-apply', data: {
      'shop_name': shopName,
      'shop_location': shopLocation,
      'tax_payer_number': taxPayerNumber,
    });
  }
}
