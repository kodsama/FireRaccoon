import 'package:flutter/material.dart';

/// Black or white, whichever is genuinely readable on [background].
///
/// Chosen by contrast ratio rather than by
/// [ThemeData.estimateBrightnessForColor], whose threshold calls a mid tone
/// dark and hands back white: on the default danger red that is 3.7:1, under
/// what body text needs, where black is 5.6:1. Computed rather than fixed
/// because a palette is free to make a semantic colour light or dark, and
/// Raccoon Mode renders danger as a mid grey.
Color onColor(Color background) {
  final luminance = background.computeLuminance();
  final onWhite = 1.05 / (luminance + 0.05);
  final onBlack = (luminance + 0.05) / 0.05;
  return onWhite >= onBlack ? Colors.white : Colors.black;
}
