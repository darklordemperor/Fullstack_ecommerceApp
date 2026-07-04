import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/utils/jwt.dart';
import '../model/user_model.dart';
import '../repository/auth_repository.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(dioProvider)));

/// Session state modeled as a sealed hierarchy so impossible combinations
/// (e.g. "loading and errored at the same time") cannot be represented.
///
/// The convenience getters keep widget code readable without exhaustive
/// switches at every call site; pattern matching is available when a screen
/// needs to handle every variant explicitly.
sealed class AuthState {
  const AuthState();

  UserModel? get user => null;
  bool get isLoggedIn => user != null;

  /// Whether the startup session restore has finished.
  bool get bootstrapped => true;

  /// Whether a login/register request is in flight.
  bool get loading => false;

  /// One-shot message to surface on the login screen (e.g. session expired).
  String? get message => null;
}

/// Startup: session restore from secure storage has not finished yet.
class AuthInitial extends AuthState {
  const AuthInitial();

  @override
  bool get bootstrapped => false;
}

/// A login or register request is in flight.
class Authenticating extends AuthState {
  const Authenticating();

  @override
  bool get loading => true;
}

/// A user is signed in with a stored, unexpired token.
class Authenticated extends AuthState {
  const Authenticated(this.user);

  @override
  final UserModel user;
}

/// No valid session; [message] optionally explains why (expired, restore
/// failure, explicit logout).
class Unauthenticated extends AuthState {
  const Unauthenticated({this.message});

  @override
  final String? message;
}

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  @override
  AuthState build() {
    unawaited(_bootstrap());
    return const AuthInitial();
  }

  /// Restores the session from secure storage on startup. Only applies its
  /// result while the state is still [AuthInitial] so an explicit login that
  /// finishes first is never overwritten.
  Future<void> _bootstrap() async {
    final token = await _storage.read(key: StorageKeys.token);
    final storedMessage = await _storage.read(key: StorageKeys.authMessage);
    if (storedMessage != null) {
      await _storage.delete(key: StorageKeys.authMessage);
    }
    if (token == null) {
      _finishBootstrap(Unauthenticated(message: storedMessage));
      return;
    }
    if (isJwtExpired(token)) {
      await _storage.delete(key: StorageKeys.token);
      _finishBootstrap(const Unauthenticated(
          message: 'Your session expired. Please sign in again.'));
      return;
    }
    try {
      final user = await _repository.me();
      _finishBootstrap(Authenticated(user));
    } on Exception catch (error) {
      log('Auth bootstrap failed', name: 'auth', error: error);
      await _storage.delete(key: StorageKeys.token);
      _finishBootstrap(const Unauthenticated(
          message: 'We could not restore your session. Please sign in again.'));
    }
  }

  void _finishBootstrap(AuthState result) {
    if (state is AuthInitial) state = result;
  }

  Future<void> login(String email, String password) async {
    final previous = state;
    state = const Authenticating();
    try {
      final result = await _repository.login(email, password);
      await _storage.write(key: StorageKeys.token, value: result.token);
      state = Authenticated(result.user);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> register(Map<String, dynamic> body) async {
    final previous = state;
    state = const Authenticating();
    try {
      await _repository.register(body);
      final result = await _repository.login(
        body['email'].toString().trim(),
        body['password'].toString(),
      );
      await _storage.write(key: StorageKeys.token, value: result.token);
      state = Authenticated(result.user);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> refreshMe() async {
    state = Authenticated(await _repository.me());
  }

  Future<void> updateProfile(Map<String, dynamic> body) async {
    state = Authenticated(await _repository.updateProfile(body));
  }

  Future<void> logout({String? message}) async {
    await _storage.delete(key: StorageKeys.token);
    state = Unauthenticated(message: message);
  }

  /// Called by the network layer when any request receives a 401. Drops the
  /// session so the router redirects to login. Ignored while a login attempt
  /// is in flight — a wrong password is not an expired session.
  void handleUnauthorized() {
    if (state is! Authenticated) return;
    unawaited(_storage.delete(key: StorageKeys.token));
    state = const Unauthenticated(
        message: 'Your session expired. Please sign in again.');
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
