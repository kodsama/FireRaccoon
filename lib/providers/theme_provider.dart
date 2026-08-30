import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../fun_modes/fun_mode.dart';
import '../fun_modes/fun_mode_definition.dart';
import '../fun_modes/fun_mode_registry.dart';
import '../fun_modes/fun_mode_resolver.dart';
import '../theme/app_colors.dart';
import '../theme/theme_palette.dart';

class ThemeSettings {
  final ThemeMode themeMode;
  final ThemePaletteType paletteType;
  final AccentColorType accentType;
  final FunMode funMode;

  const ThemeSettings({
    required this.themeMode,
    required this.paletteType,
    required this.accentType,
    required this.funMode,
  });

  bool get isRaccoonMode => funMode == FunMode.raccoon;

  FunMode get effectiveFunMode => FunModeResolver.resolve(funMode);

  FunModeDefinition get funModeDefinition =>
      FunModeRegistry.get(effectiveFunMode);

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    ThemePaletteType? paletteType,
    AccentColorType? accentType,
    FunMode? funMode,
    bool? isRaccoonMode,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      paletteType: paletteType ?? this.paletteType,
      accentType: accentType ?? this.accentType,
      funMode:
          funMode ??
          (isRaccoonMode != null
              ? (isRaccoonMode ? FunMode.raccoon : FunMode.none)
              : this.funMode),
    );
  }

  /// Fun modes can override the palette without overwriting the saved style.
  ThemePaletteType get effectivePalette =>
      funModeDefinition.paletteOverride ?? paletteType;

  AccentColorType get effectiveAccent {
    final palette = effectivePalette;
    final override = funModeDefinition.accentOverride;
    if (override != null) {
      return ThemePalette.normalizeAccent(palette, override);
    }
    return ThemePalette.normalizeAccent(palette, accentType);
  }
}

class ThemeNotifier extends Notifier<ThemeSettings> {
  late SharedPreferences _prefs;

  @override
  ThemeSettings build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final palette = _loadPaletteType(_prefs);
    return ThemeSettings(
      themeMode: _loadThemeMode(_prefs),
      paletteType: palette,
      accentType: _loadAccentType(_prefs, palette),
      funMode: _loadFunMode(_prefs),
    );
  }

  static ThemeMode _loadThemeMode(SharedPreferences prefs) {
    final val = prefs.getString('themeMode');
    if (val == 'dark') return ThemeMode.dark;
    if (val == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  static ThemePaletteType _loadPaletteType(SharedPreferences prefs) {
    final val = prefs.getString('paletteType');
    if (val != null) {
      for (final type in ThemePaletteType.values) {
        if (type.name == val) return type;
      }
    }
    return ThemePaletteType.classic;
  }

  static AccentColorType _loadAccentType(
    SharedPreferences prefs,
    ThemePaletteType palette,
  ) {
    final val = prefs.getString('accentType');
    if (val != null) {
      for (var type in AccentColorType.values) {
        if (type.name == val) {
          return ThemePalette.normalizeAccent(palette, type);
        }
      }
    }
    return palette.defaultAccent;
  }

  static FunMode _loadFunMode(SharedPreferences prefs) {
    final stored = prefs.getString('funMode');
    if (stored != null) {
      for (final mode in FunMode.values) {
        if (mode.name == stored) return mode;
      }
    }
    if (prefs.getBool('isRaccoonMode') ?? false) return FunMode.raccoon;
    return FunMode.none;
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs.setString('themeMode', mode.name);
  }

  void setPalette(ThemePaletteType palette) {
    final accent = ThemePalette.normalizeAccent(palette, state.accentType);
    state = state.copyWith(paletteType: palette, accentType: accent);
    _prefs.setString('paletteType', palette.name);
    _prefs.setString('accentType', accent.name);
  }

  void setAccent(AccentColorType type) {
    final accent = ThemePalette.normalizeAccent(state.paletteType, type);
    state = state.copyWith(accentType: accent);
    _prefs.setString('accentType', accent.name);
  }

  void applyStyle({
    ThemeMode? themeMode,
    ThemePaletteType? paletteType,
    AccentColorType? accentType,
  }) {
    final palette = paletteType ?? state.paletteType;
    final accent = ThemePalette.normalizeAccent(
      palette,
      accentType ?? state.accentType,
    );
    final mode = themeMode ?? state.themeMode;

    state = state.copyWith(
      themeMode: mode,
      paletteType: palette,
      accentType: accent,
    );
    _prefs.setString('themeMode', mode.name);
    _prefs.setString('paletteType', palette.name);
    _prefs.setString('accentType', accent.name);
  }

  void setFunMode(FunMode mode) {
    state = state.copyWith(funMode: mode);
    _prefs.setString('funMode', mode.name);
    _prefs.setBool('isRaccoonMode', mode == FunMode.raccoon);
  }

  void setRaccoonMode(bool isRaccoon) {
    setFunMode(isRaccoon ? FunMode.raccoon : FunMode.none);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // Override in main()
});

final themeProvider = NotifierProvider<ThemeNotifier, ThemeSettings>(
  ThemeNotifier.new,
);
