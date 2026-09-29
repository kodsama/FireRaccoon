import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../theme/app_theme.dart';

/// One filter in a filter row. An active filter is filled with the accent
/// and carries its own clear button, so a narrowed view reads as narrowed
/// at a glance rather than only through the label it happens to show.
class FilterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onClear;
  final String? tooltip;

  const FilterPill({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.onClear,
    this.tooltip,
  });

  /// [idle] with nothing picked, the one name picked, or the first name
  /// and how many more, so a pill stays one short line however many.
  static String selectionLabel(
    Set<String> names,
    String idle, {
    String Function(String name)? labelOf,
  }) {
    if (names.isEmpty) return idle;
    final labels = names.map(labelOf ?? (name) => name).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return labels.length == 1
        ? labels.single
        : '${labels.first} +${labels.length - 1}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = active ? colors.accent.acc : colors.text;
    return Tooltip(
      message: tooltip ?? label,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          active && onClear != null ? 6 : 16,
          8,
        ),
        decoration: BoxDecoration(
          color: active
              ? colors.accent.acc.withValues(alpha: 0.16)
              : colors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? colors.accent.acc : colors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            if (active && onClear != null)
              Tooltip(
                message: context.l10n.clear,
                child: InkWell(
                  onTap: onClear,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(LucideIcons.x, size: 14, color: foreground),
                  ),
                ),
              )
            else
              Icon(LucideIcons.chevronDown, size: 14, color: colors.text3),
          ],
        ),
      ),
    );
  }
}
