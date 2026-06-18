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
    AppLanguage.currentCode = state.languageCode;
  }
}

class AppLanguage {
  static String currentCode = 'en';
  static bool get isThai => currentCode == 'th';

  static String text(String en, String th) => isThai ? th : en;
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
        (ref) => AppSettingsNotifier());

String tr(WidgetRef ref, String en, String th) {
  return ref.watch(appSettingsProvider).languageCode == 'th' ? th : en;
}

bool isThai(WidgetRef ref) =>
    ref.watch(appSettingsProvider).languageCode == 'th';

String moneyLocale(WidgetRef ref) => isThai(ref) ? 'th_TH' : 'en_US';

String categoryLabel(WidgetRef ref, String category) {
  final th = switch (category) {
    'All' => 'ทั้งหมด',
    'Electronics' => 'อิเล็กทรอนิกส์',
    'Fashion' => 'แฟชั่น',
    'Food' => 'อาหาร',
    'Sports' => 'กีฬา',
    'Beauty' => 'ความงาม',
    _ => category,
  };
  return isThai(ref) ? th : category;
}

String genderLabel(WidgetRef ref, String gender) {
  final th = switch (gender) {
    'Female' => 'หญิง',
    'Male' => 'ชาย',
    'Other' => 'อื่น ๆ',
    _ => gender,
  };
  return isThai(ref) ? th : gender;
}

String roleLabel(WidgetRef ref, String role) {
  final th = switch (role) {
    'customer' => 'ผู้ซื้อ',
    'seller' => 'ผู้ขาย',
    'admin' => 'แอดมิน',
    _ => role,
  };
  return isThai(ref) ? th : role;
}

String sellerStatusLabel(WidgetRef ref, String status) {
  final th = switch (status) {
    'approved' => 'อนุมัติแล้ว',
    'pending' => 'รอตรวจสอบ',
    'none' => 'ไม่มี',
    _ => status,
  };
  return isThai(ref) ? th : status;
}
