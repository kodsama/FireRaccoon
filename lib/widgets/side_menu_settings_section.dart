import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../l10n/l10n_extensions.dart';
import '../models/side_menu_config.dart';
import '../providers/side_menu_config_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'confirmation_dialog.dart';

class SideMenuSettingsSection extends ConsumerWidget {
  const SideMenuSettingsSection({super.key});

  void _showContainerDialog(
    BuildContext context,
    WidgetRef ref, {
    SideMenuGroup? existingGroup,
  }) {
    final titleController = TextEditingController(
      text: existingGroup?.title ?? '',
    );
    String selectedIcon = existingGroup?.iconName ?? 'folder';
    bool isCollapsible = existingGroup?.isCollapsible ?? true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                existingGroup == null ? 'Add New Container' : 'Edit Container',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Container Name',
                        hintText: 'e.g. Reports, Personal, Tools',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Container Icon',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kAvailableIcons.map((iconData) {
                        final String name = iconData['name'] as String;
                        final IconData icon = iconData['icon'] as IconData;
                        final bool isSelected = selectedIcon == name;
                        return ChoiceChip(
                          avatar: Icon(icon, size: 16),
                          label: Text(iconData['label'] as String),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() => selectedIcon = name);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Collapsible Container'),
                      subtitle: const Text(
                        'Allows collapsing and expanding items with a chevron arrow',
                      ),
                      value: isCollapsible,
                      onChanged: (val) => setState(() => isCollapsible = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final notifier = ref.read(sideMenuConfigProvider.notifier);
                    if (existingGroup == null) {
                      notifier.addGroup(
                        title: titleController.text,
                        iconName: selectedIcon,
                        isCollapsible: isCollapsible,
                      );
                    } else {
                      notifier.updateGroup(
                        existingGroup.id,
                        title: titleController.text,
                        iconName: selectedIcon,
                        isCollapsible: isCollapsible,
                      );
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showConfirmationDialog(
      context: context,
      title: 'Reset Side Menu Layout',
      message:
          'Are you sure you want to reset the side menu layout to default?',
      confirmLabel: 'Reset',
    ).then((confirmed) {
      if (confirmed == true) {
        ref.read(sideMenuConfigProvider.notifier).resetToDefault();
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);
    final config = ref.watch(sideMenuConfigProvider);
    final notifier = ref.read(sideMenuConfigProvider.notifier);

    final availableGroups = config.nodes
        .where((n) => n.type == SideMenuNodeType.group)
        .map((n) => n.group!)
        .toList();

    final flatNodes = getFlatNodes(config);

    String getItemTitle(SideMenuItem item) {
      switch (item.defaultTitleKey) {
        case 'navDashboard':
          return fun.navDashboard;
        case 'navAccounts':
          return fun.navAccounts;
        case 'navLiabilities':
          return fun.navLiabilities;
        case 'navTransactions':
          return fun.navTransactions;
        case 'navBudgets':
          return fun.navBudgets;
        case 'navPiggyBanks':
          return fun.navPiggyBanks;
        case 'navSubscriptions':
          return fun.navSubscriptions;
        case 'navExpenses':
          return fun.navExpenses;
        case 'navIncome':
          return fun.navIncome;
        case 'navTransfers':
          return fun.navTransfers;
        case 'payees':
          return 'Payees';
        case 'categoriesTags':
          return 'Categories & Tags';
        case 'navProjection':
          return fun.navProjection;
        case 'navHistory':
          return fun.navHistory;
        default:
          return item.defaultTitle;
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          leading: const Icon(LucideIcons.menu, size: 20),
          title: Text(
            'Side Menu Layout',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 16),
          ),
          subtitle: const Text(
            'Reorganize menu items by long-pressing or dragging rows directly into or out of containers',
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showContainerDialog(context, ref),
                  icon: const Icon(LucideIcons.folderPlus, size: 16),
                  label: const Text('Add Container'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _confirmReset(context, ref),
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReorderableListView.builder(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: flatNodes.length,
              onReorderItem: (oldIdx, newIdx) =>
                  notifier.reorderFlat(oldIdx, newIdx),
              itemBuilder: (context, index) {
                final flatNode = flatNodes[index];
                if (flatNode.type == FlatNodeType.groupHeader) {
                  return _GroupHeaderTile(
                    key: ValueKey(flatNode.id),
                    group: flatNode.group!,
                    flatIndex: index,
                    colors: colors,
                    notifier: notifier,
                    onEditGroup: () => _showContainerDialog(
                      context,
                      ref,
                      existingGroup: flatNode.group,
                    ),
                  );
                } else if (flatNode.type == FlatNodeType.groupChild) {
                  return _ChildItemTile(
                    key: ValueKey(flatNode.id),
                    item: flatNode.item!,
                    group: flatNode.group!,
                    flatIndex: index,
                    getItemTitle: getItemTitle,
                    notifier: notifier,
                    colors: colors,
                  );
                } else {
                  return _StandaloneItemTile(
                    key: ValueKey(flatNode.id),
                    item: flatNode.item!,
                    flatIndex: index,
                    availableGroups: availableGroups,
                    getItemTitle: getItemTitle,
                    notifier: notifier,
                    colors: colors,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeaderTile extends StatelessWidget {
  final SideMenuGroup group;
  final int flatIndex;
  final AppColors colors;
  final SideMenuConfigNotifier notifier;
  final VoidCallback onEditGroup;

  const _GroupHeaderTile({
    required super.key,
    required this.group,
    required this.flatIndex,
    required this.colors,
    required this.notifier,
    required this.onEditGroup,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableDelayedDragStartListener(
      index: flatIndex,
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 2),
        decoration: BoxDecoration(
          color: colors.panel2.withValues(alpha: 0.6),
          border: Border.all(
            color: colors.accent.acc.withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
          leading: Icon(
            getLucideIcon(group.iconName),
            color: group.isHidden ? colors.text3 : colors.accent.acc,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: group.isHidden ? colors.text3 : null,
                    decoration: group.isHidden
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent.acc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  group.isCollapsible ? 'Collapsible' : 'Static Section',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.accent.acc,
                  ),
                ),
              ),
            ],
          ),
          trailing: _AlignedRowActions(
            colors: colors,
            isHidden: group.isHidden,
            dragIndex: flatIndex,
            onToggleVisibility: () => notifier.toggleNodeVisibility(group.id),
            slot4Action: IconButton(
              tooltip: 'Edit Container',
              icon: const Icon(Icons.edit, size: 18),
              onPressed: onEditGroup,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
            ),
            slot5Action: IconButton(
              tooltip: 'Delete Container',
              icon: Icon(Icons.delete_outline, size: 18, color: colors.danger),
              onPressed: () => notifier.deleteGroup(group.id),
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildItemTile extends StatelessWidget {
  final SideMenuItem item;
  final SideMenuGroup group;
  final int flatIndex;
  final String Function(SideMenuItem) getItemTitle;
  final SideMenuConfigNotifier notifier;
  final AppColors colors;

  const _ChildItemTile({
    required super.key,
    required this.item,
    required this.group,
    required this.flatIndex,
    required this.getItemTitle,
    required this.notifier,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final title = getItemTitle(item);

    return ReorderableDelayedDragStartListener(
      index: flatIndex,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: colors.panel2.withValues(alpha: 0.3),
          border: Border(
            left: BorderSide(color: colors.accent.acc, width: 3),
            right: BorderSide(
              color: colors.accent.acc.withValues(alpha: 0.2),
              width: 1,
            ),
            bottom: BorderSide(
              color: colors.accent.acc.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 16),
              Icon(
                getLucideIcon(item.iconName),
                size: 18,
                color: item.isHidden ? colors.text3 : colors.sidebarMuted,
              ),
            ],
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: item.isHidden ? colors.text3 : null,
              decoration: item.isHidden ? TextDecoration.lineThrough : null,
            ),
          ),
          trailing: _AlignedRowActions(
            colors: colors,
            isHidden: item.isHidden,
            dragIndex: flatIndex,
            onToggleVisibility: () =>
                notifier.toggleGroupItemVisibility(group.id, item.id),
            slot4Action: IconButton(
              tooltip: 'Move out of container',
              icon: const Icon(LucideIcons.folderOutput, size: 18),
              onPressed: () => notifier.moveItemToGroup(item.id, null),
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
            ),
            slot5Action: const SizedBox(width: 36),
          ),
        ),
      ),
    );
  }
}

class _StandaloneItemTile extends StatelessWidget {
  final SideMenuItem item;
  final int flatIndex;
  final List<SideMenuGroup> availableGroups;
  final String Function(SideMenuItem) getItemTitle;
  final SideMenuConfigNotifier notifier;
  final AppColors colors;

  const _StandaloneItemTile({
    required super.key,
    required this.item,
    required this.flatIndex,
    required this.availableGroups,
    required this.getItemTitle,
    required this.notifier,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final title = getItemTitle(item);

    Widget slot4;
    if (availableGroups.isNotEmpty) {
      slot4 = PopupMenuButton<String>(
        tooltip: 'Move into Container',
        icon: const Icon(LucideIcons.folderInput, size: 18),
        constraints: const BoxConstraints(minWidth: 160),
        padding: EdgeInsets.zero,
        onSelected: (groupId) {
          notifier.moveItemToGroup(item.id, groupId);
        },
        itemBuilder: (context) {
          return availableGroups.map((g) {
            return PopupMenuItem(
              value: g.id,
              child: Row(
                children: [
                  Icon(getLucideIcon(g.iconName), size: 16),
                  const SizedBox(width: 8),
                  Text(g.title),
                ],
              ),
            );
          }).toList();
        },
      );
    } else {
      slot4 = const SizedBox(width: 36);
    }

    return ReorderableDelayedDragStartListener(
      index: flatIndex,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: colors.panel2.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(
            getLucideIcon(item.iconName),
            color: item.isHidden ? colors.text3 : colors.sidebarMuted,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: item.isHidden ? colors.text3 : null,
              decoration: item.isHidden ? TextDecoration.lineThrough : null,
            ),
          ),
          trailing: _AlignedRowActions(
            colors: colors,
            isHidden: item.isHidden,
            dragIndex: flatIndex,
            onToggleVisibility: () => notifier.toggleNodeVisibility(item.id),
            slot4Action: slot4,
            slot5Action: const SizedBox(width: 36),
          ),
        ),
      ),
    );
  }
}

/// Helper widget to enforce 100% pixel-perfect horizontal alignment across all rows.
class _AlignedRowActions extends StatelessWidget {
  final AppColors colors;
  final bool isHidden;
  final int dragIndex;
  final VoidCallback onToggleVisibility;
  final Widget slot4Action;
  final Widget slot5Action;

  const _AlignedRowActions({
    required this.colors,
    required this.isHidden,
    required this.dragIndex,
    required this.onToggleVisibility,
    required this.slot4Action,
    required this.slot5Action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Slot 1: Visibility Toggle (36px)
        IconButton(
          tooltip: isHidden ? 'Show' : 'Hide',
          icon: Icon(
            isHidden ? Icons.visibility_off : Icons.visibility,
            size: 18,
            color: isHidden ? colors.text3 : colors.accent.acc,
          ),
          onPressed: onToggleVisibility,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
        ),
        // Slot 2: Action Slot 4 (Edit / Move In / Move Out) (36px)
        SizedBox(width: 36, height: 36, child: Center(child: slot4Action)),
        // Slot 3: Action Slot 5 (Delete / Spacer) (36px)
        SizedBox(width: 36, height: 36, child: Center(child: slot5Action)),
        // Slot 4: Interactive Drag Handle (36px)
        ReorderableDragStartListener(
          index: dragIndex,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Icon(Icons.drag_handle, size: 18, color: colors.text3),
            ),
          ),
        ),
      ],
    );
  }
}
