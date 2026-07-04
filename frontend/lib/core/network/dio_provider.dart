import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/provider/auth_provider.dart';
import '../constants/api_constants.dart';

/// Keys for values persisted in platform secure storage.
abstract final class StorageKeys {
  static const token = 'token';
  static const authMessage = 'auth_message';
}

/// Platform secure storage (Keychain on iOS, EncryptedSharedPreferences on
/// Android). Injected so tests can substitute a fake.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Unwraps the `{"data": ...}` envelope every backend endpoint responds with.
T apiPayload<T>(Response<dynamic> response) =>
    (response.data as Map<String, dynamic>)['data'] as T;

/// Shared HTTP client. Repositories receive this instance through their
/// constructors, so the network layer can be mocked in tests and swapped per
/// environment.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: ApiConstants.connectTimeout,
    sendTimeout: ApiConstants.transferTimeout,
    receiveTimeout: ApiConstants.transferTimeout,
  ));
  dio.interceptors.add(AuthTokenInterceptor(
    storage: ref.watch(secureStorageProvider),
    // Read lazily inside the callback: the auth notifier depends on this
    // provider, so reading it while building would create a dependency cycle.
    onUnauthorized: () => ref.read(authProvider.notifier).handleUnauthorized(),
  ));
  if (ApiConstants.candidateBaseUrls.length > 1) {
    dio.interceptors.add(BaseUrlFailoverInterceptor(dio));
  }
  return dio;
});

/// Attaches the bearer token to every request and reports 401 responses to
/// the auth layer.
///
/// Navigation intentionally stays out of this class: the router listens to
/// auth state and redirects to login when the session becomes invalid.
class AuthTokenInterceptor extends Interceptor {
  AuthTokenInterceptor({required this.storage, required this.onUnauthorized});

  final FlutterSecureStorage storage;
  final void Function() onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.read(key: StorageKeys.token);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      onUnauthorized();
    }
    handler.next(err);
  }
}

/// Development-only convenience: when no `--dart-define=API_BASE_URL` is set,
/// connectivity failures are retried against the other candidate hosts
/// (emulator loopback, localhost, dev machine LAN IP) so the app can find the
/// local backend. Production builds configure a single URL, which disables
/// this interceptor entirely.
class BaseUrlFailoverInterceptor extends Interceptor {
  BaseUrlFailoverInterceptor(this._dio)
      : _candidates = ApiConstants.candidateBaseUrls;

  static const _retriedFlag = 'baseUrlFailoverRetried';

  final Dio _dio;
  final List<String> _candidates;
  int _activeIndex = 0;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Requests issued by this interceptor must not fan out recursively.
    if (!_isConnectivityError(err) ||
        err.requestOptions.extra[_retriedFlag] == true) {
      handler.next(err);
      return;
    }
    final previousBaseUrl = _dio.options.baseUrl;
    for (var attempts = 1; attempts < _candidates.length; attempts++) {
      _activeIndex = (_activeIndex + 1) % _candidates.length;
      final nextBaseUrl = _candidates[_activeIndex];
      if (nextBaseUrl == previousBaseUrl) continue;
      _dio.options.baseUrl = nextBaseUrl;
      try {
        final response = await _dio.fetch<dynamic>(
          err.requestOptions.copyWith(
            baseUrl: nextBaseUrl,
            extra: {...err.requestOptions.extra, _retriedFlag: true},
          ),
        );
        handler.resolve(response);
        return;
      } on DioException catch (nextError) {
        if (!_isConnectivityError(nextError)) {
          handler.next(nextError);
          return;
        }
      }
    }
    _dio.options.baseUrl = previousBaseUrl;
    handler.next(err);
  }

  bool _isConnectivityError(DioException error) => switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          true,
        _ => false,
      };
}
