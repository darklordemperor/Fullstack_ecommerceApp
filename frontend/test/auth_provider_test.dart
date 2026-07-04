import 'package:dio/dio.dart';
import 'package:ecommerce_frontend/features/auth/model/user_model.dart';
import 'package:ecommerce_frontend/features/auth/provider/auth_provider.dart';
import 'package:ecommerce_frontend/features/auth/repository/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('bootstrap without a stored token ends unauthenticated', () async {
    final container = containerWith(_RegisterThenLoginAuthRepository());

    // Trigger provider creation, then let the async bootstrap finish.
    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(authProvider);
    expect(state, isA<Unauthenticated>());
    expect(state.bootstrapped, isTrue);
  });
}

class _FailingAuthRepository extends AuthRepository {
  _FailingAuthRepository() : super(Dio());

  @override
  Future<({String token, UserModel user})> login(
    String email,
    String password,
  ) {
    throw DioException.connectionTimeout(
      timeout: const Duration(seconds: 20),
      requestOptions: RequestOptions(path: '/auth/login'),
    );
  }
}

class _RegisterThenLoginAuthRepository extends AuthRepository {
  _RegisterThenLoginAuthRepository() : super(Dio());

  bool registered = false;
  String? loginEmail;
  String? loginPassword;

  @override
  Future<UserModel> register(Map<String, dynamic> body) async {
    registered = true;
    return _user(body['email'].toString());
  }

  @override
  Future<({String token, UserModel user})> login(
    String email,
    String password,
  ) async {
    loginEmail = email;
    loginPassword = password;
    return (token: 'token', user: _user(email));
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
