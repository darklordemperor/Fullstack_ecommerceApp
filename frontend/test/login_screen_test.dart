import 'package:dio/dio.dart';
import 'package:ecommerce_frontend/features/auth/screen/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server connection failures show a clear login warning', () {
    final message = loginErrorMessage(
      DioException.connectionTimeout(
        timeout: const Duration(seconds: 20),
        requestOptions: RequestOptions(path: '/auth/login'),
      ),
    );

    expect(message, 'Cannot connect to the server. Please try again.');
  });
}
