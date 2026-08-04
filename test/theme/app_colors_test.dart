import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/theme/app_colors.dart';

void main() {
  test('AppColors.light instantiation', () {
    final colors = AppColors.light(AppAccent.green);
    expect(colors.isDark, false);
    expect(colors.accent.acc, const Color(0xFF1F8A5B)); // Green accent acc
  });

  test('AppColors.dark instantiation', () {
    final colors = AppColors.dark(AppAccent.violet);
    expect(colors.isDark, true);
    expect(colors.accent.acc, const Color(0xFF7A5AD6)); // Violet accent acc
  });

  test('AppColors lerp', () {
    final colors1 = AppColors.light(AppAccent.green);
    final colors2 = AppColors.dark(AppAccent.violet);

    final lerped = colors1.lerp(colors2, 0.5);
    expect(lerped, isA<AppColors>());
    expect((lerped).isDark, true); // lerp returns other when t >= 0.5
  });

  test('AppAccent.fromType computations', () {
    final green = AppAccent.fromType(AccentColorType.green);
    expect(green.acc, const Color(0xFF1F8A5B));

    final teal = AppAccent.fromType(AccentColorType.teal);
    expect(teal.acc, const Color(0xFF028A93));

    final blue = AppAccent.fromType(AccentColorType.blue);
    expect(blue.acc, const Color(0xFF2A6FDB));

    final orange = AppAccent.fromType(AccentColorType.orange);
    expect(orange.acc, const Color(0xFFE07B29));

    final red = AppAccent.fromType(AccentColorType.red);
    expect(red.acc, const Color(0xFFD64A4A));

    final violet = AppAccent.fromType(AccentColorType.violet);
    expect(violet.acc, const Color(0xFF7A5AD6));

    for (final type in [
      AccentColorType.lime,
      AccentColorType.sky,
      AccentColorType.charcoal,
      AccentColorType.silver,
      AccentColorType.tan,
      AccentColorType.amber,
      AccentColorType.slate,
      AccentColorType.midnight,
      AccentColorType.smoke,
      AccentColorType.pearl,
    ]) {
      expect(AppAccent.fromType(type), isA<AppAccent>());
    }
  });

  test('AppColors copyWith', () {
    final colors = AppColors.light(AppAccent.green);
    final updated = colors.copyWith(accent: AppAccent.red);

    expect((updated).accent.acc, const Color(0xFFD64A4A)); // Red accent acc
    expect(updated.isDark, false);
  });
}
