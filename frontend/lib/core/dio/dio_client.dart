import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../constants/api_constants.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class DioClient {
  DioClient._();

  static const storage = FlutterSecureStorage();
  static final List<String> _baseUrlCandidates = ApiConstants.candidateBaseUrls;
  static int _activeBaseUrlIndex = 0;

  static final Dio dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: ApiConstants.connectTimeout,
    sendTimeout: ApiConstants.transferTimeout,
    receiveTimeout: ApiConstants.transferTimeout,
  ))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.read(key: 'token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final context = rootNavigatorKey.currentContext;
            await storage.delete(key: 'token');
            await storage.write(
                key: 'auth_message',
                value: 'Your session expired. Please sign in again.');
            if (context != null && context.mounted) {
              context.go('/login');
            }
          }
          if (_shouldTryNextBaseUrl(error)) {
            final response = await _retryWithNextBaseUrl(error);
            if (response != null) {
              handler.resolve(response);
              return;
            }
          }
          handler.next(error);
        },
      ),
    );

  static dynamic payload(Response response) => response.data['data'];

  static bool _shouldTryNextBaseUrl(DioException error) {
    if (_baseUrlCandidates.length <= 1) return false;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      _ => false,
    };
  }

  static Future<Response<dynamic>?> _retryWithNextBaseUrl(
    DioException error,
  ) async {
    final previousBaseUrl = dio.options.baseUrl;
    for (var attempts = 1; attempts < _baseUrlCandidates.length; attempts++) {
      _activeBaseUrlIndex =
          (_activeBaseUrlIndex + 1) % _baseUrlCandidates.length;
      final nextBaseUrl = _baseUrlCandidates[_activeBaseUrlIndex];
      if (nextBaseUrl == previousBaseUrl) continue;

      dio.options.baseUrl = nextBaseUrl;
      try {
        final request = error.requestOptions;
        return await dio.fetch<dynamic>(
          request.copyWith(
            baseUrl: nextBaseUrl,
            path: request.path,
          ),
        );
      } on DioException catch (nextError) {
        if (!_shouldTryNextBaseUrl(nextError)) rethrow;
      }
    }
    dio.options.baseUrl = previousBaseUrl;
    return null;
  }
}
