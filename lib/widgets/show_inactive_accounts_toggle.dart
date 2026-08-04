import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../theme/app_theme.dart';

class ShowInactiveAccountsToggle extends StatelessWidget {
  final bool showInactive;
  final VoidCallback onToggle;

  const ShowInactiveAccountsToggle({
    super.key,
    required this.showInactive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final statusText = showInactive ? 'Inactive: Shown' : 'Inactive: Hidden';

    return Tooltip(
      message: l10n.showInactiveAccounts,
      child: Material(
        color: showInactive
            ? colors.accent.acc.withValues(alpha: 0.15)
            : colors.surface2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: showInactive ? colors.accent.acc : colors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  showInactive ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 16,
                  color: showInactive ? colors.accent.acc : colors.text3,
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: showInactive ? colors.accent.acc : colors.text,
                    fontWeight: showInactive
                        ? FontWeight.w600
                        : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
