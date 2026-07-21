import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env_config.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';

void main() {
  // Orientation is declared per device in Info.plist / AndroidManifest, not
  // locked here: a runtime portrait lock is an anti-pattern for a multitasking
  // iPad app (it fights Split View / Slide Over). iPhone stays portrait via
  // Info.plist; iPad and Android are free to rotate and resize.
  runApp(const ProviderScope(child: ShopApp()));
}

class ShopApp extends ConsumerWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp.router(
      title: 'ShopApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: Locale(settings.languageCode),
      routerConfig: router,
      builder: (context, child) {
        final label = EnvConfig.bannerLabel;
        if (label == null || child == null) return child ?? const SizedBox();
        return Banner(
          message: label,
          location: BannerLocation.topEnd,
          child: child,
        );
      },
    );
  }
}
