/// Build-time environment selection.
///
/// The environment is chosen per build with `--dart-define-from-file`:
///
/// ```bash
/// flutter run --dart-define-from-file=env/dev.json
/// flutter build apk --dart-define-from-file=env/prod.json
/// ```
///
/// Only `dev` may run without an explicit `API_BASE_URL`; staging and prod
/// builds fail fast at startup instead of silently talking to localhost.
enum AppEnvironment { dev, staging, prod }

abstract final class EnvConfig {
  static const _envName =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  /// Explicit backend URL for this build. Required outside dev.
  static const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static AppEnvironment get current => switch (_envName) {
        'prod' || 'production' => AppEnvironment.prod,
        'staging' || 'test' || 'uat' => AppEnvironment.staging,
        _ => AppEnvironment.dev,
      };

  static bool get isProd => current == AppEnvironment.prod;

  /// Label shown on the corner banner for non-production builds so testers
  /// always know which backend they are hitting.
  static String? get bannerLabel => switch (current) {
        AppEnvironment.prod => null,
        AppEnvironment.staging => 'STAGING',
        AppEnvironment.dev => 'DEV',
      };
}
