import 'package:dio/dio.dart';
import 'package:ecommerce_frontend/features/auth/model/user_model.dart';
import 'package:ecommerce_frontend/features/auth/provider/auth_provider.dart';
import 'package:ecommerce_frontend/features/auth/repository/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('login clears loading state when the API request fails', () async {
    final notifier = AuthNotifier(_FailingAuthRepository());

    await expectLater(
      notifier.login('test@example.com', 'abc12345'),
      throwsA(isA<DioException>()),
    );

    expect(notifier.state.loading, isFalse);
    expect(notifier.state.isLoggedIn, isFalse);
  });

  test('register signs in with the new account after registration succeeds',
      () async {
    final repository = _RegisterThenLoginAuthRepository();
    final notifier = AuthNotifier(repository);

    await notifier.register({
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

    expect(repository.registered, isTrue);
    expect(repository.loginEmail, 'new@example.com');
    expect(repository.loginPassword, 'abc12345');
    expect(notifier.state.loading, isFalse);
    expect(notifier.state.user?.email, 'new@example.com');
    expect(notifier.state.isLoggedIn, isTrue);
  });
}

class _FailingAuthRepository extends AuthRepository {
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
