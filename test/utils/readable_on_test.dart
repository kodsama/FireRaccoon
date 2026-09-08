import 'package:fireraccoon/utils/readable_on.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast ratio, so the test asserts readability rather than a colour.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test(
    'the default danger red gets the readable choice, not the estimated one',
    () {
      // 0xFFE05656 is where ThemeData.estimateBrightnessForColor says "dark" and
      // hands back white at 3.7:1, under what body text needs. Black is 5.6:1.
      const danger = Color(0xFFE05656);

      final chosen = onColor(danger);

      expect(chosen, Colors.black);
      expect(_contrast(chosen, danger), greaterThan(4.5));
    },
  );

  test('every semantic colour in the palettes clears AA for body text', () {
    // The colours the banner is actually painted with, across palettes.
    const backgrounds = [
      Color(0xFFE05656), // default danger
      Color(0xFF33A76A), // default success
      Color(0xFF888888), // Raccoon Mode danger and success
      Color(0xFF111111),
      Color(0xFFEEEEEE),
    ];

    for (final background in backgrounds) {
      expect(
        _contrast(onColor(background), background),
        greaterThanOrEqualTo(4.5),
        reason: 'text on $background must clear AA',
      );
    }
  });

  test('it never picks the worse of the two', () {
    for (var i = 0; i <= 255; i += 15) {
      final background = Color.fromARGB(255, i, i, i);
      final chosen = onColor(background);
      final other = chosen == Colors.white ? Colors.black : Colors.white;

      expect(
        _contrast(chosen, background),
        greaterThanOrEqualTo(_contrast(other, background)),
        reason: 'grey $i should take the higher-contrast option',
      );
    }
  });
}
