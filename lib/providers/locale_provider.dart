import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_provider.dart';

/// Supported app locales with persisted language selection.
class AppLocale {
  static const en = Locale('en');
  static const fr = Locale('fr');
  static const sv = Locale('sv');
  static const pt = Locale('pt');
  static const zh = Locale('zh');
  static const ja = Locale('ja');

  static const supported = [en, fr, sv, pt, zh, ja];

  final Locale locale;

  const AppLocale(this.locale);

  String get languageCode => locale.languageCode;

  String storageKey() => languageCode;

  static AppLocale fromCode(String? code) {
    return switch (code) {
      'fr' => const AppLocale(fr),
      'sv' => const AppLocale(sv),
      'pt' => const AppLocale(pt),
      'zh' => const AppLocale(zh),
      'ja' => const AppLocale(ja),
      _ => const AppLocale(en),
    };
  }
}

class LocaleNotifier extends Notifier<AppLocale> {
  late SharedPreferences _prefs;

  @override
  AppLocale build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return AppLocale.fromCode(_prefs.getString('locale'));
  }

  Future<void> setLocale(AppLocale locale) async {
    state = locale;
    await _prefs.setString('locale', locale.storageKey());
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLocale>(
  LocaleNotifier.new,
);
