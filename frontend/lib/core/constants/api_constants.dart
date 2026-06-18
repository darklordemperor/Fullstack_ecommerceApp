import 'package:flutter/foundation.dart';

class ApiConstants {
  static const connectTimeout = Duration(seconds: 4);
  static const transferTimeout = Duration(seconds: 20);
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _devMachineBaseUrl = 'http://192.168.68.72:8080/api';

  static String get baseUrl {
    return candidateBaseUrls.first;
  }

  static List<String> get candidateBaseUrls {
    if (_configuredBaseUrl.isNotEmpty) {
      return [_withoutTrailingSlash(_configuredBaseUrl)];
    }
    if (kIsWeb) return const ['http://localhost:8080/api'];

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const [
          'http://10.0.2.2:8080/api',
          'http://127.0.0.1:8080/api',
          _devMachineBaseUrl,
        ],
      _ => const ['http://localhost:8080/api'],
    };
  }

  static const String iosSimulatorBaseUrl = 'http://localhost:8080/api';

  static String _withoutTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
