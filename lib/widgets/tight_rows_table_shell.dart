import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Horizontal padding applied by tight-row headers and data rows.
const double tightRowsHorizontalPadding = 16.0;

/// Wraps a tight-rows header and its data rows so they share one width and,
/// when needed, one horizontal scroll viewport.
///
/// Independent per-row horizontal scroll views desync: the header can pan
/// while the body stays put. This shell sizes to at least [minContentWidth]
/// (column widths + action column + horizontal padding) and scrolls as a unit.
class TightRowsTableShell extends StatelessWidget {
  /// Minimum width of the table content, including the 16px padding on each
  /// side used by header/row widgets.
  final double minContentWidth;
  final Widget header;
  final List<Widget> rows;

  const TightRowsTableShell({
    super.key,
    required this.minContentWidth,
    required this.header,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, minContentWidth);
        final table = SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(color: dividerColor, height: 1),
                rows[i],
              ],
            ],
          ),
        );

        // Published so content inside a row can hold itself to the window
        // instead of the table; see [FitToTightRowsViewport].
        final published = TightRowsViewport(
          width: constraints.maxWidth,
          child: table,
        );
        if (width > constraints.maxWidth + 0.5) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: published,
          );
        }
        return published;
      },
    );
  }
}

/// The width of the shell's own viewport, which is not the width of the table
/// when the table is the wider of the two.
class TightRowsViewport extends InheritedWidget {
  const TightRowsViewport({
    super.key,
    required this.width,
    required super.child,
  });

  final double width;

  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TightRowsViewport>()?.width;

  @override
  bool updateShouldNotify(TightRowsViewport oldWidget) =>
      oldWidget.width != width;
}

/// Holds [child] to the shell's viewport when the table around it is wider.
///
/// A tight-rows table is as wide as its columns need and pans when the window
/// is narrower. A form opened inside a row has no columns to line up with, so
/// laying it out at the table's width pushed half of every field past the
/// right edge, where it read as a panel that would not resize with the window.
class FitToTightRowsViewport extends StatelessWidget {
  const FitToTightRowsViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final viewport = TightRowsViewport.maybeOf(context);
    if (viewport == null) return child;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(width: viewport, child: child),
    );
  }
}
