import 'dart:math';

import 'package:flutter/material.dart';

import '../models/projection.dart';
import '../theme/app_colors.dart';
import '../l10n/l10n_extensions.dart';
import '../theme/app_theme.dart';

/// Stock-market-style fan chart: historical line + worst/expected/best projection.
class ProjectionFanChart extends StatelessWidget {
  final ProjectionResult result;
  final ProjectionChartStyle style;
  final double height;
  final String Function(double) formatValue;

  const ProjectionFanChart({
    super.key,
    required this.result,
    this.style = ProjectionChartStyle.fan,
    this.height = 250,
    this.formatValue = _defaultFormat,
  });

  static String _defaultFormat(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _FanChartPainter(
          result: result,
          style: style,
          colors: colors,
          formatValue: formatValue,
          todayLabel: context.l10n.today,
        ),
      ),
    );
  }
}

class _FanChartPainter extends CustomPainter {
  final ProjectionResult result;
  final ProjectionChartStyle style;
  final AppColors colors;
  final String Function(double) formatValue;
  final String todayLabel;

  _FanChartPainter({
    required this.result,
    required this.style,
    required this.colors,
    required this.formatValue,
    required this.todayLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hist = result.historical;
    final exp = result.expected;
    final lo = result.worst;
    final hi = result.best;
    final histN = hist.length;

    if (hist.isEmpty || exp.isEmpty) return;

    const padL = 48.0;
    const padR = 12.0;
    const padT = 14.0;
    const padB = 26.0;
    final iw = size.width - padL - padR;
    final ih = size.height - padT - padB;

    final allValues = [...hist, ...exp.skip(1), ...lo.skip(1), ...hi.skip(1)];
    var minV = allValues.reduce(min) - 150;
    var maxV = allValues.reduce(max) + 150;
    if (minV == maxV) {
      minV -= 100;
      maxV += 100;
    }
    final rng = maxV - minV;

    final totalPoints = hist.length + exp.length - 1;
    if (totalPoints < 2) return;

    double xFor(int idx) => padL + (idx / (totalPoints - 1)) * iw;
    double yFor(double v) => padT + ih - ((v - minV) / rng) * ih;

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
            fontFamily: 'Comfortaa',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL + 2, yy - tp.height - 2));
    }

    if (style == ProjectionChartStyle.fan ||
        style == ProjectionChartStyle.lines) {
      final bandPath = Path();
      for (var i = 0; i < hi.length; i++) {
        final x = xFor(histN - 1 + i);
        final y = yFor(hi[i]);
        if (i == 0) {
          bandPath.moveTo(x, y);
        } else {
          bandPath.lineTo(x, y);
        }
      }
      for (var i = lo.length - 1; i >= 0; i--) {
        bandPath.lineTo(xFor(histN - 1 + i), yFor(lo[i]));
      }
      bandPath.close();

      if (style == ProjectionChartStyle.fan) {
        canvas.drawPath(bandPath, Paint()..color = colors.confidenceBandFill);
      }
    }

    final todayX = xFor(histN - 1);
    _drawDashedLine(
      canvas,
      todayX,
      padT,
      todayX,
      padT + ih,
      colors.trackStrong,
    );

    final todayTp = TextPainter(
      text: TextSpan(
        text: todayLabel,
        style: TextStyle(
          fontSize: 9.5,
          color: colors.text3,
          fontFamily: 'Comfortaa',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    todayTp.paint(canvas, Offset(todayX + 4, padT + 2));

    _drawPolyline(canvas, hist, 0, colors.chartLine, false, xFor, yFor);

    if (style == ProjectionChartStyle.lines) {
      _drawPolyline(canvas, lo, histN - 1, colors.danger, true, xFor, yFor);
      _drawPolyline(canvas, exp, histN - 1, colors.chartLine, true, xFor, yFor);
      _drawPolyline(canvas, hi, histN - 1, colors.success, true, xFor, yFor);
    } else {
      _drawPolyline(canvas, exp, histN - 1, colors.chartLine, true, xFor, yFor);
    }

    final endIdx = totalPoints - 1;
    final endVal = exp.last;
    final endX = xFor(endIdx);
    final endY = yFor(endVal);
    canvas.drawCircle(
      Offset(endX, endY),
      4.5,
      Paint()..color = colors.chartLine,
    );

    final endLabel = formatValue(endVal);
    final endTp = TextPainter(
      text: TextSpan(
        text: endLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.text,
          fontFamily: 'Roboto Slab',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    endTp.paint(
      canvas,
      Offset(endX - endTp.width - 4, endY - endTp.height - 8),
    );
  }

  void _drawPolyline(
    Canvas canvas,
    List<double> values,
    int startIdx,
    Color color,
    bool dashed,
    double Function(int) xFor,
    double Function(double) yFor,
  ) {
    if (values.length < 2) return;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final globalIdx = startIdx + i;
      final x = xFor(globalIdx);
      final y = yFor(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (dashed) {
      _drawDashedPath(canvas, path, color, 2.5);
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 6;
        canvas.drawPath(
          metric.extractPath(distance, min(next, metric.length)),
          paint,
        );
        distance = next + 5;
      }
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    double x1,
    double y1,
    double x2,
    double y2,
    Color color,
  ) {
    final path = Path()
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);
    _drawDashedPath(canvas, path, color, 1);
  }

  @override
  bool shouldRepaint(covariant _FanChartPainter old) =>
      old.result != result || old.style != style || old.colors != colors;
}

class ProjectionChartLegend extends StatelessWidget {
  final ProjectionChartStyle style;

  const ProjectionChartLegend({super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        _LegendItem(
          color: colors.chartLine,
          label: l10n.chartLegendActual,
          dashed: false,
        ),
        _LegendItem(
          color: colors.chartLine,
          label: l10n.expected,
          dashed: true,
        ),
        if (style == ProjectionChartStyle.fan)
          _LegendItem(
            color: colors.confidenceBandFill,
            label: l10n.chartLegendWorstBest,
            isBand: true,
          ),
        if (style == ProjectionChartStyle.lines) ...[
          _LegendItem(
            color: colors.danger,
            label: l10n.chartLegendWorst,
            dashed: true,
          ),
          _LegendItem(
            color: colors.success,
            label: l10n.chartLegendBest,
            dashed: true,
          ),
        ],
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  final bool isBand;

  const _LegendItem({
    required this.color,
    required this.label,
    this.dashed = false,
    this.isBand = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBand)
          Container(
            width: 12,
            height: 11,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          )
        else if (dashed)
          SizedBox(
            width: 16,
            height: 3,
            child: CustomPaint(painter: _DashedLinePainter(color: color)),
          )
        else
          Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.text2),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(min(x + 6, size.width), size.height / 2),
        paint,
      );
      x += 9;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ProjectionScenarioCards extends StatelessWidget {
  final ProjectionResult result;
  final String currency;

  const ProjectionScenarioCards({
    super.key,
    required this.result,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = context.format;
    return Row(
      children: [
        Expanded(
          child: _ScenarioCard(
            label: l10n.worstCase,
            value: format.formatMoney(result.endWorst, currency),
            color: colors.danger,
            bg: colors.dangerSoft,
            icon: Icons.trending_down,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ScenarioCard(
            label: l10n.expected,
            value: format.formatMoney(result.endExpected, currency),
            color: colors.chartLine,
            bg: colors.iconBg,
            icon: Icons.show_chart,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ScenarioCard(
            label: l10n.bestCase,
            value: format.formatMoney(result.endBest, currency),
            color: colors.success,
            bg: colors.successSoft,
            icon: Icons.trending_up,
          ),
        ),
      ],
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final IconData icon;

  const _ScenarioCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.colors.text2),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Roboto Slab',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
