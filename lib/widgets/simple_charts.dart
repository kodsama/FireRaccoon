import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dart:math';

class GroupedBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> incomeValues;
  final List<double> spendingValues;
  final Color incomeColor;
  final Color spendingColor;
  final double height;
  final int? highlightedGroupIndex;
  final ValueChanged<int?>? onGroupHover;

  const GroupedBarChart({
    super.key,
    required this.labels,
    required this.incomeValues,
    required this.spendingValues,
    required this.incomeColor,
    required this.spendingColor,
    this.height = 190,
    this.highlightedGroupIndex,
    this.onGroupHover,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return SizedBox(height: height);

    const labelAreaHeight = 24.0;
    final barAreaHeight = height - labelAreaHeight;
    final maxVal = [
      ...incomeValues,
      ...spendingValues,
    ].fold(0.0, (current, value) => max(current, value));

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(labels.length, (index) {
          final income = index < incomeValues.length
              ? incomeValues[index]
              : 0.0;
          final spending = index < spendingValues.length
              ? spendingValues[index]
              : 0.0;
          final incomeHeight = maxVal == 0
              ? 0.0
              : (income / maxVal) * barAreaHeight;
          final spendingHeight = maxVal == 0
              ? 0.0
              : (spending / maxVal) * barAreaHeight;
          final isHighlighted =
              highlightedGroupIndex == null || highlightedGroupIndex == index;
          final barOpacity = isHighlighted ? 1.0 : 0.35;

          return Expanded(
            child: MouseRegion(
              onEnter: (_) => onGroupHover?.call(index),
              onExit: (_) => onGroupHover?.call(null),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: barAreaHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Container(
                              height: incomeHeight,
                              margin: const EdgeInsets.only(right: 2),
                              decoration: BoxDecoration(
                                color: incomeColor.withValues(
                                  alpha: barOpacity,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: spendingHeight,
                              margin: const EdgeInsets.only(left: 2),
                              decoration: BoxDecoration(
                                color: spendingColor.withValues(
                                  alpha: barOpacity,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontSize: 10,
                        color: context.colors.text3.withValues(
                          alpha: isHighlighted ? 1 : 0.45,
                        ),
                        fontWeight: isHighlighted
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SimpleBarChart extends StatelessWidget {
  final List<double> values;
  final double height;

  const SimpleBarChart({super.key, required this.values, this.height = 190});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (values.isEmpty) return SizedBox(height: height);

    final maxVal = values.reduce(max);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: values.map((val) {
          final p = maxVal == 0 ? 0.0 : val / maxVal;
          return Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Container(
                height: height * p,
                decoration: BoxDecoration(
                  color: colors.accent.acc,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SimpleDonutChart extends StatefulWidget {
  final List<double> values;
  final List<Color> sliceColors;
  final double size;
  final int? highlightedIndex;
  final ValueChanged<int?>? onSliceHover;

  const SimpleDonutChart({
    super.key,
    required this.values,
    required this.sliceColors,
    this.size = 190,
    this.highlightedIndex,
    this.onSliceHover,
  });

  @override
  State<SimpleDonutChart> createState() => _SimpleDonutChartState();
}

class _SimpleDonutChartState extends State<SimpleDonutChart> {
  int? _sliceAtOffset(Offset localOffset, Size size) {
    if (widget.values.isEmpty) return null;
    final total = widget.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return null;

    final center = Offset(size.width / 2, size.height / 2);
    final dx = localOffset.dx - center.dx;
    final dy = localOffset.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);
    final radius = min(size.width / 2, size.height / 2);
    final inner = radius * 0.6;
    if (distance < inner || distance > radius) return null;

    final normalized = (atan2(dy, dx) + (pi / 2) + (2 * pi)) % (2 * pi);
    var accumulated = 0.0;
    for (var i = 0; i < widget.values.length; i++) {
      final sweep = (widget.values[i] / total) * 2 * pi;
      accumulated += sweep;
      if (normalized <= accumulated) return i;
    }
    return widget.values.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onExit: (_) => widget.onSliceHover?.call(null),
      onHover: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(event.position);
        widget.onSliceHover?.call(_sliceAtOffset(local, box.size));
      },
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _DonutChartPainter(
              values: widget.values,
              colors: widget.sliceColors,
              highlightedIndex: widget.highlightedIndex,
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final int? highlightedIndex;

  _DonutChartPainter({
    required this.values,
    required this.colors,
    this.highlightedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final total = values.reduce((a, b) => a + b);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final strokeWidth = radius * 0.4;
    final innerRadius = radius - strokeWidth / 2;

    double startAngle = -pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * pi;
      final isHighlighted = highlightedIndex == null || highlightedIndex == i;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(
          alpha: isHighlighted ? 1 : 0.32,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlightedIndex == i ? strokeWidth + 3 : strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        sweepAngle - 0.05, // small gap
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return highlightedIndex != oldDelegate.highlightedIndex ||
        !listEquals(values, oldDelegate.values) ||
        !listEquals(colors, oldDelegate.colors);
  }
}

class SimpleSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  final double width;

  const SimpleSparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 40,
    this.width = 100,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _SparklinePainter(values: values, color: color),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxVal = values.reduce(max);
    final minVal = values.reduce(min);
    final range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    final path = Path();
    final stepX = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - ((values[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return color != oldDelegate.color ||
        !listEquals(values, oldDelegate.values);
  }
}
