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

        if (width > constraints.maxWidth + 0.5) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: table,
          );
        }
        return table;
      },
    );
  }
}
