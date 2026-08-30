import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/theme/app_colors.dart';
import 'package:fireraccoon/theme/theme_palette.dart';

void main() {
  test('ThemePalette.classic uses accent-based ramp', () {
    final colors = ThemePalette.resolve(
      isDark: false,
      palette: ThemePaletteType.classic,
      accentType: AccentColorType.green,
    );
    expect(colors.accent.acc, const Color(0xFF1F8A5B));
    expect(colors.categoryRamp.first, colors.accent.acc);
  });

  test('ThemePalette.spectrum uses rainbow category ramp', () {
    final colors = ThemePalette.resolve(
      isDark: true,
      palette: ThemePaletteType.spectrum,
      accentType: AccentColorType.red,
    );
    expect(colors.categoryRamp, ThemePaletteTypeX.spectrumCategoryRamp);
  });

  test('ThemePalette.raccoon uses greyscale surfaces and status colors', () {
    final colors = ThemePalette.resolve(
      isDark: false,
      palette: ThemePaletteType.raccoon,
      accentType: AccentColorType.charcoal,
    );
    expect(colors.pageBg, const Color(0xFFF0F0F0));
    expect(colors.surface, const Color(0xFFFFFFFF));
    expect(colors.text, const Color(0xFF111111));
    expect(colors.categoryRamp, ThemePaletteTypeX.raccoonCategoryRamp);
    expect(colors.accent.acc, const Color(0xFF525252));
    expect(colors.success, const Color(0xFF111111));
    expect(colors.warning, const Color(0xFF666666));
    expect(colors.danger, const Color(0xFF888888));
    expect(_isGreyscale(colors.success), isTrue);
    expect(_isGreyscale(colors.warning), isTrue);
    expect(_isGreyscale(colors.danger), isTrue);
  });

  test('ThemePalette.raccoon dark uses greyscale status colors', () {
    final colors = ThemePalette.resolve(
      isDark: true,
      palette: ThemePaletteType.raccoon,
      accentType: AccentColorType.charcoal,
    );
    expect(colors.success, const Color(0xFFEEEEEE));
    expect(colors.warning, const Color(0xFFAAAAAA));
    expect(colors.danger, const Color(0xFF888888));
  });

  test('normalizeAccent falls back to palette default', () {
    expect(
      ThemePalette.normalizeAccent(
        ThemePaletteType.spectrum,
        AccentColorType.green,
      ),
      AccentColorType.red,
    );
    expect(
      ThemePalette.normalizeAccent(
        ThemePaletteType.raccoon,
        AccentColorType.blue,
      ),
      AccentColorType.charcoal,
    );
  });
}

bool _isGreyscale(Color color) {
  return color.r == color.g && color.g == color.b;
}
