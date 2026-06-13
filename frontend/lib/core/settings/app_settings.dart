import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettings {
  const AppSettings(
      {this.themeMode = ThemeMode.light, this.languageCode = 'en'});

  final ThemeMode themeMode;
  final String languageCode;

  AppSettings copyWith({ThemeMode? themeMode, String? languageCode}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings());

  void toggleTheme() {
    state = state.copyWith(
        themeMode: state.themeMode == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark);
  }

  void toggleLanguage() {
    state =
        state.copyWith(languageCode: state.languageCode == 'en' ? 'th' : 'en');
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
        (ref) => AppSettingsNotifier());

String tr(WidgetRef ref, String en, String th) {
  return ref.watch(appSettingsProvider).languageCode == 'th' ? th : en;
}
