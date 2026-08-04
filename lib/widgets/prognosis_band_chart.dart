import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/account_prognosis.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class PrognosisBandChart extends StatelessWidget {
  final List<PrognosisBalancePoint> timeline;
  final double height;
  final String Function(double) formatValue;
  final DateTime? markerEndOfMonth;
  final DateTime? markerEndOfNextMonth;
  final DateTime? horizonEnd;

  const PrognosisBandChart({
    super.key,
    required this.timeline,
    this.height = 260,
    required this.formatValue,
    this.markerEndOfMonth,
    this.markerEndOfNextMonth,
    this.horizonEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (timeline.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('—', style: TextStyle(color: colors.text3)),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _PrognosisBandPainter(
          timeline: timeline,
          colors: colors,
          formatValue: formatValue,
          markerEndOfMonth: markerEndOfMonth,
          markerEndOfNextMonth: markerEndOfNextMonth,
          horizonEnd: horizonEnd,
        ),
      ),
    );
  }
}

@visibleForTesting
({double min, double max}) computePrognosisChartBounds(
  List<PrognosisBalancePoint> timeline,
) {
  final allValues = <double>[
    for (final point in timeline) ...[
      point.expected,
      point.pessimistic,
      point.optimistic,
    ],
  ];
  var minV = allValues.reduce(min);
  var maxV = allValues.reduce(max);
  final span = maxV - minV;
  final pad = span > 0
      ? span * 0.12
      : max(max(maxV.abs(), minV.abs()) * 0.1, 100);
  minV -= pad;
  maxV += pad;

  // Keep 0 visible only when it's near the projected value range;
  // forcing it for high-balance accounts flattens meaningful variation.
  final nearZeroWindow = max(maxV.abs(), minV.abs()) * 0.2;
  final zeroNearby =
      minV.abs() <= nearZeroWindow || maxV.abs() <= nearZeroWindow;
  if (zeroNearby) {
    minV = min(minV, 0);
    maxV = max(maxV, 0);
  }

  return (min: minV, max: maxV);
}

class _PrognosisBandPainter extends CustomPainter {
  final List<PrognosisBalancePoint> timeline;
  final AppColors colors;
  final String Function(double) formatValue;
  final DateTime? markerEndOfMonth;
  final DateTime? markerEndOfNextMonth;
  final DateTime? horizonEnd;

  _PrognosisBandPainter({
    required this.timeline,
    required this.colors,
    required this.formatValue,
    this.markerEndOfMonth,
    this.markerEndOfNextMonth,
    this.horizonEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 56.0;
    const padR = 12.0;
    const padT = 14.0;
    const padB = 30.0;
    final iw = size.width - padL - padR;
    final ih = size.height - padT - padB;

    final bounds = computePrognosisChartBounds(timeline);
    final minV = bounds.min;
    final maxV = bounds.max;
    final rng = maxV - minV;
    final n = timeline.length;
    if (n < 2 || rng <= 0) return;

    double xFor(int index) => padL + (index / (n - 1)) * iw;
    double yFor(double value) => padT + ih - ((value - minV) / rng) * ih;

    for (var g = 0; g <= 3; g++) {
      final yy = padT + (ih / 3) * g;
      canvas.drawLine(
        Offset(padL, yy),
        Offset(size.width - padR, yy),
        Paint()..color = colors.divider,
      );
      final label = formatValue(maxV - (rng / 3) * g);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 9.5,
            color: colors.text3,
            fontFamily: AppTypography.bodyFont,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: padL - 6);
      tp.paint(canvas, Offset(padL - tp.width - 4, yy - tp.height / 2));
    }

    if (minV < 0 && maxV > 0) {
      final zeroY = yFor(0);
      canvas.drawLine(
        Offset(padL, zeroY),
        Offset(size.width - padR, zeroY),
        Paint()
          ..color = colors.danger.withValues(alpha: 0.45)
          ..strokeWidth = 1.2,
      );
    }

    final bandPath = Path();
    for (var i = 0; i < n; i++) {
      final x = xFor(i);
      final y = yFor(timeline[i].pessimistic);
      if (i == 0) {
        bandPath.moveTo(x, y);
      } else {
        bandPath.lineTo(x, y);
      }
    }
    for (var i = n - 1; i >= 0; i--) {
      bandPath.lineTo(xFor(i), yFor(timeline[i].optimistic));
    }
    bandPath.close();
    canvas.drawPath(
      bandPath,
      Paint()..color = colors.accent.acc.withValues(alpha: 0.18),
    );

    final expectedPaint = Paint()
      ..color = colors.accent.acc
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final expectedPath = Path();
    for (var i = 0; i < n; i++) {
      final x = xFor(i);
      final y = yFor(timeline[i].expected);
      if (i == 0) {
        expectedPath.moveTo(x, y);
      } else {
        expectedPath.lineTo(x, y);
      }
    }
    canvas.drawPath(expectedPath, expectedPaint);

    final startX = xFor(0);
    final startY = yFor(timeline.first.expected);
    canvas.drawCircle(
      Offset(startX, startY),
      4,
      Paint()..color = colors.accent.acc,
    );

    final endX = xFor(n - 1);
    final endY = yFor(timeline.last.expected);
    canvas.drawCircle(
      Offset(endX, endY),
      4,
      Paint()..color = colors.accent.acc,
    );

    final endLabel = formatValue(timeline.last.expected);
    final endTp = TextPainter(
      text: TextSpan(
        text: endLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.text,
          fontFamily: AppTypography.figureFont,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelX = endX - endTp.width - 6;
    final labelY = endY - endTp.height - 8;
    endTp.paint(
      canvas,
      Offset(
        labelX.clamp(padL, size.width - padR - endTp.width),
        labelY.clamp(padT, padT + ih - endTp.height),
      ),
    );

    void drawXLabel(int index, String label) {
      final x = xFor(index);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 9,
            color: colors.text3,
            fontFamily: AppTypography.bodyFont,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          (x - tp.width / 2).clamp(padL, size.width - padR - tp.width),
          padT + ih + 6,
        ),
      );
    }

    final dateFormat = DateFormat.MMMd();
    drawXLabel(0, dateFormat.format(timeline.first.date));
    drawXLabel(n - 1, dateFormat.format(timeline.last.date));

    final markerSpecs = <({DateTime? marker, Color color, String label})>[
      (marker: markerEndOfMonth, color: colors.warning, label: 'EOM'),
      (marker: markerEndOfNextMonth, color: colors.text3, label: 'EOM+1'),
      (marker: horizonEnd, color: colors.accent.acc, label: 'END'),
    ];
    final markersByIndex = <int, ({Color color, List<String> labels})>{};
    for (final spec in markerSpecs) {
      final marker = spec.marker;
      if (marker == null) continue;
      final index = _indexOnOrBefore(marker);
      final existing = markersByIndex[index];
      if (existing == null) {
        markersByIndex[index] = (color: spec.color, labels: [spec.label]);
      } else if (!existing.labels.contains(spec.label)) {
        existing.labels.add(spec.label);
      }
    }

    for (final entry in markersByIndex.entries) {
      final index = entry.key;
      final marker = entry.value;
      final x = xFor(index);
      canvas.drawLine(
        Offset(x, padT),
        Offset(x, padT + ih),
        Paint()
          ..color = marker.color.withValues(alpha: 0.55)
          ..strokeWidth = 1.2,
      );
      final markerLabel = marker.labels.join(' · ');
      final tp = TextPainter(
        text: TextSpan(
          text: markerLabel,
          style: TextStyle(
            fontSize: 9,
            color: marker.color,
            fontFamily: AppTypography.bodyFont,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          (x - tp.width / 2).clamp(padL, size.width - padR - tp.width),
          padT + 2,
        ),
      );
    }
  }

  int _indexOnOrBefore(DateTime marker) {
    final target = DateTime(marker.year, marker.month, marker.day);
    var bestIndex = 0;
    for (var i = 0; i < timeline.length; i++) {
      final pointDay = DateTime(
        timeline[i].date.year,
        timeline[i].date.month,
        timeline[i].date.day,
      );
      if (pointDay.isAfter(target)) break;
      bestIndex = i;
    }
    return bestIndex;
  }

  @override
  bool shouldRepaint(covariant _PrognosisBandPainter oldDelegate) {
    return oldDelegate.timeline != timeline ||
        oldDelegate.horizonEnd != horizonEnd ||
        oldDelegate.markerEndOfMonth != markerEndOfMonth ||
        oldDelegate.markerEndOfNextMonth != markerEndOfNextMonth;
  }
}
