import 'package:flutter/material.dart';

/// Identifies a corner sticker; painters live in mode-specific files.
enum FunStickerId {
  raccoonTail,
  raccoonEyes,
  goldCoin,
  rainbow,
  sparkle,
  santaHat,
  snowflake,
  candyCane,
  christmasStar,
  balloon,
  cupcake,
  partyHat,
  streamer,
}

typedef FunStickerPainterBuilder = CustomPainter Function();
