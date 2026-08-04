import 'package:fireracoon/models/side_menu_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('getLucideIcon', () {
    test('maps known names and falls back to folder', () {
      expect(getLucideIcon('layoutDashboard'), LucideIcons.layoutDashboard);
      expect(getLucideIcon('wallet'), LucideIcons.wallet);
      expect(getLucideIcon('scale'), LucideIcons.scale);
      expect(getLucideIcon('arrowLeftRight'), LucideIcons.arrowLeftRight);
      expect(getLucideIcon('target'), LucideIcons.target);
      expect(getLucideIcon('piggyBank'), LucideIcons.piggyBank);
      expect(getLucideIcon('repeat'), LucideIcons.repeat);
      expect(getLucideIcon('pieChart'), LucideIcons.pieChart);
      expect(getLucideIcon('arrowDownLeft'), LucideIcons.arrowDownLeft);
      expect(getLucideIcon('tags'), LucideIcons.tags);
      expect(getLucideIcon('store'), LucideIcons.store);
      expect(getLucideIcon('sparkles'), LucideIcons.sparkles);
      expect(getLucideIcon('history'), LucideIcons.history);
      expect(getLucideIcon('folder'), LucideIcons.folder);
      expect(getLucideIcon('layers'), LucideIcons.layers);
      expect(getLucideIcon('list'), LucideIcons.list);
      expect(getLucideIcon('bookmark'), LucideIcons.bookmark);
      expect(getLucideIcon('star'), LucideIcons.star);
      expect(getLucideIcon('box'), LucideIcons.box);
      expect(getLucideIcon('briefcase'), LucideIcons.briefcase);
      expect(getLucideIcon('landmark'), LucideIcons.landmark);
      expect(getLucideIcon('coins'), LucideIcons.coins);
      expect(getLucideIcon('settings'), LucideIcons.settings);
      expect(getLucideIcon('shield'), LucideIcons.shield);
      expect(getLucideIcon('heart'), LucideIcons.heart);
      expect(getLucideIcon('zap'), LucideIcons.zap);
      expect(getLucideIcon('globe'), LucideIcons.globe);
      expect(getLucideIcon('grid'), LucideIcons.grid);
      expect(getLucideIcon('unknown-icon'), LucideIcons.folder);
    });

    test('kAvailableIcons has labels and icons', () {
      expect(kAvailableIcons, isNotEmpty);
      expect(kAvailableIcons.first['name'], 'folder');
      expect(kAvailableIcons.first['icon'], LucideIcons.folder);
    });
  });

  group('SideMenuItem/Group/Node/Config JSON', () {
    test('item round-trips with defaults', () {
      final item = SideMenuItem.fromJson({
        'id': 'accounts',
        'routePath': '/accounts',
      });
      expect(item.defaultTitleKey, 'accounts');
      expect(item.defaultTitle, 'accounts');
      expect(item.iconName, 'folder');
      expect(item.isHidden, isFalse);
      expect(item.copyWith(isHidden: true).isHidden, isTrue);
      expect(item.copyWith().isHidden, isFalse);
      expect(item.toJson()['routePath'], '/accounts');
    });

    test('group and node round-trip', () {
      final group = SideMenuGroup(
        id: 'g1',
        title: 'Accounts',
        iconName: 'wallet',
        items: [SideMenuConfig.defaultItems['accounts']!],
      );
      final decoded = SideMenuGroup.fromJson(group.toJson());
      expect(decoded.items, hasLength(1));
      expect(decoded.copyWith(title: 'X').title, 'X');

      final itemNode = SideMenuNode.item(
        SideMenuConfig.defaultItems['dashboard']!,
      );
      expect(itemNode.id, 'dashboard');
      expect(itemNode.isHidden, isFalse);
      expect(itemNode.copyWithHidden(true).isHidden, isTrue);
      expect(SideMenuNode.fromJson(itemNode.toJson()).id, 'dashboard');

      final groupNode = SideMenuNode.group(group);
      expect(groupNode.id, 'g1');
      expect(
        SideMenuNode.fromJson(groupNode.toJson()).group!.title,
        'Accounts',
      );
    });

    test('config default and JSON round-trip', () {
      final config = SideMenuConfig.defaultConfig;
      expect(config.nodes, isNotEmpty);
      final roundTrip = SideMenuConfig.fromJson(config.toJson());
      expect(roundTrip.nodes.length, config.nodes.length);
      expect(SideMenuConfig.fromJson({}).nodes, isEmpty);
      expect(
        SideMenuConfig.defaultItems['projection']!.routePath,
        '/projection',
      );
    });
  });
}
