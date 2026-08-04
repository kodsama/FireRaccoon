import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A drag handle widget placed on the right edge of each column header.
/// Shows a visible bar that brightens on hover; dragging horizontally
/// resizes the column.
class ResizeHandle extends StatefulWidget {
  final void Function(double dx) onDrag;
  const ResizeHandle({super.key, required this.onDrag});

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 3,
            height: _hovering ? 28 : 16,
            decoration: BoxDecoration(
              color: _hovering ? colors.text2 : colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
