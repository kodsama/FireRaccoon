import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../theme/app_theme.dart';

/// Expand/collapse body that only builds [child] while expanded or animating,
/// unlike AnimatedCrossFade which builds and lays out both states on every
/// frame. The child stays mounted during the collapse animation and is
/// dropped once fully closed.
class _ExpandableBody extends StatefulWidget {
  final bool expanded;
  final Widget child;

  const _ExpandableBody({required this.expanded, required this.child});

  @override
  State<_ExpandableBody> createState() => _ExpandableBodyState();
}

class _ExpandableBodyState extends State<_ExpandableBody> {
  late bool _childMounted = widget.expanded;

  @override
  void didUpdateWidget(covariant _ExpandableBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded) _childMounted = true;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.expanded ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      onEnd: () {
        if (!widget.expanded && _childMounted) {
          setState(() => _childMounted = false);
        }
      },
      child: _childMounted
          ? SizedBox(width: double.infinity, child: widget.child)
          : null,
      builder: (context, factor, child) {
        if (child == null || factor == 0.0) {
          return const SizedBox(width: double.infinity);
        }
        if (factor == 1.0) return child;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: factor,
            child: child,
          ),
        );
      },
    );
  }
}

/// Animated chevron indicating expand/collapse state.
class ExpandChevron extends StatelessWidget {
  final bool expanded;
  final double size;

  const ExpandChevron({super.key, required this.expanded, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedRotation(
      turns: expanded ? 0.5 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: Icon(LucideIcons.chevronDown, size: size, color: colors.text3),
    );
  }
}

/// Standard grid card shell: bordered surface, tap-to-expand header, cross-fade body.
class ExpandableEntityCard extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggleExpand;
  final Widget header;
  final Widget expandedChild;
  final double width;

  /// When set, tapping the header uses this instead of [onToggleExpand].
  final VoidCallback? onHeaderTap;

  const ExpandableEntityCard({
    super.key,
    required this.expanded,
    required this.onToggleExpand,
    required this.header,
    required this.expandedChild,
    this.width = 380,
    this.onHeaderTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final tap = onHeaderTap ?? onToggleExpand;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expanded
              ? colors.accent.acc.withValues(alpha: 0.5)
              : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: onHeaderTap != null
                ? l10n.tooltipBalanceCheckIncludePending
                : (expanded
                      ? l10n.tooltipCollapseDetails
                      : l10n.tooltipExpandDetails),
            child: InkWell(
              onTap: tap,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(expanded ? 0 : 16),
                bottomRight: Radius.circular(expanded ? 0 : 16),
              ),
              child: header,
            ),
          ),
          _ExpandableBody(expanded: expanded, child: expandedChild),
        ],
      ),
    );
  }
}

/// Standard compact list row shell with tap-to-expand and cross-fade body.
class ExpandableEntityCompactRow extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggleExpand;
  final Widget header;
  final Widget expandedChild;

  /// When set, tapping the row body uses this instead of [onToggleExpand]
  /// (expand stays available via an explicit control in the header).
  final VoidCallback? onHeaderTap;

  const ExpandableEntityCompactRow({
    super.key,
    required this.expanded,
    required this.onToggleExpand,
    required this.header,
    required this.expandedChild,
    this.onHeaderTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tap = onHeaderTap ?? onToggleExpand;
    return Column(
      children: [
        Tooltip(
          message: onHeaderTap != null
              ? l10n.tooltipBalanceCheckIncludePending
              : (expanded
                    ? l10n.tooltipCollapseDetails
                    : l10n.tooltipExpandDetails),
          child: InkWell(onTap: tap, child: header),
        ),
        _ExpandableBody(expanded: expanded, child: expandedChild),
      ],
    );
  }
}
