import 'package:flutter/material.dart';

/// Wraps [child] with a hover tooltip. Use on fields, buttons, and menus.
Widget withTooltip(String message, Widget child) {
  return Tooltip(message: message, child: child);
}
