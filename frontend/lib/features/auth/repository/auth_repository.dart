import 'package:dio/dio.dart';

import '../../../core/network/dio_provider.dart';
import '../model/user_model.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<UserModel> register(Map<String, dynamic> body) async {
    final response = await _dio.post<dynamic>('/auth/register', data: body);
    return UserModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  Future<({String token, UserModel user})> login(
      String email, String password) async {
    final response = await _dio.post<dynamic>('/auth/login',
        data: {'email': email, 'password': password});
    final data = apiPayload<Map<String, dynamic>>(response);
    return (
      token: data['token'] as String,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>)
    );
  }

  Future<UserModel> me() async {
    final response = await _dio.get<dynamic>('/users/me');
    return UserModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  Future<UserModel> updateProfile(Map<String, dynamic> body) async {
    final response = await _dio.put<dynamic>('/users/me', data: body);
    return UserModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  Future<void> applySeller(
      String shopName, String shopLocation, String taxPayerNumber) async {
    await _dio.post<dynamic>('/users/seller-apply', data: {
      'shop_name': shopName,
      'shop_location': shopLocation,
      'tax_payer_number': taxPayerNumber,
    });
  }
}
