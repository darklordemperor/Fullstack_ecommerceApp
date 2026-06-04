import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dio/dio_client.dart';
import '../model/user_model.dart';
import '../repository/auth_repository.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

class AuthState {
  const AuthState({this.user, this.loading = false});
  final UserModel? user;
  final bool loading;
  bool get isLoggedIn => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this.repository) : super(const AuthState());
  final AuthRepository repository;

  Future<void> bootstrap() async {
    final token = await DioClient.storage.read(key: 'token');
    if (token == null) return;
    try {
      final user = await repository.me();
      state = AuthState(user: user);
    } catch (_) {
      await DioClient.storage.delete(key: 'token');
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthState(user: state.user, loading: true);
    final result = await repository.login(email, password);
    await DioClient.storage.write(key: 'token', value: result.token);
    state = AuthState(user: result.user);
  }

  Future<void> register(Map<String, dynamic> body) async {
    state = AuthState(user: state.user, loading: true);
    await repository.register(body);
    state = const AuthState();
  }

  Future<void> refreshMe() async {
    state = AuthState(user: await repository.me());
  }

  Future<void> logout() async {
    await DioClient.storage.delete(key: 'token');
    state = const AuthState();
  }

  List<String> rolesFromToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return const [];
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    return List<String>.from(jsonDecode(payload)['role'] ?? const []);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider))..bootstrap();
});
