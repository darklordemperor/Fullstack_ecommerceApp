import 'package:dio/dio.dart';

import '../../../../core/network/dio_provider.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../model/user_model.dart';

/// Dio-backed implementation of [AuthRepository]. This is the only auth class
/// that knows about HTTP; everything above it works against the interface.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<UserModel> register(Map<String, dynamic> body) async {
    final response = await _dio.post<dynamic>('/auth/register', data: body);
    return UserModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  @override
  Future<({String token, String refreshToken, UserModel user})> login(
      String email, String password) async {
    final response = await _dio.post<dynamic>('/auth/login',
        data: {'email': email, 'password': password});
    final data = apiPayload<Map<String, dynamic>>(response);
    return (
      token: data['token'] as String,
      refreshToken: data['refresh_token'] as String? ?? '',
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>)
    );
  }

  @override
  Future<UserModel> me() async {
    final response = await _dio.get<dynamic>('/users/me');
    return UserModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  @override
  Future<UserModel> updateProfile(Map<String, dynamic> body) async {
    final response = await _dio.put<dynamic>('/users/me', data: body);
    return UserModel.fromJson(apiPayload<Map<String, dynamic>>(response));
  }

  @override
  Future<void> applySeller(
      String shopName, String shopLocation, String taxPayerNumber) async {
    await _dio.post<dynamic>('/users/seller-apply', data: {
      'shop_name': shopName,
      'shop_location': shopLocation,
      'tax_payer_number': taxPayerNumber,
    });
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _dio.post<dynamic>('/auth/logout', data: {'refresh_token': refreshToken});
  }
}
