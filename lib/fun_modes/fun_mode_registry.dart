import 'package:flutter/material.dart';

import '../theme/theme_palette.dart';
import 'fun_mode.dart';
import 'fun_mode_definition.dart';
import 'fun_sticker.dart';
import 'painters/birthday_stickers.dart';
import 'painters/christmas_stickers.dart';
import 'painters/racoon_stickers.dart';

/// Central catalog of fun modes — add a definition here to ship a new theme.
class FunModeRegistry {
  const FunModeRegistry._();

  static const _none = FunModeDefinition(
    mode: FunMode.none,
    logoAsset: 'assets/fireracoon_logo.png',
    stickers: [],
    confettiColors: [],
    celebrateOnEnable: false,
  );

  static const _racoon = FunModeDefinition(
    mode: FunMode.racoon,
    paletteOverride: ThemePaletteType.raccoon,
    logoAsset: 'assets/fireracoon_logo.png',
    stickers: [
      FunStickerId.racoonTail,
      FunStickerId.racoonEyes,
      FunStickerId.goldCoin,
      FunStickerId.rainbow,
      FunStickerId.sparkle,
    ],
    confettiColors: [
      Color(0xFFFAFAFA),
      Color(0xFFDDDDDD),
      Color(0xFFAAAAAA),
      Color(0xFF777777),
      Color(0xFF444444),
      Color(0xFF111111),
    ],
    stickerSizeMultiplier: 1.0,
    wiggleAmplitude: 0.1,
  );

  static const _christmas = FunModeDefinition(
    mode: FunMode.christmas,
    paletteOverride: ThemePaletteType.classic,
    logoAsset: 'assets/fireracoon_logo.png',
    logoOverlay: FunStickerId.santaHat,
    stickers: [
      FunStickerId.santaHat,
      FunStickerId.snowflake,
      FunStickerId.candyCane,
      FunStickerId.christmasStar,
    ],
    confettiColors: [
      Color(0xFFDC2626),
      Color(0xFF16A34A),
      Color(0xFFFFFFFF),
      Color(0xFFFACC15),
      Color(0xFF60A5FA),
    ],
    wiggleAmplitude: 0.06,
  );

  static const _birthday = FunModeDefinition(
    mode: FunMode.birthday,
    paletteOverride: ThemePaletteType.spectrum,
    logoAsset: 'assets/fireracoon_logo.png',
    logoOverlay: FunStickerId.partyHat,
    stickers: [
      FunStickerId.balloon,
      FunStickerId.cupcake,
      FunStickerId.partyHat,
      FunStickerId.streamer,
    ],
    confettiColors: [
      Color(0xFFF472B6),
      Color(0xFF8B5CF6),
      Color(0xFFFACC15),
      Color(0xFF22D3EE),
      Color(0xFFFB7185),
    ],
    stickerSizeMultiplier: 1.1,
    wiggleAmplitude: 0.14,
  );

  static const Map<FunMode, FunModeDefinition> definitions = {
    FunMode.none: _none,
    FunMode.racoon: _racoon,
    FunMode.christmas: _christmas,
    FunMode.birthday: _birthday,
  };

  static FunModeDefinition get(FunMode mode) =>
      definitions[mode] ?? definitions[FunMode.none]!;

  static CustomPainter? painterFor(FunStickerId id) {
    final builder =
        racoonStickerPainters[id] ??
        christmasStickerPainters[id] ??
        birthdayStickerPainters[id];
    return builder?.call();
  }
}
