// coverage:ignore-file — decorative painter shell
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../fun_sticker.dart';

final Map<FunStickerId, FunStickerPainterBuilder> raccoonStickerPainters = {
  FunStickerId.raccoonTail: RaccoonTailPainter.new,
  FunStickerId.raccoonEyes: RaccoonEyesPainter.new,
  FunStickerId.goldCoin: GoldCoinPainter.new,
  FunStickerId.rainbow: RainbowArcPainter.new,
  FunStickerId.sparkle: SparklePainter.new,
};

class RaccoonTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.85, size.height * 0.15)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.1,
        size.width * 0.1,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.05,
        size.height * 0.95,
        size.width * 0.45,
        size.height * 0.9,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.85,
        size.width * 0.85,
        size.height * 0.15,
      );

    paint.color = const Color(0xFF666666);
    canvas.drawPath(path, paint);

    final stripe = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.25),
      Offset(size.width * 0.25, size.height * 0.5),
      stripe,
    );
    canvas.drawLine(
      Offset(size.width * 0.45, size.height * 0.55),
      Offset(size.width * 0.2, size.height * 0.78),
      stripe,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RaccoonEyesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mask = Paint()..color = const Color(0xFF333333);
    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.35, size.width, size.height * 0.3),
      Radius.circular(size.height * 0.15),
    );
    canvas.drawRRect(band, mask);

    final eyeWhite = Paint()..color = Colors.white;
    final pupil = Paint()..color = const Color(0xFF111111);
    for (final dx in [size.width * 0.28, size.width * 0.72]) {
      final center = Offset(dx, size.height * 0.5);
      canvas.drawCircle(center, size.width * 0.14, eyeWhite);
      canvas.drawCircle(center, size.width * 0.07, pupil);
      canvas.drawCircle(
        center.translate(-size.width * 0.03, -size.width * 0.02),
        size.width * 0.025,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoldCoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFE8E8E8), Color(0xFF888888)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF666666)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.06,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '\$',
        style: TextStyle(
          color: const Color(0xFF333333),
          fontSize: size.width * 0.5,
          fontWeight: FontWeight.w800,
          fontFamily: 'Roboto Slab',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RainbowArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFF111111),
      Color(0xFF333333),
      Color(0xFF555555),
      Color(0xFF777777),
      Color(0xFF999999),
      Color(0xFFBBBBBB),
    ];

    final rect = Rect.fromLTWH(0, size.height * 0.15, size.width, size.height);
    for (var i = 0; i < colors.length; i++) {
      final stroke = size.width * 0.09;
      final inset = i * stroke * 0.55;
      canvas.drawArc(
        rect.deflate(inset),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFAAAAAA)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final tip =
          center + Offset(math.cos(angle), math.sin(angle)) * size.width * 0.42;
      canvas.drawCircle(tip, size.width * 0.08, paint);
    }
    canvas.drawCircle(
      center,
      size.width * 0.12,
      paint..color = const Color(0xFFDDDDDD),
    );
    canvas.drawCircle(center, size.width * 0.05, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
