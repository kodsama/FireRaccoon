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
class TightRowsTableShell extends StatefulWidget {
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
  State<TightRowsTableShell> createState() => _TightRowsTableShellState();
}

class _TightRowsTableShellState extends State<TightRowsTableShell> {
  final _pan = ScrollController();

  @override
  void dispose() {
    _pan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, widget.minContentWidth);
        final table = SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.header,
              for (var i = 0; i < widget.rows.length; i++) ...[
                if (i > 0) Divider(color: dividerColor, height: 1),
                widget.rows[i],
              ],
            ],
          ),
        );

        // Published so content inside a row can hold itself to the window
        // instead of the table; see [FitToTightRowsViewport].
        final scrolls = width > constraints.maxWidth + 0.5;
        final published = TightRowsViewport(
          width: constraints.maxWidth,
          pan: scrolls ? _pan : null,
          child: table,
        );
        if (scrolls) {
          return SingleChildScrollView(
            controller: _pan,
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
    required this.pan,
    required super.child,
  });

  final double width;

  /// The table's own sideways scroll, or null when it fits and has none.
  final ScrollController? pan;

  static TightRowsViewport? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TightRowsViewport>();

  @override
  bool updateShouldNotify(TightRowsViewport oldWidget) =>
      oldWidget.width != width || oldWidget.pan != pan;
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
    final fitted = Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(width: viewport.width, child: child),
    );

    final pan = viewport.pan;
    if (pan == null) return fitted;
    // Panning the table moves the columns under the form rather than carrying
    // the form off with them. Sized to the window and then put back where the
    // window is, since that is the only place all of it fits.
    return AnimatedBuilder(
      animation: pan,
      builder: (context, child) => Transform.translate(
        offset: Offset(pan.hasClients ? pan.offset : 0, 0),
        child: child,
      ),
      child: fitted,
    );
  }
}
