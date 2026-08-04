// coverage:ignore-file — decorative painter shell
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../fun_sticker.dart';

final Map<FunStickerId, FunStickerPainterBuilder> christmasStickerPainters = {
  FunStickerId.santaHat: SantaHatPainter.new,
  FunStickerId.snowflake: SnowflakePainter.new,
  FunStickerId.candyCane: CandyCanePainter.new,
  FunStickerId.christmasStar: ChristmasStarPainter.new,
};

class SantaHatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final brim = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.22),
      Radius.circular(size.height * 0.11),
    );
    canvas.drawRRect(brim, Paint()..color = Colors.white);

    final hat = Path()
      ..moveTo(size.width * 0.08, size.height * 0.58)
      ..lineTo(size.width * 0.92, size.height * 0.58)
      ..lineTo(size.width * 0.52, size.height * 0.05)
      ..close();
    canvas.drawPath(hat, Paint()..color = const Color(0xFFDC2626));

    canvas.drawCircle(
      Offset(size.width * 0.52, size.height * 0.05),
      size.width * 0.1,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SnowflakePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFBAE6FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final end =
          center + Offset(math.cos(angle), math.sin(angle)) * size.width * 0.4;
      canvas.drawLine(center, end, paint);
    }
    canvas.drawCircle(center, size.width * 0.08, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CandyCanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.55, size.height * 0.05)
      ..quadraticBezierTo(
        size.width * 0.05,
        size.height * 0.05,
        size.width * 0.05,
        size.height * 0.35,
      )
      ..lineTo(size.width * 0.25, size.height * 0.95)
      ..lineTo(size.width * 0.4, size.height * 0.95)
      ..lineTo(size.width * 0.2, size.height * 0.35)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.2,
        size.width * 0.55,
        size.height * 0.2,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = Colors.white);

    final stripe = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1;
    for (var t = 0.2; t < 0.9; t += 0.18) {
      canvas.drawLine(
        Offset(size.width * (0.15 + t * 0.15), size.height * (0.3 + t * 0.55)),
        Offset(size.width * (0.28 + t * 0.12), size.height * (0.35 + t * 0.5)),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ChristmasStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final outerAngle = -math.pi / 2 + i * 4 * math.pi / 5;
      final innerAngle = outerAngle + 2 * math.pi / 5;
      final outer =
          center +
          Offset(math.cos(outerAngle), math.sin(outerAngle)) *
              size.width *
              0.42;
      final inner =
          center +
          Offset(math.cos(innerAngle), math.sin(innerAngle)) *
              size.width *
              0.18;
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFACC15));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD97706)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.04,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
