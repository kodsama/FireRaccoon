import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireracoon/fun_modes/fun_mode.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon/theme/app_colors.dart';
import 'package:fireracoon/theme/theme_palette.dart';

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

  test('default theme settings', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    final settings = container.read(themeProvider);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.paletteType, ThemePaletteType.classic);
    expect(settings.accentType, AccentColorType.green);
    expect(settings.funMode, FunMode.none);
  });

  test('load settings from prefs', () async {
    SharedPreferences.setMockInitialValues({
      'themeMode': 'dark',
      'paletteType': 'spectrum',
      'accentType': 'orange',
      'isRacoonMode': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    final settings = container.read(themeProvider);
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.paletteType, ThemePaletteType.spectrum);
    expect(settings.accentType, AccentColorType.orange);
    expect(settings.isRacoonMode, true);
  });

  test('update theme mode', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    container.read(themeProvider.notifier).setThemeMode(ThemeMode.light);

    final settings = container.read(themeProvider);
    expect(settings.themeMode, ThemeMode.light);
    expect(prefs.getString('themeMode'), 'light');
  });

  test('update palette type normalizes accent', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    container.read(themeProvider.notifier).setPalette(ThemePaletteType.raccoon);

    final settings = container.read(themeProvider);
    expect(settings.paletteType, ThemePaletteType.raccoon);
    expect(settings.accentType, AccentColorType.charcoal);
    expect(prefs.getString('paletteType'), 'raccoon');
  });

  test('update accent type', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    container.read(themeProvider.notifier).setAccent(AccentColorType.violet);

    final settings = container.read(themeProvider);
    expect(settings.accentType, AccentColorType.violet);
    expect(prefs.getString('accentType'), 'violet');
  });

  test('update racoon mode', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    container.read(themeProvider.notifier).setRacoonMode(true);

    final settings = container.read(themeProvider);
    expect(settings.isRacoonMode, true);
    expect(prefs.getString('funMode'), 'racoon');
  });

  test('update palette type', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    container.read(themeProvider.notifier).setPalette(ThemePaletteType.raccoon);

    final settings = container.read(themeProvider);
    expect(settings.paletteType, ThemePaletteType.raccoon);
    expect(settings.accentType, AccentColorType.charcoal);
    expect(prefs.getString('paletteType'), 'raccoon');
  });

  test('apply style updates all fields', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    container
        .read(themeProvider.notifier)
        .applyStyle(
          themeMode: ThemeMode.dark,
          paletteType: ThemePaletteType.spectrum,
          accentType: AccentColorType.sky,
        );

    final settings = container.read(themeProvider);
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.paletteType, ThemePaletteType.spectrum);
    expect(settings.accentType, AccentColorType.sky);
  });

  test('setFunMode persists selection', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    container.read(themeProvider.notifier).setFunMode(FunMode.birthday);

    final settings = container.read(themeProvider);
    expect(settings.funMode, FunMode.birthday);
    expect(prefs.getString('funMode'), 'birthday');
  });

  test('effective palette switches to raccoon when Racoon Mode is on', () {
    const settings = ThemeSettings(
      themeMode: ThemeMode.system,
      paletteType: ThemePaletteType.classic,
      accentType: AccentColorType.green,
      funMode: FunMode.racoon,
    );

    expect(settings.effectivePalette, ThemePaletteType.raccoon);
    expect(settings.effectiveAccent, AccentColorType.charcoal);
  });

  test('effectiveAccent normalizes fun mode override accent', () {
    const settings = ThemeSettings(
      themeMode: ThemeMode.system,
      paletteType: ThemePaletteType.classic,
      accentType: AccentColorType.green,
      funMode: FunMode.birthday,
    );

    expect(settings.effectiveAccent, AccentColorType.red);
  });

  test('ThemeSettings copyWith', () {
    const settings = ThemeSettings(
      themeMode: ThemeMode.system,
      paletteType: ThemePaletteType.classic,
      accentType: AccentColorType.green,
      funMode: FunMode.none,
    );

    final updated = settings.copyWith(
      themeMode: ThemeMode.dark,
      paletteType: ThemePaletteType.raccoon,
      funMode: FunMode.racoon,
    );

    expect(updated.themeMode, ThemeMode.dark);
    expect(updated.paletteType, ThemePaletteType.raccoon);
    expect(updated.accentType, AccentColorType.green);
    expect(updated.funMode, FunMode.racoon);
  });

  test('sharedPreferencesProvider throws when not overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(sharedPreferencesProvider),
      throwsA(isA<Exception>()),
    );
  });

  test('applyStyle without args keeps current style', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = createContainer(prefs);

    final before = container.read(themeProvider);
    container.read(themeProvider.notifier).applyStyle();
    final after = container.read(themeProvider);

    expect(after.themeMode, before.themeMode);
    expect(after.paletteType, before.paletteType);
    expect(after.accentType, before.accentType);
  });
}
