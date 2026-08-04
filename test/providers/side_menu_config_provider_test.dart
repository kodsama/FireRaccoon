import 'dart:convert';

import 'package:fireracoon/models/side_menu_config.dart';
import 'package:fireracoon/providers/side_menu_config_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> readyContainer() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(sideMenuConfigProvider, (_, _) {});
    addTearDown(sub.close);
    // Kick build + wait for SharedPreferences init.
    container.read(sideMenuConfigProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return container;
  }

  test('getFlatNodes expands groups and standalone items', () {
    final flat = getFlatNodes(SideMenuConfig.defaultConfig);
    expect(flat.any((n) => n.type == FlatNodeType.groupHeader), isTrue);
    expect(flat.any((n) => n.type == FlatNodeType.groupChild), isTrue);
    expect(flat.any((n) => n.type == FlatNodeType.standaloneItem), isTrue);
  });

  test('loads default config and persists reorderNodes', () async {
    SharedPreferences.setMockInitialValues({});
    final container = await readyContainer();
    final notifier = container.read(sideMenuConfigProvider.notifier);
    final before = container.read(sideMenuConfigProvider);
    expect(before.nodes, isNotEmpty);

    notifier.reorderNodes(0, 2);
    final after = container.read(sideMenuConfigProvider);
    expect(after.nodes.first.id, isNot(before.nodes.first.id));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fireracoon_side_menu_config'), isNotNull);
  });

  test('loads saved config and backfills missing default items', () async {
    final minimal = SideMenuConfig(
      nodes: [
        SideMenuNode.item(SideMenuConfig.defaultItems['dashboard']!),
        SideMenuNode.group(
          SideMenuGroup(
            id: 'saved-group',
            title: 'Saved',
            iconName: 'folder',
            items: [SideMenuConfig.defaultItems['accounts']!],
          ),
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'fireracoon_side_menu_config': jsonEncode(minimal.toJson()),
    });

    final container = await readyContainer();
    final config = container.read(sideMenuConfigProvider);
    final ids = <String>{};
    for (final node in config.nodes) {
      if (node.type == SideMenuNodeType.item) {
        ids.add(node.item!.id);
      } else {
        ids.addAll(node.group!.items.map((i) => i.id));
      }
    }
    expect(ids.contains('accounts'), isTrue);
    expect(ids.contains('history'), isTrue);
  });

  test('invalid saved JSON falls back to default', () async {
    SharedPreferences.setMockInitialValues({
      'fireracoon_side_menu_config': '{not-json',
    });
    final container = await readyContainer();
    expect(
      container.read(sideMenuConfigProvider).nodes.length,
      SideMenuConfig.defaultConfig.nodes.length,
    );
  });

  test('group CRUD, move, visibility, and reset', () async {
    SharedPreferences.setMockInitialValues({});
    final container = await readyContainer();
    final notifier = container.read(sideMenuConfigProvider.notifier);

    notifier.addGroup(title: '  ', iconName: 'folder', isCollapsible: true);
    var config = container.read(sideMenuConfigProvider);
    final groupId = config.nodes
        .where((n) => n.type == SideMenuNodeType.group)
        .map((n) => n.group!.id)
        .lastWhere((id) => id.startsWith('group_'));
    expect(
      config.nodes.any(
        (n) =>
            n.type == SideMenuNodeType.group &&
            n.group!.title == 'New Container',
      ),
      isTrue,
    );

    notifier.updateGroup(
      groupId,
      title: 'Custom',
      iconName: 'star',
      isCollapsible: false,
    );
    config = container.read(sideMenuConfigProvider);
    expect(
      config.nodes
          .firstWhere(
            (n) => n.type == SideMenuNodeType.group && n.group!.id == groupId,
          )
          .group!
          .title,
      'Custom',
    );

    notifier.moveItemToGroup('dashboard', groupId);
    config = container.read(sideMenuConfigProvider);
    expect(
      config.nodes
          .firstWhere((n) => n.group?.id == groupId)
          .group!
          .items
          .any((i) => i.id == 'dashboard'),
      isTrue,
    );

    notifier.reorderGroupItems(groupId, 0, 1);
    notifier.toggleGroupItemVisibility(groupId, 'dashboard');
    config = container.read(sideMenuConfigProvider);
    expect(
      config.nodes
          .firstWhere((n) => n.group?.id == groupId)
          .group!
          .items
          .firstWhere((i) => i.id == 'dashboard')
          .isHidden,
      isTrue,
    );

    notifier.toggleNodeVisibility(groupId);
    notifier.deleteGroup(groupId);
    config = container.read(sideMenuConfigProvider);
    expect(config.nodes.any((n) => n.group?.id == groupId), isFalse);

    notifier.resetToDefault();
    expect(
      container.read(sideMenuConfigProvider).nodes.length,
      SideMenuConfig.defaultConfig.nodes.length,
    );
  });

  test('reorderFlat moves nodes', () async {
    SharedPreferences.setMockInitialValues({});
    final container = await readyContainer();
    final notifier = container.read(sideMenuConfigProvider.notifier);
    final flat = getFlatNodes(container.read(sideMenuConfigProvider));
    expect(flat.length, greaterThan(3));

    notifier.reorderFlat(1, 1);
    notifier.reorderFlat(flat.length - 1, 1);

    final withGroups = getFlatNodes(container.read(sideMenuConfigProvider));
    final headerIndex = withGroups.indexWhere(
      (n) => n.type == FlatNodeType.groupHeader,
    );
    expect(headerIndex, greaterThanOrEqualTo(0));
    notifier.reorderFlat(
      headerIndex,
      (headerIndex + 2).clamp(0, withGroups.length),
    );

    notifier.reorderFlat(-1, 0);
    notifier.reorderFlat(999, 0);
    expect(getFlatNodes(container.read(sideMenuConfigProvider)), isNotEmpty);
  });

  test(
    'moveItemToGroup null ungroups and reorderFlat ends on standalone',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = await readyContainer();
      final notifier = container.read(sideMenuConfigProvider.notifier);

      notifier.moveItemToGroup('dashboard', 'group_accounts');
      notifier.moveItemToGroup('dashboard', null);
      expect(
        container
            .read(sideMenuConfigProvider)
            .nodes
            .any((n) => n.item?.id == 'dashboard'),
        isTrue,
      );

      for (final groupId in [
        'group_accounts',
        'group_budgets',
        'group_stats',
        'group_details',
      ]) {
        notifier.deleteGroup(groupId);
      }

      final flat = getFlatNodes(container.read(sideMenuConfigProvider));
      expect(flat.every((n) => n.type == FlatNodeType.standaloneItem), isTrue);
      notifier.reorderFlat(0, flat.length);
      expect(container.read(sideMenuConfigProvider).nodes.last.item, isNotNull);
    },
  );

  test(
    'reorderFlat handles group children, list end, and standalone targets',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = await readyContainer();
      final notifier = container.read(sideMenuConfigProvider.notifier);
      notifier.addGroup(
        title: 'Custom',
        iconName: 'folder',
        isCollapsible: true,
      );
      final groupId = container
          .read(sideMenuConfigProvider)
          .nodes
          .where((node) => node.group?.title == 'Custom')
          .single
          .group!
          .id;
      notifier.moveItemToGroup('dashboard', groupId);
      notifier.moveItemToGroup('accounts', groupId);

      var flat = getFlatNodes(container.read(sideMenuConfigProvider));
      final transactionsIndex = flat.indexWhere(
        (node) => node.item?.id == 'transactions',
      );
      final firstChildIndex = flat.indexWhere(
        (node) =>
            node.type == FlatNodeType.groupChild &&
            node.parentGroupId == groupId,
      );
      notifier.reorderFlat(transactionsIndex, firstChildIndex);
      expect(
        container
            .read(sideMenuConfigProvider)
            .nodes
            .firstWhere((node) => node.group?.id == groupId)
            .group!
            .items
            .first
            .id,
        'transactions',
      );

      flat = getFlatNodes(container.read(sideMenuConfigProvider));
      final budgetsIndex = flat.indexWhere(
        (node) => node.item?.id == 'budgets',
      );
      notifier.reorderFlat(budgetsIndex, flat.length);
      expect(
        container
            .read(sideMenuConfigProvider)
            .nodes
            .firstWhere((node) => node.group?.id == groupId)
            .group!
            .items
            .last
            .id,
        'budgets',
      );

      flat = getFlatNodes(container.read(sideMenuConfigProvider));
      final dashboardIndex = flat.indexWhere(
        (node) => node.item?.id == 'dashboard',
      );
      final historyIndex = flat.indexWhere(
        (node) => node.item?.id == 'history',
      );
      notifier.reorderFlat(dashboardIndex, historyIndex);
      expect(
        container
            .read(sideMenuConfigProvider)
            .nodes
            .any((node) => node.item?.id == 'dashboard'),
        isTrue,
      );
    },
  );
}
