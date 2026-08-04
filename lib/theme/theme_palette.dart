import 'package:flutter/material.dart';

import 'app_colors.dart';

enum ThemePaletteType { classic, spectrum, raccoon }

extension ThemePaletteTypeX on ThemePaletteType {
  List<AccentColorType> get accentOptions {
    switch (this) {
      case ThemePaletteType.classic:
        return const [
          AccentColorType.green,
          AccentColorType.teal,
          AccentColorType.blue,
          AccentColorType.orange,
          AccentColorType.red,
          AccentColorType.violet,
        ];
      case ThemePaletteType.spectrum:
        return const [
          AccentColorType.red,
          AccentColorType.orange,
          AccentColorType.lime,
          AccentColorType.blue,
          AccentColorType.sky,
          AccentColorType.violet,
        ];
      case ThemePaletteType.raccoon:
        return const [
          AccentColorType.charcoal,
          AccentColorType.silver,
          AccentColorType.slate,
          AccentColorType.midnight,
          AccentColorType.smoke,
          AccentColorType.pearl,
        ];
    }
  }

  AccentColorType get defaultAccent => accentOptions.first;

  static const spectrumCategoryRamp = [
    Color(0xFFD64A4A),
    Color(0xFFE07B29),
    Color(0xFF84CC16),
    Color(0xFF2A6FDB),
    Color(0xFF38BDF8),
    Color(0xFF7A5AD6),
  ];

  static const raccoonCategoryRamp = [
    Color(0xFF111111),
    Color(0xFF333333),
    Color(0xFF555555),
    Color(0xFF777777),
    Color(0xFFAAAAAA),
    Color(0xFFDDDDDD),
  ];
}

class ThemePalette {
  static AppColors resolve({
    required bool isDark,
    required ThemePaletteType palette,
    required AccentColorType accentType,
  }) {
    final accent = AppAccent.fromType(accentType);
    final base = isDark ? AppColors.dark(accent) : AppColors.light(accent);

    switch (palette) {
      case ThemePaletteType.classic:
        return base;
      case ThemePaletteType.spectrum:
        return base.copyWith(
          categoryRamp: ThemePaletteTypeX.spectrumCategoryRamp,
        );
      case ThemePaletteType.raccoon:
        return isDark ? _raccoonDark(accent) : _raccoonLight(accent);
    }
  }

  static AppColors _raccoonLight(AppAccent accent) {
    return AppColors(
      isDark: false,
      pageBg: const Color(0xFFF0F0F0),
      surface: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFE8E8E8),
      sunken: const Color(0xFFF7F7F7),
      border: const Color(0xFFD0D0D0),
      divider: const Color(0xFFE5E5E5),
      text: const Color(0xFF111111),
      text2: const Color(0xFF555555),
      text3: const Color(0xFF999999),
      headerBg: const Color(0xD8FFFFFF),
      track: const Color(0xFFE5E5E5),
      trackStrong: const Color(0xFFB0B0B0),
      overlay: const Color(0x80111111),
      accent: accent,
      categoryRamp: ThemePaletteTypeX.raccoonCategoryRamp,
      success: const Color(0xFF111111),
      warning: const Color(0xFF666666),
      danger: const Color(0xFF888888),
    );
  }

  static AppColors _raccoonDark(AppAccent accent) {
    return AppColors(
      isDark: true,
      pageBg: const Color(0xFF0F0F0F),
      surface: const Color(0xFF1A1A1A),
      surface2: const Color(0xFF121212),
      sunken: const Color(0xFF141414),
      border: const Color(0xFF3D3D3D),
      divider: const Color(0xFF2E2E2E),
      text: const Color(0xFFF5F5F5),
      text2: const Color(0xFFB8B8B8),
      text3: const Color(0xFF737373),
      headerBg: const Color(0xD10F0F0F),
      track: const Color(0xFF2E2E2E),
      trackStrong: const Color(0xFF525252),
      overlay: const Color(0x99000000),
      accent: accent,
      categoryRamp: ThemePaletteTypeX.raccoonCategoryRamp,
      success: const Color(0xFFEEEEEE),
      warning: const Color(0xFFAAAAAA),
      danger: const Color(0xFF888888),
    );
  }

  static AccentColorType normalizeAccent(
    ThemePaletteType palette,
    AccentColorType accent,
  ) {
    final options = palette.accentOptions;
    if (options.contains(accent)) return accent;
    return palette.defaultAccent;
  }
}
