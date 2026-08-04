// lib/widgets/view_mode_switch.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../l10n/app_localizations.dart';
import '../providers/view_mode_provider.dart';
import '../widgets/fun_decorated_surface.dart';

/// A widget that displays a dropdown menu to switch between view modes.
/// The UI shows an icon and the label of the currently selected mode.
/// Available view modes: Standard (Cards), Compact (Rows), and Tight (Tight rows).
class ViewModeSwitcher extends ConsumerWidget {
  const ViewModeSwitcher({super.key});

  String _viewModeLabel(AppLocalizations l10n, ViewMode mode) => switch (mode) {
    ViewMode.standard => l10n.viewModeCards,
    ViewMode.compact => l10n.viewModeRows,
    ViewMode.tight => l10n.viewModeTightRows,
  };

  IconData _viewModeIcon(ViewMode mode) => switch (mode) {
    ViewMode.standard => LucideIcons.layoutGrid,
    ViewMode.compact => LucideIcons.rows3,
    ViewMode.tight => LucideIcons.list,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewModeProvider);
    final l10n = AppLocalizations.of(context);
    final modeLabel = _viewModeLabel(l10n, mode);
    final modeIcon = _viewModeIcon(mode);

    return FunDecoratedSurface(
      child: PopupMenuButton<ViewMode>(
        offset: const Offset(0, 12),
        padding: EdgeInsets.zero,
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(modeIcon, size: 18),
            const SizedBox(width: 4),
            Text(modeLabel, style: Theme.of(context).textTheme.bodySmall),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: ViewMode.standard,
            child: Row(
              children: [
                const Icon(LucideIcons.layoutGrid, size: 18),
                const SizedBox(width: 8),
                Text(l10n.viewModeCards),
              ],
            ),
          ),
          PopupMenuItem(
            value: ViewMode.compact,
            child: Row(
              children: [
                const Icon(LucideIcons.rows3, size: 18),
                const SizedBox(width: 8),
                Text(l10n.viewModeRows),
              ],
            ),
          ),
          PopupMenuItem(
            value: ViewMode.tight,
            child: Row(
              children: [
                const Icon(LucideIcons.list, size: 18),
                const SizedBox(width: 8),
                Text(l10n.viewModeTightRows),
              ],
            ),
          ),
        ],
        onSelected: (selectedMode) =>
            ref.read(viewModeProvider.notifier).setMode(selectedMode),
      ),
    );
  }
}
