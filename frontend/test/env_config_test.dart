import 'package:ecommerce_frontend/core/config/env_config.dart';
import 'package:ecommerce_frontend/core/constants/api_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tests compile without --dart-define, so the build is a dev build.
  test('defaults to the dev environment when APP_ENV is not defined', () {
    expect(EnvConfig.current, AppEnvironment.dev);
    expect(EnvConfig.isProd, isFalse);
    expect(EnvConfig.bannerLabel, 'DEV');
  });

  test('dev builds fall back to local candidate backend URLs', () {
    expect(ApiConstants.candidateBaseUrls, isNotEmpty);
    expect(
      ApiConstants.baseUrl,
      anyOf(contains('localhost'), contains('10.0.2.2')),
    );
  });
}
