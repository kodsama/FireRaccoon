import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'stats_hover_card.dart';

/// One slice of a [StatsDonut] ring.
class DonutSlice {
  final String label;
  final double value;
  final Color color;

  /// The slice's amount as the page formats money, shown on hover.
  final String amount;
  final VoidCallback? onTap;

  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
    required this.amount,
    this.onTap,
  });
}

/// A donut with its parts named: each outer slice outside on a leader line
/// with its share, each inner slice by name inside it, and the part under
/// the pointer in full with its share and amount. An [inner] ring, when
/// given, sits inside the outer one and must run in the same order, so each
/// inner slice spans the outer slices that belong to it: types inside,
/// their categories around them.
class StatsDonut extends StatefulWidget {
  final List<DonutSlice> outer;
  final List<DonutSlice> inner;
  final double height;

  /// Writes a share, given in percent, the way the user's locale does.
  final String Function(double percent) formatPercent;

  const StatsDonut({
    super.key,
    required this.outer,
    required this.formatPercent,
    this.inner = const [],
    this.height = 360,
  });

  @override
  State<StatsDonut> createState() => _StatsDonutState();
}

class _StatsDonutState extends State<StatsDonut> {
  (bool, int)? _hovered;
  Offset _pointer = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, widget.height);
        final geometry = DonutGeometry(size, hasInner: widget.inner.isNotEmpty);
        (bool, int)? hitAt(Offset position) =>
            geometry.hit(position, outer: widget.outer, inner: widget.inner);
        return MouseRegion(
          onHover: (event) {
            final found = hitAt(event.localPosition);
            setState(() {
              _hovered = found;
              _pointer = event.localPosition;
            });
          },
          onExit: (_) => setState(() => _hovered = null),
          cursor: _hovered == null
              ? MouseCursor.defer
              : SystemMouseCursors.click,
          child: GestureDetector(
            onTapUp: (details) {
              final found = hitAt(details.localPosition);
              if (found == null) return;
              final slices = found.$1 ? widget.inner : widget.outer;
              slices[found.$2].onTap?.call();
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: size,
                  painter: _DonutPainter(
                    geometry: geometry,
                    outer: widget.outer,
                    inner: widget.inner,
                    hovered: _hovered,
                    gapColor: colors.surface,
                    lineColor: colors.text3,
                    textColor: colors.text,
                    mutedColor: colors.text3,
                    formatPercent: widget.formatPercent,
                  ),
                ),
                if (_hovered case final hovered?)
                  _hoverCard(context, size, hovered),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension on _StatsDonutState {
  /// The part under the pointer written out in full, since the name beside
  /// the ring is cut short and slivers have none: its name, its share of
  /// its ring and its amount.
  Widget _hoverCard(BuildContext context, Size size, (bool, int) hovered) {
    final slices = hovered.$1 ? widget.inner : widget.outer;
    final slice = slices[hovered.$2];
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    final share = total > 0 ? slice.value / total * 100 : 0.0;
    return StatsHoverCard(
      area: size,
      hover: StatsHover(
        at: _pointer,
        color: slice.color,
        title: slice.label,
        lines: ['${widget.formatPercent(share)} · ${slice.amount}'],
      ),
    );
  }
}

/// Where the rings sit, shared by painting and hit testing.
class DonutGeometry {
  final Size size;
  final bool hasInner;

  DonutGeometry(this.size, {required this.hasInner});

  /// The least room kept each side of the ring for the names outside;
  /// wider canvases give them the rest.
  static const labelRoom = 150.0;

  Offset get center => Offset(size.width / 2, size.height / 2);

  double get radius =>
      math.max(40, math.min(size.height / 2 - 24, size.width / 2 - labelRoom));

  (double, double) get outerRing =>
      hasInner ? (radius * 0.68, radius) : (radius * 0.58, radius);

  (double, double) get innerRing => (radius * 0.36, radius * 0.66);

  /// Start and sweep of each slice, clockwise from twelve o'clock.
  static List<(double, double)> arcs(List<DonutSlice> slices) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return const [];
    final arcs = <(double, double)>[];
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = slice.value / total * 2 * math.pi;
      arcs.add((start, sweep));
      start += sweep;
    }
    return arcs;
  }

  /// The ring (true for inner) and slice under [position], if any.
  (bool, int)? hit(
    Offset position, {
    required List<DonutSlice> outer,
    required List<DonutSlice> inner,
  }) {
    final delta = position - center;
    final distance = delta.distance;
    final (outerFrom, outerTo) = outerRing;
    final (innerFrom, innerTo) = innerRing;
    final List<DonutSlice> slices;
    final bool isInner;
    if (distance >= outerFrom && distance <= outerTo + 6) {
      slices = outer;
      isInner = false;
    } else if (hasInner && distance >= innerFrom && distance <= innerTo) {
      slices = inner;
      isInner = true;
    } else {
      return null;
    }
    var angle = math.atan2(delta.dy, delta.dx);
    if (angle < -math.pi / 2) angle += 2 * math.pi;
    final list = arcs(slices);
    for (var i = 0; i < list.length; i++) {
      final (start, sweep) = list[i];
      if (angle >= start && angle < start + sweep) return (isInner, i);
    }
    return null;
  }
}

class _DonutPainter extends CustomPainter {
  final DonutGeometry geometry;
  final List<DonutSlice> outer;
  final List<DonutSlice> inner;
  final (bool, int)? hovered;
  final Color gapColor;
  final Color lineColor;
  final Color textColor;
  final Color mutedColor;
  final String Function(double percent) formatPercent;

  _DonutPainter({
    required this.geometry,
    required this.outer,
    required this.inner,
    required this.hovered,
    required this.gapColor,
    required this.lineColor,
    required this.textColor,
    required this.mutedColor,
    required this.formatPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _ring(canvas, outer, geometry.outerRing, isInner: false);
    if (inner.isNotEmpty) {
      _ring(canvas, inner, geometry.innerRing, isInner: true);
    }
    _outsideLabels(canvas, size);
  }

  void _ring(
    Canvas canvas,
    List<DonutSlice> slices,
    (double, double) ring, {
    required bool isInner,
  }) {
    final (from, to) = ring;
    final arcs = DonutGeometry.arcs(slices);
    final center = geometry.center;
    for (var i = 0; i < arcs.length; i++) {
      final (start, sweep) = arcs[i];
      final lifted = hovered == (isInner, i);
      final outerRadius = lifted ? to + 6 : to;
      final path = Path()
        ..arcTo(
          Rect.fromCircle(center: center, radius: outerRadius),
          start,
          sweep,
          true,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: from),
          start + sweep,
          -sweep,
          false,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = slices[i].color);
      // A thin gap between slices, in the card colour, keeps shades of one
      // hue apart.
      if (arcs.length > 1) {
        canvas.drawPath(
          path,
          Paint()
            ..color = gapColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      // Only the inner ring is written on: its slices are the types, few
      // and wide. The outer parts are named outside the ring instead.
      if (!isInner) continue;
      final painter = _text(
        slices[i].label,
        TextStyle(
          color: _onColor(slices[i].color),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
      final radius = (from + to) / 2;
      // Level text fits a ring best where the ring runs across it, so the
      // label goes to the spot nearest the slice's middle where it fits.
      var placed = false;
      for (final at in _spotsNearMiddle(start, sweep)) {
        final box = Rect.fromCenter(
          center: center + Offset(math.cos(at), math.sin(at)) * radius,
          width: painter.width + 6,
          height: painter.height + 2,
        );
        if (_insideSlice(box, center, from, to, start, sweep)) {
          painter.paint(
            canvas,
            box.center - Offset(painter.width / 2, painter.height / 2),
          );
          placed = true;
          break;
        }
      }
      // Where no level spot fits, the name runs along the ring at the
      // slice's middle instead, turned to read upright on either half.
      final middle = start + sweep / 2;
      if (!placed &&
          sweep * radius > painter.width + 8 &&
          to - from > painter.height + 4) {
        final at = center + Offset(math.cos(middle), math.sin(middle)) * radius;
        final lowerHalf = math.sin(middle) > 0;
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..rotate(lowerHalf ? middle - math.pi / 2 : middle + math.pi / 2);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        canvas.restore();
      }
    }
  }

  /// Angles across a slice, its middle first and then outwards either side.
  static Iterable<double> _spotsNearMiddle(double start, double sweep) sync* {
    const steps = 12;
    final middle = start + sweep / 2;
    yield middle;
    for (var i = 1; i <= steps; i++) {
      final offset = sweep / 2 * i / (steps + 1);
      yield middle - offset;
      yield middle + offset;
    }
  }

  static bool _insideSlice(
    Rect box,
    Offset center,
    double from,
    double to,
    double start,
    double sweep,
  ) {
    for (final corner in [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ]) {
      final delta = corner - center;
      final distance = delta.distance;
      if (distance < from || distance > to) return false;
      var angle = math.atan2(delta.dy, delta.dx);
      if (angle < start) angle += 2 * math.pi;
      if (angle > start + sweep) return false;
    }
    return true;
  }

  void _outsideLabels(Canvas canvas, Size size) {
    final arcs = DonutGeometry.arcs(outer);
    final total = outer.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;
    final (_, to) = geometry.outerRing;
    final center = geometry.center;
    final labels = <_Label>[];
    for (var i = 0; i < arcs.length; i++) {
      final share = outer[i].value / total;
      // Slivers go unnamed; they would only crowd the ones that matter.
      if (share < 0.02) continue;
      final (start, sweep) = arcs[i];
      final middle = start + sweep / 2;
      final direction = Offset(math.cos(middle), math.sin(middle));
      labels.add(
        _Label(
          index: i,
          anchor: center + direction * (to + 2),
          elbow: center + direction * (to + 16),
          right: direction.dx >= 0,
          share: share,
        ),
      );
    }
    for (final right in [true, false]) {
      final side = labels.where((l) => l.right == right).toList()
        ..sort((a, b) => a.elbow.dy.compareTo(b.elbow.dy));
      // Push crowded names apart downwards, then back up inside the canvas.
      const gap = 30.0;
      for (var i = 0; i < side.length; i++) {
        side[i].y = side[i].elbow.dy.clamp(14.0, size.height - 14);
        if (i > 0 && side[i].y - side[i - 1].y < gap) {
          side[i].y = side[i - 1].y + gap;
        }
      }
      for (var i = side.length - 1; i >= 0; i--) {
        final limit = i == side.length - 1
            ? size.height - 14
            : side[i + 1].y - gap;
        if (side[i].y > limit) side[i].y = limit;
      }
      for (final label in side) {
        _drawLabel(canvas, size, label);
      }
    }
  }

  void _drawLabel(Canvas canvas, Size size, _Label label) {
    final slice = outer[label.index];
    final (_, to) = geometry.outerRing;
    final center = geometry.center;
    final endX = label.right ? center.dx + to + 30 : center.dx - to - 30;
    final elbow = Offset(label.elbow.dx, label.y);
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    canvas.drawLine(label.anchor, elbow, line);
    canvas.drawLine(elbow, Offset(endX, label.y), line);
    canvas.drawCircle(Offset(endX, label.y), 2.5, Paint()..color = slice.color);

    // A name may run to the canvas edge on its side, less a small margin.
    final maxWidth = math.max(
      60.0,
      label.right ? size.width - endX - 10 : endX - 10,
    );
    final name = _text(
      slice.label,
      TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
      maxWidth: maxWidth,
    );
    final share = _text(
      formatPercent(label.share * 100),
      TextStyle(color: mutedColor, fontSize: 11),
    );
    final x = label.right ? endX + 6 : endX - 6;
    name.paint(
      canvas,
      Offset(label.right ? x : x - name.width, label.y - name.height),
    );
    share.paint(canvas, Offset(label.right ? x : x - share.width, label.y));
  }

  static TextPainter _text(
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
  }) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);

  static Color _onColor(Color fill) =>
      fill.computeLuminance() > 0.45 ? const Color(0xFF1B1B1B) : Colors.white;

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.outer != outer || old.inner != inner || old.hovered != hovered;
}

class _Label {
  final int index;
  final Offset anchor;
  final Offset elbow;
  final bool right;
  final double share;
  double y = 0;

  _Label({
    required this.index,
    required this.anchor,
    required this.elbow,
    required this.right,
    required this.share,
  });
}
