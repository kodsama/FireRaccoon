import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

IconData getLucideIcon(String iconName) {
  switch (iconName) {
    case 'layoutDashboard':
      return LucideIcons.layoutDashboard;
    case 'wallet':
      return LucideIcons.wallet;
    case 'scale':
      return LucideIcons.scale;
    case 'arrowLeftRight':
      return LucideIcons.arrowLeftRight;
    case 'target':
      return LucideIcons.target;
    case 'piggyBank':
      return LucideIcons.piggyBank;
    case 'repeat':
      return LucideIcons.repeat;
    case 'pieChart':
      return LucideIcons.pieChart;
    case 'arrowDownLeft':
      return LucideIcons.arrowDownLeft;
    case 'tags':
      return LucideIcons.tags;
    case 'store':
      return LucideIcons.store;
    case 'sparkles':
      return LucideIcons.sparkles;
    case 'history':
      return LucideIcons.history;
    case 'folder':
      return LucideIcons.folder;
    case 'layers':
      return LucideIcons.layers;
    case 'list':
      return LucideIcons.list;
    case 'bookmark':
      return LucideIcons.bookmark;
    case 'star':
      return LucideIcons.star;
    case 'box':
      return LucideIcons.box;
    case 'briefcase':
      return LucideIcons.briefcase;
    case 'landmark':
      return LucideIcons.landmark;
    case 'coins':
      return LucideIcons.coins;
    case 'settings':
      return LucideIcons.settings;
    case 'shield':
      return LucideIcons.shield;
    case 'heart':
      return LucideIcons.heart;
    case 'zap':
      return LucideIcons.zap;
    case 'globe':
      return LucideIcons.globe;
    case 'grid':
      return LucideIcons.grid;
    default:
      return LucideIcons.folder;
  }
}

const List<Map<String, dynamic>> kAvailableIcons = [
  {'name': 'folder', 'label': 'Folder', 'icon': LucideIcons.folder},
  {
    'name': 'layoutDashboard',
    'label': 'Dashboard',
    'icon': LucideIcons.layoutDashboard,
  },
  {'name': 'wallet', 'label': 'Wallet', 'icon': LucideIcons.wallet},
  {'name': 'scale', 'label': 'Scale', 'icon': LucideIcons.scale},
  {
    'name': 'arrowLeftRight',
    'label': 'Arrows',
    'icon': LucideIcons.arrowLeftRight,
  },
  {'name': 'target', 'label': 'Target', 'icon': LucideIcons.target},
  {'name': 'piggyBank', 'label': 'Piggy Bank', 'icon': LucideIcons.piggyBank},
  {'name': 'repeat', 'label': 'Repeat', 'icon': LucideIcons.repeat},
  {'name': 'pieChart', 'label': 'Pie Chart', 'icon': LucideIcons.pieChart},
  {
    'name': 'arrowDownLeft',
    'label': 'Income',
    'icon': LucideIcons.arrowDownLeft,
  },
  {'name': 'tags', 'label': 'Tags', 'icon': LucideIcons.tags},
  {'name': 'store', 'label': 'Store', 'icon': LucideIcons.store},
  {'name': 'sparkles', 'label': 'Sparkles', 'icon': LucideIcons.sparkles},
  {'name': 'history', 'label': 'History', 'icon': LucideIcons.history},
  {'name': 'layers', 'label': 'Layers', 'icon': LucideIcons.layers},
  {'name': 'list', 'label': 'List', 'icon': LucideIcons.list},
  {'name': 'bookmark', 'label': 'Bookmark', 'icon': LucideIcons.bookmark},
  {'name': 'star', 'label': 'Star', 'icon': LucideIcons.star},
  {'name': 'box', 'label': 'Box', 'icon': LucideIcons.box},
  {'name': 'briefcase', 'label': 'Briefcase', 'icon': LucideIcons.briefcase},
  {'name': 'landmark', 'label': 'Bank', 'icon': LucideIcons.landmark},
  {'name': 'coins', 'label': 'Coins', 'icon': LucideIcons.coins},
  {'name': 'grid', 'label': 'Grid', 'icon': LucideIcons.grid},
];

class SideMenuItem {
  final String id;
  final String routePath;
  final String defaultTitleKey;
  final String defaultTitle;
  final String iconName;
  final bool isHidden;

  const SideMenuItem({
    required this.id,
    required this.routePath,
    required this.defaultTitleKey,
    required this.defaultTitle,
    required this.iconName,
    this.isHidden = false,
  });

  SideMenuItem copyWith({
    String? id,
    String? routePath,
    String? defaultTitleKey,
    String? defaultTitle,
    String? iconName,
    bool? isHidden,
  }) {
    return SideMenuItem(
      id: id ?? this.id,
      routePath: routePath ?? this.routePath,
      defaultTitleKey: defaultTitleKey ?? this.defaultTitleKey,
      defaultTitle: defaultTitle ?? this.defaultTitle,
      iconName: iconName ?? this.iconName,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'routePath': routePath,
    'defaultTitleKey': defaultTitleKey,
    'defaultTitle': defaultTitle,
    'iconName': iconName,
    'isHidden': isHidden,
  };

  factory SideMenuItem.fromJson(Map<String, dynamic> json) => SideMenuItem(
    id: json['id'] as String,
    routePath: json['routePath'] as String,
    defaultTitleKey: json['defaultTitleKey'] as String? ?? json['id'] as String,
    defaultTitle: json['defaultTitle'] as String? ?? json['id'] as String,
    iconName: json['iconName'] as String? ?? 'folder',
    isHidden: json['isHidden'] as bool? ?? false,
  );
}

class SideMenuGroup {
  final String id;
  final String title;
  final String iconName;
  final bool isCollapsible;
  final List<SideMenuItem> items;
  final bool isHidden;

  const SideMenuGroup({
    required this.id,
    required this.title,
    required this.iconName,
    this.isCollapsible = true,
    this.items = const [],
    this.isHidden = false,
  });

  SideMenuGroup copyWith({
    String? id,
    String? title,
    String? iconName,
    bool? isCollapsible,
    List<SideMenuItem>? items,
    bool? isHidden,
  }) {
    return SideMenuGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      iconName: iconName ?? this.iconName,
      isCollapsible: isCollapsible ?? this.isCollapsible,
      items: items ?? this.items,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'iconName': iconName,
    'isCollapsible': isCollapsible,
    'items': items.map((i) => i.toJson()).toList(),
    'isHidden': isHidden,
  };

  factory SideMenuGroup.fromJson(Map<String, dynamic> json) => SideMenuGroup(
    id: json['id'] as String,
    title: json['title'] as String,
    iconName: json['iconName'] as String? ?? 'folder',
    isCollapsible: json['isCollapsible'] as bool? ?? true,
    items:
        (json['items'] as List<dynamic>?)
            ?.map((i) => SideMenuItem.fromJson(i as Map<String, dynamic>))
            .toList() ??
        const [],
    isHidden: json['isHidden'] as bool? ?? false,
  );
}

enum SideMenuNodeType { item, group }

class SideMenuNode {
  final SideMenuNodeType type;
  final SideMenuItem? item;
  final SideMenuGroup? group;

  const SideMenuNode.item(SideMenuItem this.item)
    : type = SideMenuNodeType.item,
      group = null;

  const SideMenuNode.group(SideMenuGroup this.group)
    : type = SideMenuNodeType.group,
      item = null;

  String get id => type == SideMenuNodeType.item ? item!.id : group!.id;
  bool get isHidden =>
      type == SideMenuNodeType.item ? item!.isHidden : group!.isHidden;

  SideMenuNode copyWithHidden(bool hidden) {
    if (type == SideMenuNodeType.item) {
      return SideMenuNode.item(item!.copyWith(isHidden: hidden));
    } else {
      return SideMenuNode.group(group!.copyWith(isHidden: hidden));
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    if (type == SideMenuNodeType.item) 'item': item!.toJson(),
    if (type == SideMenuNodeType.group) 'group': group!.toJson(),
  };

  factory SideMenuNode.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String;
    if (typeName == 'item') {
      return SideMenuNode.item(
        SideMenuItem.fromJson(json['item'] as Map<String, dynamic>),
      );
    } else {
      return SideMenuNode.group(
        SideMenuGroup.fromJson(json['group'] as Map<String, dynamic>),
      );
    }
  }
}

class SideMenuConfig {
  final List<SideMenuNode> nodes;

  const SideMenuConfig({required this.nodes});

  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((n) => n.toJson()).toList(),
  };

  factory SideMenuConfig.fromJson(Map<String, dynamic> json) {
    final rawNodes =
        (json['nodes'] as List<dynamic>?)
            ?.map((n) => SideMenuNode.fromJson(n as Map<String, dynamic>))
            .toList() ??
        [];
    return SideMenuConfig(nodes: rawNodes);
  }

  static const defaultItems = <String, SideMenuItem>{
    'dashboard': SideMenuItem(
      id: 'dashboard',
      routePath: '/',
      defaultTitleKey: 'navDashboard',
      defaultTitle: 'Dashboard',
      iconName: 'layoutDashboard',
    ),
    'accounts': SideMenuItem(
      id: 'accounts',
      routePath: '/accounts',
      defaultTitleKey: 'navAccounts',
      defaultTitle: 'Accounts',
      iconName: 'wallet',
    ),
    'liabilities': SideMenuItem(
      id: 'liabilities',
      routePath: '/liabilities',
      defaultTitleKey: 'navLiabilities',
      defaultTitle: 'Liabilities',
      iconName: 'scale',
    ),
    'transactions': SideMenuItem(
      id: 'transactions',
      routePath: '/transactions',
      defaultTitleKey: 'navTransactions',
      defaultTitle: 'Transactions',
      iconName: 'arrowLeftRight',
    ),
    'budgets': SideMenuItem(
      id: 'budgets',
      routePath: '/budgets',
      defaultTitleKey: 'navBudgets',
      defaultTitle: 'Budgets',
      iconName: 'target',
    ),
    'piggy_banks': SideMenuItem(
      id: 'piggy_banks',
      routePath: '/piggy-banks',
      defaultTitleKey: 'navPiggyBanks',
      defaultTitle: 'Piggy Banks',
      iconName: 'piggyBank',
    ),
    'subscriptions': SideMenuItem(
      id: 'subscriptions',
      routePath: '/subscriptions',
      defaultTitleKey: 'navSubscriptions',
      defaultTitle: 'Subscriptions',
      iconName: 'repeat',
    ),
    'expenses': SideMenuItem(
      id: 'expenses',
      routePath: '/expenses',
      defaultTitleKey: 'navExpenses',
      defaultTitle: 'Expenses',
      iconName: 'pieChart',
    ),
    'income': SideMenuItem(
      id: 'income',
      routePath: '/income',
      defaultTitleKey: 'navIncome',
      defaultTitle: 'Income',
      iconName: 'arrowDownLeft',
    ),
    'transfers': SideMenuItem(
      id: 'transfers',
      routePath: '/transfers',
      defaultTitleKey: 'navTransfers',
      defaultTitle: 'Transfers',
      iconName: 'arrowLeftRight',
    ),
    'payees': SideMenuItem(
      id: 'payees',
      routePath: '/payees',
      defaultTitleKey: 'payees',
      defaultTitle: 'Payees',
      iconName: 'store',
    ),
    'categories_tags': SideMenuItem(
      id: 'categories_tags',
      routePath: '/categories-tags',
      defaultTitleKey: 'categoriesTags',
      defaultTitle: 'Categories & Tags',
      iconName: 'tags',
    ),
    'projection': SideMenuItem(
      id: 'projection',
      routePath: '/projection',
      defaultTitleKey: 'navProjection',
      defaultTitle: 'Projection',
      iconName: 'sparkles',
    ),
    'history': SideMenuItem(
      id: 'history',
      routePath: '/history',
      defaultTitleKey: 'navHistory',
      defaultTitle: 'History',
      iconName: 'history',
    ),
  };

  static SideMenuConfig get defaultConfig => SideMenuConfig(
    nodes: [
      SideMenuNode.item(defaultItems['dashboard']!),
      SideMenuNode.group(
        SideMenuGroup(
          id: 'group_accounts',
          title: 'Accounts',
          iconName: 'wallet',
          isCollapsible: true,
          items: [defaultItems['accounts']!, defaultItems['liabilities']!],
        ),
      ),
      SideMenuNode.item(defaultItems['transactions']!),
      SideMenuNode.group(
        SideMenuGroup(
          id: 'group_budgets',
          title: 'Budgets',
          iconName: 'target',
          isCollapsible: true,
          items: [defaultItems['budgets']!, defaultItems['piggy_banks']!],
        ),
      ),
      SideMenuNode.item(defaultItems['subscriptions']!),
      SideMenuNode.group(
        SideMenuGroup(
          id: 'group_stats',
          title: 'Stats',
          iconName: 'pieChart',
          isCollapsible: true,
          items: [
            defaultItems['expenses']!,
            defaultItems['income']!,
            defaultItems['transfers']!,
          ],
        ),
      ),
      SideMenuNode.group(
        SideMenuGroup(
          id: 'group_details',
          title: 'Details',
          iconName: 'tags',
          isCollapsible: true,
          items: [defaultItems['payees']!, defaultItems['categories_tags']!],
        ),
      ),
      SideMenuNode.item(defaultItems['projection']!),
      SideMenuNode.item(defaultItems['history']!),
    ],
  );
}
