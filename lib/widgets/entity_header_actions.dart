import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/people_providers.dart';
import '../theme/app_theme.dart';
import 'entity_action_icon.dart';

/// Standard edit (wrench), optional duplicate (copy), and delete (trash) icons.
class EntityHeaderActions extends ConsumerWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onReconcile;
  final VoidCallback? onLink;
  final List<Widget> leading;
  final double iconSize;

  const EntityHeaderActions({
    super.key,
    required this.onEdit,
    required this.onDelete,
    this.onDuplicate,
    this.onReconcile,
    this.onLink,
    this.leading = const [],
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final canWrite = ref.watch(canWriteFinancialDataProvider);
    if (!canWrite) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...leading,
        if (leading.isNotEmpty) const SizedBox(width: 8),
        if (onLink != null) ...[
          EntityActionIcon(
            icon: LucideIcons.link2,
            tooltip: 'Link / Auto-Assign...',
            onTap: onLink!,
            color: colors.text3,
            size: iconSize,
          ),
          const SizedBox(width: 2),
        ],
        EntityActionIcon(
          icon: LucideIcons.wrench,
          tooltip: l10n.editAction,
          onTap: onEdit,
          color: colors.text3,
          size: iconSize,
        ),
        if (onDuplicate != null) ...[
          const SizedBox(width: 2),
          EntityActionIcon(
            icon: LucideIcons.copy,
            tooltip: l10n.duplicate,
            onTap: onDuplicate!,
            color: colors.text3,
            size: iconSize,
          ),
        ],
        if (onReconcile != null) ...[
          const SizedBox(width: 2),
          EntityActionIcon(
            icon: LucideIcons.listChecks,
            tooltip: l10n.reconciliationTitle,
            onTap: onReconcile!,
            color: colors.text3,
            size: iconSize,
          ),
        ],
        const SizedBox(width: 2),
        EntityActionIcon(
          icon: LucideIcons.trash2,
          tooltip: l10n.delete,
          onTap: onDelete,
          color: colors.danger,
          size: iconSize,
        ),
      ],
    );
  }
}
