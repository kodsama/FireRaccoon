import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/theme/app_colors.dart';
import 'package:fireraccoon/utils/stats_colors.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

void main() {
  test('shades keep the hue and run from dark to light', () {
    const red = Color(0xFFD64545);
    final shades = statsShades(red, 5);
    expect(shades, hasLength(5));
    final lightness = shades
        .map((c) => HSLColor.fromColor(c).lightness)
        .toList();
    for (var i = 1; i < lightness.length; i++) {
      expect(lightness[i], greaterThan(lightness[i - 1]));
    }
    for (final shade in shades) {
      expect(
        HSLColor.fromColor(shade).hue,
        closeTo(HSLColor.fromColor(red).hue, 1),
      );
    }
    expect(statsShades(red, 1), [red]);
    expect(statsShades(red, 0), isEmpty);
  });

  test('each type keeps its own hue whatever the accent', () {
    final colors = AppColors.dark(AppAccent.green);
    expect(
      statsTypeColor(colors, TransactionTypeFilter.expense),
      colors.danger,
    );
    expect(
      statsTypeColor(colors, TransactionTypeFilter.income),
      colors.success,
    );
    final transfer = statsTypeColor(colors, TransactionTypeFilter.transfer);
    expect(transfer, isNot(colors.danger));
    expect(transfer, isNot(colors.success));
    expect(
      statsShade(colors, TransactionTypeFilter.expense, 0, 3),
      statsShades(colors.danger, 3).first,
    );
  });
}
