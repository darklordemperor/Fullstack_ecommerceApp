import 'package:flutter/foundation.dart';

import '../config/env_config.dart';

class ApiConstants {
  static const connectTimeout = Duration(seconds: 4);
  static const transferTimeout = Duration(seconds: 20);
  static const _devMachineBaseUrl = 'http://192.168.68.72:8080/api/v1';

  static String get baseUrl {
    return candidateBaseUrls.first;
  }

  static List<String> get candidateBaseUrls {
    if (EnvConfig.configuredBaseUrl.isNotEmpty) {
      return [_withoutTrailingSlash(EnvConfig.configuredBaseUrl)];
    }
    // Staging/prod builds must never fall back to developer-machine hosts.
    if (EnvConfig.current != AppEnvironment.dev) {
      throw StateError(
          'API_BASE_URL must be provided for ${EnvConfig.current.name} builds '
          '(use --dart-define-from-file=env/${EnvConfig.current.name}.json).');
    }
    if (kIsWeb) return const ['http://localhost:8080/api/v1'];

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const [
          'http://10.0.2.2:8080/api/v1',
          'http://127.0.0.1:8080/api/v1',
          _devMachineBaseUrl,
        ],
      _ => const ['http://localhost:8080/api/v1'],
    };
  }

  static const String iosSimulatorBaseUrl = 'http://localhost:8080/api/v1';

  static String _withoutTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
