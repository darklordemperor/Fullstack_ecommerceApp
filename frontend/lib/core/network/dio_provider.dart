import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/provider/auth_provider.dart';
import '../constants/api_constants.dart';

/// Keys for values persisted in platform secure storage.
abstract final class StorageKeys {
  static const token = 'token';
  static const refreshToken = 'refresh_token';
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
    dio: dio,
    // Read lazily inside the callback: the auth notifier depends on this
    // provider, so reading it while building would create a dependency cycle.
    onUnauthorized: () => ref.read(authProvider.notifier).handleUnauthorized(),
  ));
  if (ApiConstants.candidateBaseUrls.length > 1) {
    dio.interceptors.add(BaseUrlFailoverInterceptor(dio));
  }
  return dio;
});

/// Attaches the bearer access token to every request and, on a 401, transparently
/// refreshes the session and retries once.
///
/// The refresh call goes through a bare Dio (no interceptors) so it neither
/// attaches the stale token nor recurses into this handler. Concurrent 401s
/// share a single in-flight refresh. If refresh is impossible or fails, the auth
/// layer is notified so the router redirects to login — navigation stays out of
/// here on purpose.
class AuthTokenInterceptor extends Interceptor {
  AuthTokenInterceptor({
    required this.storage,
    required this.onUnauthorized,
    required Dio dio,
  }) : _dio = dio;

  final FlutterSecureStorage storage;
  final void Function() onUnauthorized;
  final Dio _dio;

  static const _retriedFlag = 'authRetried';

  Future<bool>? _refreshing;

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
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isAuthCall = err.requestOptions.path.contains('/auth/');
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;
    if (!isUnauthorized || isAuthCall || alreadyRetried) {
      handler.next(err);
      return;
    }

    if (!await _refreshOnce()) {
      onUnauthorized();
      handler.next(err);
      return;
    }

    try {
      final token = await storage.read(key: StorageKeys.token);
      final options = err.requestOptions
        ..headers['Authorization'] = 'Bearer $token'
        ..extra[_retriedFlag] = true;
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Refreshes the token pair, collapsing concurrent callers onto one request.
  Future<bool> _refreshOnce() {
    return _refreshing ??=
        _performRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await storage.read(key: StorageKeys.refreshToken);
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final client = Dio(BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: _dio.options.connectTimeout,
        receiveTimeout: _dio.options.receiveTimeout,
      ));
      final response = await client.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = apiPayload<Map<String, dynamic>>(response);
      await storage.write(key: StorageKeys.token, value: data['token'] as String);
      await storage.write(
          key: StorageKeys.refreshToken, value: data['refresh_token'] as String);
      return true;
    } on DioException {
      return false;
    }
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
