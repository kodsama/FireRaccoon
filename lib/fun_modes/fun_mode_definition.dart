import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/theme_palette.dart';
import 'fun_mode.dart';
import 'fun_sticker.dart';

/// Everything a fun mode needs — palette, logo, confetti, and sticker set.
class FunModeDefinition {
  const FunModeDefinition({
    required this.mode,
    this.paletteOverride,
    this.accentOverride,
    required this.logoAsset,
    this.logoOverlay,
    required this.stickers,
    required this.confettiColors,
    this.celebrateOnEnable = true,
    this.stickerSizeMultiplier = 1.0,
    this.logoSizeMultiplier = 1.0,
    this.wiggleAmplitude = 0.08,
  });

  final FunMode mode;
  final ThemePaletteType? paletteOverride;
  final AccentColorType? accentOverride;
  final String logoAsset;
  final FunStickerId? logoOverlay;
  final List<FunStickerId> stickers;
  final List<Color> confettiColors;
  final bool celebrateOnEnable;
  final double stickerSizeMultiplier;
  final double logoSizeMultiplier;
  final double wiggleAmplitude;

  bool get isActive => mode != FunMode.none;
}
