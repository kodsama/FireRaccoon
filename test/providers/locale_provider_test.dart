import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireraccoon/l10n/app_localizations.dart';
import 'package:fireraccoon/providers/locale_provider.dart';
import 'package:fireraccoon/providers/theme_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer createContainer(SharedPreferences prefs) {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('supported locales include Simplified Chinese and Japanese', () {
    expect(AppLocale.supported, contains(const Locale('zh')));
    expect(AppLocale.supported, contains(const Locale('ja')));
    expect(AppLocale.supported, contains(AppLocale.en));
    expect(AppLocale.supported.length, 6);
  });

  test('default locale is English', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    expect(container.read(localeProvider).locale, AppLocale.en);
  });

  test('fromCode maps zh to Simplified Chinese locale', () {
    expect(AppLocale.fromCode('zh').locale, const Locale('zh'));
    expect(AppLocale.fromCode('zh').languageCode, 'zh');
    expect(AppLocale.fromCode('zh').storageKey(), 'zh');
  });

  test('load zh locale from prefs', () async {
    SharedPreferences.setMockInitialValues({'locale': 'zh'});
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    expect(container.read(localeProvider).locale, AppLocale.zh);
  });

  test('setLocale persists zh selection', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    await container
        .read(localeProvider.notifier)
        .setLocale(const AppLocale(AppLocale.zh));

    expect(container.read(localeProvider).locale, AppLocale.zh);
    expect(prefs.getString('locale'), 'zh');
  });

  test('fromCode maps ja to Japanese locale', () {
    expect(AppLocale.fromCode('ja').locale, const Locale('ja'));
    expect(AppLocale.fromCode('ja').languageCode, 'ja');
    expect(AppLocale.fromCode('ja').storageKey(), 'ja');
  });

  test('load ja locale from prefs', () async {
    SharedPreferences.setMockInitialValues({'locale': 'ja'});
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    expect(container.read(localeProvider).locale, AppLocale.ja);
  });

  test('setLocale persists ja selection', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    await container
        .read(localeProvider.notifier)
        .setLocale(const AppLocale(AppLocale.ja));

    expect(container.read(localeProvider).locale, AppLocale.ja);
    expect(prefs.getString('locale'), 'ja');
  });

  test('AppLocalizationsJa exposes translated navigation labels', () {
    final l10n = lookupAppLocalizations(const Locale('ja'));

    expect(l10n.navDashboard, 'ダッシュボード');
    expect(l10n.navSettings, '設定');
    expect(l10n.languageJapanese, '日本語');
    expect(l10n.navSubscriptions, 'サブスクリプションと定期取引');
  });

  test('AppLocalizationsZh exposes translated navigation labels', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));

    expect(l10n.navDashboard, '仪表盘');
    expect(l10n.navSettings, '设置');
    expect(l10n.languageChinese, '简体中文');
    expect(l10n.navSubscriptions, '订阅与定期');
  });
}
