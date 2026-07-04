import 'package:ecommerce_frontend/core/network/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API client uses short connect timeout and stable transfer timeout',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const connectTimeout = Duration(seconds: 4);
    const transferTimeout = Duration(seconds: 20);

    final dio = container.read(dioProvider);
    expect(dio.options.connectTimeout, connectTimeout);
    expect(dio.options.sendTimeout, transferTimeout);
    expect(dio.options.receiveTimeout, transferTimeout);
  });

  test('bearer token and failover interceptors are installed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);
    expect(dio.interceptors.whereType<AuthTokenInterceptor>(), hasLength(1));
  });
}
