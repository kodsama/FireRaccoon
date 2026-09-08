import 'package:flutter/material.dart';

/// Black or white, whichever can be read on [background].
///
/// Picked from the colour rather than fixed, because a palette is free to make
/// a semantic colour light or dark: Raccoon Mode renders danger as a mid grey,
/// where the white that suits the default red is the wrong answer.
Color onColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black87;
