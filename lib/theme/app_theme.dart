import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'theme_palette.dart';

class AppTypography {
  static const String bodyFont = 'Comfortaa';
  static const String figureFont = 'Roboto Slab';

  static TextStyle get body =>
      const TextStyle(fontFamily: bodyFont, height: 1.5);
  static TextStyle get heading => const TextStyle(
    fontFamily: bodyFont,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -0.02,
  );
  static TextStyle get figure =>
      const TextStyle(fontFamily: figureFont, fontWeight: FontWeight.w700);
}

class AppTheme {
  static ThemeData buildFromSettings({
    required bool isDark,
    required ThemePaletteType palette,
    required AccentColorType accentType,
  }) {
    final colors = ThemePalette.resolve(
      isDark: isDark,
      palette: palette,
      accentType: accentType,
    );
    return _buildThemeData(isDark, colors);
  }

  static ThemeData buildTheme(bool isDark, AppAccent accent) {
    final colors = isDark ? AppColors.dark(accent) : AppColors.light(accent);
    return _buildThemeData(isDark, colors);
  }

  static ThemeData _buildThemeData(bool isDark, AppColors colors) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: colors.pageBg,
      fontFamily: AppTypography.bodyFont,
      textTheme: TextTheme(
        bodyMedium: AppTypography.body.copyWith(
          color: colors.text,
          fontSize: 14,
        ),
        bodyLarge: AppTypography.body.copyWith(
          color: colors.text,
          fontSize: 16,
        ),
        bodySmall: AppTypography.body.copyWith(
          color: colors.text2,
          fontSize: 12,
        ),
        titleLarge: AppTypography.heading.copyWith(
          color: colors.text,
          fontSize: 24,
        ),
        titleMedium: AppTypography.heading.copyWith(
          color: colors.text,
          fontSize: 18,
        ),
        titleSmall: AppTypography.heading.copyWith(
          color: colors.text,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent.acc,
      ),
      extensions: [colors],
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get textTheme => Theme.of(this).textTheme;
}
