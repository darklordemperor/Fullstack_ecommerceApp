import 'package:ecommerce_frontend/core/dio/dio_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API client uses short connect timeout and stable transfer timeout', () {
    const connectTimeout = Duration(seconds: 4);
    const transferTimeout = Duration(seconds: 20);

    expect(DioClient.dio.options.connectTimeout, connectTimeout);
    expect(DioClient.dio.options.sendTimeout, transferTimeout);
    expect(DioClient.dio.options.receiveTimeout, transferTimeout);
  });
}
