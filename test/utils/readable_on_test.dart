import 'package:fireraccoon/utils/readable_on.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a dark background gets white text', () {
    // The default danger red, which is what left the connection error
    // unreadable when the theme's own dark content colour was used.
    expect(onColor(const Color(0xFFE05656)), Colors.white);
    expect(onColor(const Color(0xFF111111)), Colors.white);
  });

  test('a light background gets dark text', () {
    expect(onColor(const Color(0xFFEEEEEE)), Colors.black87);
    expect(onColor(Colors.white), Colors.black87);
  });

  test('the mid grey Raccoon Mode uses for danger stays readable', () {
    // A fixed white would have been the wrong answer here, which is why the
    // colour is picked from the background.
    final chosen = onColor(const Color(0xFF888888));

    expect(chosen, anyOf(Colors.white, Colors.black87));
    expect(
      chosen == Colors.white
          ? Colors.white.computeLuminance()
          : Colors.black87.computeLuminance(),
      isNot(closeTo(const Color(0xFF888888).computeLuminance(), 0.15)),
    );
  });
}
