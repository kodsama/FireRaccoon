import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// What a chart says about the one thing under the pointer.
class StatsHover {
  /// Where the pointer is, in the chart's own coordinates.
  final Offset at;
  final Color color;
  final String title;
  final List<String> lines;

  /// What the card must not cover, such as the bars of the month hovered;
  /// the card then sits clear of it on one side.
  final Rect? beside;

  const StatsHover({
    required this.at,
    required this.color,
    required this.title,
    required this.lines,
    this.beside,
  });
}

/// A card beside the pointer naming what it is over, bordered in that
/// part's colour and flipped to the other side near an edge of [area].
class StatsHoverCard extends StatelessWidget {
  final StatsHover hover;
  final Size area;

  static const width = 240.0;

  const StatsHoverCard({super.key, required this.hover, required this.area});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final at = hover.at;
    final beside = hover.beside;
    // Clear of what it describes when told what that is, to the right if
    // it fits there and to the left if not; else just off the pointer.
    final double left;
    if (beside != null) {
      left = beside.right + 12 + width <= area.width
          ? beside.right + 12
          : beside.left - 12 - width;
    } else {
      left = at.dx + 16 + width > area.width ? at.dx - 16 - width : at.dx + 16;
    }
    final top = (at.dy - 30).clamp(0.0, area.height - 72);
    return Positioned(
      left: left.clamp(0.0, area.width - width),
      top: top,
      width: width,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: hover.color, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hover.title,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final line in hover.lines) ...[
                const SizedBox(height: 2),
                Text(line, style: TextStyle(color: colors.text2)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Holds what a chart's pointer is over and lays the card on top of the
/// chart [builder] draws, handing it the setter to call from its touch
/// callbacks.
class StatsHoverHost extends StatefulWidget {
  final Widget Function(BuildContext context, ValueChanged<StatsHover?> onHover)
  builder;

  const StatsHoverHost({super.key, required this.builder});

  @override
  State<StatsHoverHost> createState() => _StatsHoverHostState();
}

class _StatsHoverHostState extends State<StatsHoverHost> {
  StatsHover? _hover;

  void _set(StatsHover? hover) {
    if (!mounted) return;
    setState(() => _hover = hover);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: widget.builder(context, _set)),
          if (_hover case final hover?)
            StatsHoverCard(hover: hover, area: constraints.biggest),
        ],
      ),
    );
  }
}
