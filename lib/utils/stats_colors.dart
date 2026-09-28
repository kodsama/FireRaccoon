import 'package:flutter/material.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../theme/app_colors.dart';

/// The hue a type is drawn in, so money out reads red, money in green and
/// money moved between accounts blue at a glance, whatever the accent.
Color statsTypeColor(AppColors colors, TransactionTypeFilter type) =>
    switch (type) {
      TransactionTypeFilter.expense => colors.danger,
      TransactionTypeFilter.income => colors.success,
      _ => const Color(0xFF3B82F6),
    };

/// [count] shades of [base], darkest first, for the parts of one type: the
/// largest part gets the deepest shade and each after it a lighter one.
List<Color> statsShades(Color base, int count) {
  if (count <= 0) return const [];
  final hsl = HSLColor.fromColor(base);
  if (count == 1) return [base];
  const darkest = 0.3;
  const lightest = 0.78;
  return [
    for (var i = 0; i < count; i++)
      hsl
          .withLightness(darkest + (lightest - darkest) * i / (count - 1))
          .withSaturation((hsl.saturation * (1 - 0.3 * i / (count - 1))))
          .toColor(),
  ];
}

/// The shade for part [index] of [count] in [type]'s hue.
Color statsShade(
  AppColors colors,
  TransactionTypeFilter type,
  int index,
  int count,
) => statsShades(statsTypeColor(colors, type), count)[index];

/// The line net income is drawn as: a colour no type uses.
const kStatsNetColor = Color(0xFFF59E0B);
