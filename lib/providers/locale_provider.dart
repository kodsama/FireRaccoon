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

/// Locales offered for numbers and for dates.
///
/// Wider than the six the interface is translated into, because the
/// conventions are a separate choice from the language: reading the app in
/// English while writing amounts the French way and dates the American way is
/// a combination no single locale expresses. Every entry here has number
/// symbols compiled into `intl`, and date symbols are loaded for all locales at
/// startup, so any of them formats both.
const List<Locale> kFormattingLocales = [
  Locale('en', 'US'),
  Locale('en', 'GB'),
  Locale('fr', 'FR'),
  Locale('fr', 'CA'),
  Locale('de', 'DE'),
  Locale('es', 'ES'),
  Locale('it', 'IT'),
  Locale('nl', 'NL'),
  Locale('pt', 'PT'),
  Locale('pt', 'BR'),
  Locale('sv', 'SE'),
  Locale('da', 'DK'),
  Locale('nb', 'NO'),
  Locale('fi', 'FI'),
  Locale('pl', 'PL'),
  Locale('ja', 'JP'),
  Locale('zh', 'CN'),
];

/// Reads and writes one formatting preference.
///
/// Null means "whatever the interface language uses", which is what everybody
/// gets until they say otherwise, so nothing changes for anyone who never opens
/// the setting.
class FormattingLocaleNotifier extends Notifier<Locale?> {
  FormattingLocaleNotifier(this._key);

  final String _key;
  late SharedPreferences _prefs;

  @override
  Locale? build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return parseLocaleTag(_prefs.getString(_key));
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await _prefs.remove(_key);
      return;
    }
    await _prefs.setString(_key, formatLocaleTag(locale));
  }
}

/// `fr_FR` and the like, which is what [Locale.toString] produces.
String formatLocaleTag(Locale locale) => locale.toString();

Locale? parseLocaleTag(String? raw) {
  final tag = raw?.trim() ?? '';
  if (tag.isEmpty) return null;
  final parts = tag.split(RegExp('[_-]'));
  final parsed = parts.length > 1
      ? Locale(parts.first, parts[1])
      : Locale(parts.first);
  // A tag nobody offers would format against data that may not be there.
  return kFormattingLocales.any((l) => l.toString() == parsed.toString())
      ? parsed
      : null;
}

final numberLocaleProvider =
    NotifierProvider<FormattingLocaleNotifier, Locale?>(
      () => FormattingLocaleNotifier('numberLocale'),
    );

final dateLocaleProvider = NotifierProvider<FormattingLocaleNotifier, Locale?>(
  () => FormattingLocaleNotifier('dateLocale'),
);

/// The locale numbers are actually written in.
final effectiveNumberLocaleProvider = Provider<Locale>((ref) {
  return ref.watch(numberLocaleProvider) ?? ref.watch(localeProvider).locale;
});

/// The locale dates are actually written in.
final effectiveDateLocaleProvider = Provider<Locale>((ref) {
  return ref.watch(dateLocaleProvider) ?? ref.watch(localeProvider).locale;
});
