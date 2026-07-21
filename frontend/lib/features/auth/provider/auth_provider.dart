import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/utils/jwt.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/auth_usecases.dart';
import '../model/user_model.dart';

/// Binds the [AuthRepository] contract to its Dio-backed implementation.
/// Overriding this provider (with a fake) in a test re-routes the whole auth
/// flow, since every use case is built from it.
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepositoryImpl(ref.watch(dioProvider)));

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

  // Use cases wrap the repository so this view model stays a thin coordinator
  // of state transitions rather than a home for business flow.
  LoginUseCase get _login => LoginUseCase(_repository);
  RegisterUseCase get _register => RegisterUseCase(_repository);
  GetCurrentUserUseCase get _getCurrentUser => GetCurrentUserUseCase(_repository);
  UpdateProfileUseCase get _updateProfile => UpdateProfileUseCase(_repository);

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
    final refreshToken = await _storage.read(key: StorageKeys.refreshToken);
    final storedMessage = await _storage.read(key: StorageKeys.authMessage);
    if (storedMessage != null) {
      await _storage.delete(key: StorageKeys.authMessage);
    }
    if (token == null) {
      _finishBootstrap(Unauthenticated(message: storedMessage));
      return;
    }
    // A locally-expired access token is only fatal when there is no refresh
    // token to renew it; otherwise the /me call below refreshes transparently
    // via the network interceptor.
    final hasRefresh = refreshToken != null && refreshToken.isNotEmpty;
    if (isJwtExpired(token) && !hasRefresh) {
      await _clearTokens();
      _finishBootstrap(const Unauthenticated(
          message: 'Your session expired. Please sign in again.'));
      return;
    }
    try {
      final user = await _getCurrentUser();
      _finishBootstrap(Authenticated(user));
    } on Exception catch (error) {
      log('Auth bootstrap failed', name: 'auth', error: error);
      await _clearTokens();
      _finishBootstrap(const Unauthenticated(
          message: 'We could not restore your session. Please sign in again.'));
    }
  }

  void _finishBootstrap(AuthState result) {
    if (state is AuthInitial) state = result;
  }

  Future<void> _persistTokens(String token, String refreshToken) async {
    await _storage.write(key: StorageKeys.token, value: token);
    if (refreshToken.isNotEmpty) {
      await _storage.write(key: StorageKeys.refreshToken, value: refreshToken);
    }
  }

  Future<void> _clearTokens() async {
    await _storage.delete(key: StorageKeys.token);
    await _storage.delete(key: StorageKeys.refreshToken);
  }

  Future<void> login(String email, String password) async {
    final previous = state;
    state = const Authenticating();
    try {
      final result = await _login(email, password);
      await _persistTokens(result.token, result.refreshToken);
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
      await _register(body);
      final result = await _login(
        body['email'].toString().trim(),
        body['password'].toString(),
      );
      await _persistTokens(result.token, result.refreshToken);
      state = Authenticated(result.user);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> refreshMe() async {
    state = Authenticated(await _getCurrentUser());
  }

  Future<void> updateProfile(Map<String, dynamic> body) async {
    state = Authenticated(await _updateProfile(body));
  }

  Future<void> logout({String? message}) async {
    final refreshToken = await _storage.read(key: StorageKeys.refreshToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _repository.logout(refreshToken);
      } catch (_) {
        // Best-effort: always clear local state even if the server call fails.
      }
    }
    await _clearTokens();
    state = Unauthenticated(message: message);
  }

  /// Called by the network layer when a 401 could not be recovered by a token
  /// refresh. Drops the session so the router redirects to login. Ignored while
  /// a login attempt is in flight — a wrong password is not an expired session.
  void handleUnauthorized() {
    if (state is! Authenticated) return;
    unawaited(_clearTokens());
    state = const Unauthenticated(
        message: 'Your session expired. Please sign in again.');
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
