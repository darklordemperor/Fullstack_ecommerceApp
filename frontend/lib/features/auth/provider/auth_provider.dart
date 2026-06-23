import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dio/dio_client.dart';
import '../model/user_model.dart';
import '../repository/auth_repository.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

class AuthState {
  const AuthState(
      {this.user,
      this.loading = false,
      this.bootstrapped = false,
      this.message});
  final UserModel? user;
  final bool loading;
  final bool bootstrapped;
  final String? message;
  bool get isLoggedIn => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this.repository) : super(const AuthState());
  final AuthRepository repository;

  Future<void> bootstrap() async {
    final token = await DioClient.storage.read(key: 'token');
    final storedMessage = await DioClient.storage.read(key: 'auth_message');
    if (storedMessage != null) {
      await DioClient.storage.delete(key: 'auth_message');
    }
    if (token == null) {
      state = AuthState(bootstrapped: true, message: storedMessage);
      return;
    }
    if (isTokenExpired(token)) {
      await DioClient.storage.delete(key: 'token');
      state = const AuthState(
          bootstrapped: true,
          message: 'Your session expired. Please sign in again.');
      return;
    }
    try {
      final user = await repository.me();
      state = AuthState(user: user, bootstrapped: true);
    } catch (error) {
      debugPrint('Auth bootstrap failed: $error');
      await DioClient.storage.delete(key: 'token');
      state = const AuthState(
          bootstrapped: true,
          message: 'We could not restore your session. Please sign in again.');
    }
  }

  Future<void> login(String email, String password) async {
    final previous = state;
    state = AuthState(
        user: previous.user,
        loading: true,
        bootstrapped: previous.bootstrapped);
    try {
      final result = await repository.login(email, password);
      await DioClient.storage.write(key: 'token', value: result.token);
      state = AuthState(user: result.user, bootstrapped: true);
    } catch (_) {
      state =
          AuthState(user: previous.user, bootstrapped: previous.bootstrapped);
      rethrow;
    }
  }

  Future<void> register(Map<String, dynamic> body) async {
    final previous = state;
    state = AuthState(
        user: previous.user,
        loading: true,
        bootstrapped: previous.bootstrapped);
    try {
      await repository.register(body);
      final result = await repository.login(
        body['email'].toString().trim(),
        body['password'].toString(),
      );
      await DioClient.storage.write(key: 'token', value: result.token);
      state = AuthState(user: result.user, bootstrapped: true);
    } catch (_) {
      state =
          AuthState(user: previous.user, bootstrapped: previous.bootstrapped);
      rethrow;
    }
  }

  Future<void> refreshMe() async {
    state = AuthState(user: await repository.me(), bootstrapped: true);
  }

  Future<void> logout({String? message}) async {
    await DioClient.storage.delete(key: 'token');
    state = AuthState(bootstrapped: true, message: message);
  }

  List<String> rolesFromToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return const [];
    final payload =
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    return List<String>.from(jsonDecode(payload)['role'] ?? const []);
  }

  bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final exp = jsonDecode(payload)['exp'];
      if (exp is! num) return true;
      return DateTime.now().millisecondsSinceEpoch >= exp.toInt() * 1000;
    } catch (error) {
      debugPrint('Token decode failed: $error');
      return true;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider))..bootstrap();
});
