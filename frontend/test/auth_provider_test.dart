import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:ecommerce_frontend/core/network/dio_provider.dart';
import 'package:ecommerce_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:ecommerce_frontend/features/auth/model/user_model.dart';
import 'package:ecommerce_frontend/features/auth/provider/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const storage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  ProviderContainer containerWith(AuthRepository repository) {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  // Reading the provider kicks off the async startup bootstrap. Pump the event
  // loop until it settles out of the AuthInitial state.
  Future<AuthState> settle(ProviderContainer container) async {
    for (var i = 0; i < 50; i++) {
      if (container.read(authProvider) is! AuthInitial) break;
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(authProvider);
  }

  group('login and register', () {
    test('login clears loading state when the API request fails', () async {
      final container = containerWith(_FailingAuthRepository());
      final notifier = container.read(authProvider.notifier);

      await expectLater(
        notifier.login('test@example.com', 'abc12345'),
        throwsA(isA<DioException>()),
      );

      expect(container.read(authProvider).loading, isFalse);
      expect(container.read(authProvider).isLoggedIn, isFalse);
    });

    test('register signs in with the new account after registration succeeds',
        () async {
      final repository = _RegisterThenLoginAuthRepository();
      final container = containerWith(repository);

      await container.read(authProvider.notifier).register({
        'name': 'Test',
        'lastname': 'User',
        'age': 28,
        'gender': 'Other',
        'address': 'Bangkok',
        'profile_image': '',
        'email': 'new@example.com',
        'password': 'abc12345',
        'confirm_password': 'abc12345',
      });

      final state = container.read(authProvider);
      expect(repository.registered, isTrue);
      expect(repository.loginEmail, 'new@example.com');
      expect(repository.loginPassword, 'abc12345');
      expect(state.loading, isFalse);
      expect(state, isA<Authenticated>());
      expect(state.user?.email, 'new@example.com');
    });
  });

  // These cover the "user opens the app after it was killed" path: the session
  // must be restored from secure storage — or safely dropped — without ever
  // stranding the app in a half-authenticated state.
  group('app open / killed-state session restore', () {
    test('restores an authenticated session from a valid stored token',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.token: _jwt(ttl: const Duration(hours: 1)),
      });
      final repository = _RestoreAuthRepository();
      final container = containerWith(repository);

      final state = await settle(container);

      expect(repository.meCalled, isTrue);
      expect(state, isA<Authenticated>());
      expect(state.isLoggedIn, isTrue);
      expect(state.bootstrapped, isTrue);
    });

    test('expired stored token ends unauthenticated and is cleared', () async {
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.token: _jwt(ttl: const Duration(hours: -1)),
      });
      final repository = _RestoreAuthRepository();
      final container = containerWith(repository);

      final state = await settle(container);

      // A locally-known-expired token must not waste a doomed /me round trip.
      expect(repository.meCalled, isFalse);
      expect(state, isA<Unauthenticated>());
      expect(state.message, contains('expired'));
      expect(await storage.read(key: StorageKeys.token), isNull);
    });

    test('failed /me during restore clears the token and ends unauthenticated',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.token: _jwt(ttl: const Duration(hours: 1)),
      });
      final repository = _RestoreAuthRepository(failMe: true);
      final container = containerWith(repository);

      final state = await settle(container);

      expect(repository.meCalled, isTrue);
      expect(state, isA<Unauthenticated>());
      expect(state.message, contains('could not restore'));
      expect(await storage.read(key: StorageKeys.token), isNull);
    });

    test('bootstrap without a stored token ends unauthenticated', () async {
      final container = containerWith(_RestoreAuthRepository());

      final state = await settle(container);

      expect(state, isA<Unauthenticated>());
      expect(state.bootstrapped, isTrue);
    });

    test('expired access token with a refresh token still restores via /me',
        () async {
      // With a refresh token present, an expired access token must NOT short
      // circuit to logout: /me proceeds (the network interceptor refreshes it).
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.token: _jwt(ttl: const Duration(hours: -1)),
        StorageKeys.refreshToken: 'stored-refresh-token',
      });
      final repository = _RestoreAuthRepository();
      final container = containerWith(repository);

      final state = await settle(container);

      expect(repository.meCalled, isTrue,
          reason: 'must not bail early when a refresh token exists');
      expect(state, isA<Authenticated>());
    });
  });

  group('mid-session 401 and logout', () {
    test('handleUnauthorized drops an authenticated session and clears the token',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.token: _jwt(ttl: const Duration(hours: 1)),
      });
      final container = containerWith(_RestoreAuthRepository());
      final notifier = container.read(authProvider.notifier);
      expect(await settle(container), isA<Authenticated>());

      notifier.handleUnauthorized();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(authProvider);
      expect(state, isA<Unauthenticated>());
      expect(state.message, contains('expired'));
      expect(await storage.read(key: StorageKeys.token), isNull);
    });

    test('handleUnauthorized is ignored when there is no active session',
        () async {
      final container = containerWith(_RestoreAuthRepository());
      final notifier = container.read(authProvider.notifier);
      expect(await settle(container), isA<Unauthenticated>());

      notifier.handleUnauthorized();

      // A wrong password mid-login is not an expired session: state unchanged.
      expect(container.read(authProvider), isA<Unauthenticated>());
    });

    test('logout clears the stored token', () async {
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.token: _jwt(ttl: const Duration(hours: 1)),
      });
      final container = containerWith(_RestoreAuthRepository());
      final notifier = container.read(authProvider.notifier);
      expect(await settle(container), isA<Authenticated>());

      await notifier.logout(message: 'Signed out.');

      final state = container.read(authProvider);
      expect(state, isA<Unauthenticated>());
      expect(state.message, 'Signed out.');
      expect(await storage.read(key: StorageKeys.token), isNull);
    });
  });
}

/// Builds a syntactically valid JWT whose `exp` claim is [ttl] from now
/// (negative [ttl] produces an already-expired token). The signature segment is
/// a placeholder — the client only decodes `exp`; the backend verifies signing.
String _jwt({required Duration ttl}) {
  String seg(Map<String, dynamic> claims) =>
      base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
  final exp = DateTime.now().add(ttl).millisecondsSinceEpoch ~/ 1000;
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg({'exp': exp})}.sig';
}

/// Base fake implementing the full [AuthRepository] contract; each test
/// subclass overrides only the methods it exercises.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<({String token, String refreshToken, UserModel user})> login(
          String email, String password) =>
      throw UnimplementedError();

  @override
  Future<UserModel> register(Map<String, dynamic> body) =>
      throw UnimplementedError();

  @override
  Future<UserModel> me() => throw UnimplementedError();

  @override
  Future<UserModel> updateProfile(Map<String, dynamic> body) =>
      throw UnimplementedError();

  @override
  Future<void> applySeller(
          String shopName, String shopLocation, String taxPayerNumber) =>
      throw UnimplementedError();

  @override
  Future<void> logout(String refreshToken) => throw UnimplementedError();
}

class _FailingAuthRepository extends _FakeAuthRepository {
  @override
  Future<({String token, String refreshToken, UserModel user})> login(
      String email, String password) {
    throw DioException.connectionTimeout(
      timeout: const Duration(seconds: 20),
      requestOptions: RequestOptions(path: '/auth/login'),
    );
  }
}

class _RegisterThenLoginAuthRepository extends _FakeAuthRepository {
  bool registered = false;
  String? loginEmail;
  String? loginPassword;

  @override
  Future<UserModel> register(Map<String, dynamic> body) async {
    registered = true;
    return _user(body['email'].toString());
  }

  @override
  Future<({String token, String refreshToken, UserModel user})> login(
    String email,
    String password,
  ) async {
    loginEmail = email;
    loginPassword = password;
    return (token: 'token', refreshToken: 'refresh-token', user: _user(email));
  }
}

/// Fake used by the startup-restore tests. Records whether `/me` was called so
/// tests can assert the expired-token short circuit, and can be told to fail
/// `/me` to simulate a network/server error during restore.
class _RestoreAuthRepository extends _FakeAuthRepository {
  _RestoreAuthRepository({this.failMe = false});

  final bool failMe;
  bool meCalled = false;

  @override
  Future<UserModel> me() async {
    meCalled = true;
    if (failMe) {
      throw DioException.connectionTimeout(
        timeout: const Duration(seconds: 20),
        requestOptions: RequestOptions(path: '/users/me'),
      );
    }
    return _user('restored@example.com');
  }
}

UserModel _user(String email) {
  return UserModel(
    id: 'u1',
    name: 'Test',
    lastname: 'User',
    age: 28,
    gender: 'Other',
    email: email,
    role: const ['customer'],
  );
}
