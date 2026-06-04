import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../constants/api_constants.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class DioClient {
  DioClient._();

  static const storage = FlutterSecureStorage();
  static final Dio dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl))
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
            await storage.delete(key: 'token');
            final context = rootNavigatorKey.currentContext;
            if (context != null) context.go('/login');
          }
          handler.next(error);
        },
      ),
    );

  static dynamic payload(Response response) => response.data['data'];
}
