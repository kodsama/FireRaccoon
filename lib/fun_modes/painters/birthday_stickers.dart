// coverage:ignore-file — decorative painter shell
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../fun_sticker.dart';

final Map<FunStickerId, FunStickerPainterBuilder> birthdayStickerPainters = {
  FunStickerId.balloon: BalloonPainter.new,
  FunStickerId.cupcake: CupcakePainter.new,
  FunStickerId.partyHat: PartyHatPainter.new,
  FunStickerId.streamer: StreamerPainter.new,
};

class BalloonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.38);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.55,
        height: size.height * 0.62,
      ),
      Paint()
        ..shader =
            const RadialGradient(
              colors: [Color(0xFFF472B6), Color(0xFFDB2777)],
            ).createShader(
              Rect.fromCircle(center: center, radius: size.width * 0.3),
            ),
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.68),
      Offset(size.width * 0.5, size.height * 0.95),
      Paint()
        ..color = const Color(0xFF9CA3AF)
        ..strokeWidth = size.width * 0.04,
    );
    canvas.drawCircle(
      Offset(size.width * 0.38, size.height * 0.28),
      size.width * 0.06,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CupcakePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wrapper = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.2,
        size.height * 0.45,
        size.width * 0.6,
        size.height * 0.45,
      ),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(wrapper, Paint()..color = const Color(0xFFD97706));

    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.18,
        size.width * 0.76,
        size.height * 0.5,
      ),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFFBCFE8),
    );

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.18),
      size.width * 0.08,
      Paint()..color = const Color(0xFFEF4444),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PartyHatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hat = Path()
      ..moveTo(size.width * 0.12, size.height * 0.88)
      ..lineTo(size.width * 0.88, size.height * 0.88)
      ..lineTo(size.width * 0.5, size.height * 0.08)
      ..close();
    canvas.drawPath(hat, Paint()..color = const Color(0xFF8B5CF6));

    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.35 + i * 0.14);
      canvas.drawCircle(
        Offset(size.width * (0.35 + (i % 2) * 0.3), y),
        size.width * 0.05,
        Paint()
          ..color = [
            const Color(0xFFFACC15),
            const Color(0xFF22C55E),
            const Color(0xFF3B82F6),
            const Color(0xFFEF4444),
          ][i],
      );
    }

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.08),
      size.width * 0.08,
      Paint()..color = const Color(0xFFFACC15),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StreamerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFF22C55E),
      const Color(0xFF3B82F6),
      const Color(0xFFFACC15),
    ];

    for (var i = 0; i < colors.length; i++) {
      paint.color = colors[i];
      final path = Path()
        ..moveTo(size.width * (0.1 + i * 0.05), size.height * 0.1)
        ..quadraticBezierTo(
          size.width * 0.5,
          size.height * (0.35 + i * 0.12),
          size.width * (0.9 - i * 0.05),
          size.height * 0.9,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
