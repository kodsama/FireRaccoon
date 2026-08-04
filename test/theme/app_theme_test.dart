import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/theme/app_theme.dart';
import 'package:fireracoon/theme/app_colors.dart';

void main() {
  test('AppTypography exposes the figure font style', () {
    expect(AppTypography.figure.fontFamily, AppTypography.figureFont);
    expect(AppTypography.figure.fontWeight, FontWeight.w700);
  });

  test('AppTheme.buildTheme builds light theme correctly', () {
    final theme = AppTheme.buildTheme(false, AppAccent.green);

    expect(theme.brightness, Brightness.light);
    expect(
      theme.scaffoldBackgroundColor,
      const Color(0xFFECF0F0),
    ); // pageBg light

    final colorsExtension = theme.extension<AppColors>();
    expect(colorsExtension, isNotNull);
    expect(colorsExtension!.isDark, false);
    expect(
      colorsExtension.accent.acc,
      const Color(0xFF1F8A5B),
    ); // Green accent acc
  });

  test('AppTheme.buildTheme builds dark theme correctly', () {
    final theme = AppTheme.buildTheme(true, AppAccent.violet);

    expect(theme.brightness, Brightness.dark);
    expect(
      theme.scaffoldBackgroundColor,
      const Color(0xFF0E1516),
    ); // pageBg dark

    final colorsExtension = theme.extension<AppColors>();
    expect(colorsExtension, isNotNull);
    expect(colorsExtension!.isDark, true);
    expect(
      colorsExtension.accent.acc,
      const Color(0xFF7A5AD6),
    ); // Violet accent acc
  });

  testWidgets('AppThemeContext extension works', (WidgetTester tester) async {
    final theme = AppTheme.buildTheme(false, AppAccent.green);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            expect(context.colors, isNotNull);
            expect(context.colors.isDark, false);
            expect(context.textTheme, isNotNull);
            return const SizedBox();
          },
        ),
      ),
    );
  });
}
