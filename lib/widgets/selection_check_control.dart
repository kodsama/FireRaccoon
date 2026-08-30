import 'package:flutter/material.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/balance_check_selection.dart';

class SelectionCheckColors {
  const SelectionCheckColors({
    required this.selected,
    required this.partial,
    required this.unselected,
    required this.disabled,
  });

  final Color selected;
  final Color partial;
  final Color unselected;
  final Color disabled;

  factory SelectionCheckColors.selection(AppColors colors) {
    final selectionColor =
        (colors.accent == AppAccent.green || colors.accent == AppAccent.teal)
        ? AppAccent.blue.acc
        : colors.accent.acc;
    return SelectionCheckColors(
      selected: selectionColor,
      partial: selectionColor,
      unselected: colors.text3,
      disabled: colors.text3.withValues(alpha: 0.4),
    );
  }

  factory SelectionCheckColors.reconciled(AppColors colors) {
    return SelectionCheckColors(
      selected: colors.success,
      partial: colors.warning,
      unselected: colors.text3,
      disabled: colors.text3.withValues(alpha: 0.4),
    );
  }
}

/// Palette for a transaction's reconcile checkmark.
///
/// In balance-check mode:
/// - green check = already reconciled and still included
/// - muted green minus = was reconciled, excluded (pending un-reconcile)
/// - accent check = not reconciled yet, selected to reconcile
/// - empty circle = not selected
SelectionCheckColors balanceCheckTogglePalette(
  AppColors colors, {
  required BalanceCheckVisual visual,
}) {
  return switch (visual) {
    BalanceCheckVisual.reconciledIncluded ||
    BalanceCheckVisual.reconciledExcluded => SelectionCheckColors.reconciled(
      colors,
    ),
    BalanceCheckVisual.pendingInclude ||
    BalanceCheckVisual.unselected => SelectionCheckColors.selection(colors),
  };
}

/// Palette for a transaction's reconcile checkmark. Green (reconciled) is
/// reserved for rows that are actually reconciled; while picking rows in
/// reconcile mode, a not-yet-reconciled row uses the accent (selection)
/// palette so a pending pick never reads as "reconciled".
SelectionCheckColors reconciledTogglePalette(
  AppColors colors, {
  required bool inSelectionMode,
  required bool actuallyReconciled,
}) {
  return (inSelectionMode && !actuallyReconciled)
      ? SelectionCheckColors.selection(colors)
      : SelectionCheckColors.reconciled(colors);
}

class SelectionCheckControl extends StatelessWidget {
  const SelectionCheckControl({
    super.key,
    required this.state,
    this.enabled = true,
    this.onTap,
    this.colors,
    this.size = 20,
    this.showDisabledIcon = true,
    this.excluded = false,
    this.iconOverride,
  });

  final SelectionState state;
  final bool enabled;
  final VoidCallback? onTap;
  final SelectionCheckColors? colors;
  final double size;
  final bool showDisabledIcon;

  /// When true with [SelectionState.none], shows a minus circle (excluded
  /// after having been reconciled) instead of an empty circle.
  final bool excluded;

  /// Optional icon to use instead of the state default icon.
  final IconData? iconOverride;

  @override
  Widget build(BuildContext context) {
    final palette = colors ?? SelectionCheckColors.selection(context.colors);

    if (!enabled) {
      if (!showDisabledIcon) {
        return SizedBox(width: size + 8, height: size + 8);
      }
      return Icon(LucideIcons.circleOff, size: size, color: palette.disabled);
    }

    final IconData icon;
    final Color color;
    if (iconOverride != null) {
      icon = iconOverride!;
      color = palette.selected;
    } else {
      switch (state) {
        case SelectionState.all:
          icon = LucideIcons.circleCheck;
          color = palette.selected;
        case SelectionState.partial:
          icon = LucideIcons.circleDot;
          color = palette.partial;
        case SelectionState.none:
          icon = excluded ? LucideIcons.circleMinus : LucideIcons.circle;
          color = excluded
              ? palette.selected.withValues(alpha: 0.7)
              : palette.unselected;
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}
