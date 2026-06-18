import 'package:dio/dio.dart';
import 'package:ecommerce_frontend/features/auth/model/user_model.dart';
import 'package:ecommerce_frontend/features/auth/provider/auth_provider.dart';
import 'package:ecommerce_frontend/features/auth/repository/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login clears loading state when the API request fails', () async {
    final notifier = AuthNotifier(_FailingAuthRepository());

    await expectLater(
      notifier.login('test@example.com', 'abc12345'),
      throwsA(isA<DioException>()),
    );

    expect(notifier.state.loading, isFalse);
    expect(notifier.state.isLoggedIn, isFalse);
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
