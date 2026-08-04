import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/side_menu_config.dart';

const String _kSideMenuConfigPrefKey = 'fireracoon_side_menu_config';

enum FlatNodeType { groupHeader, groupChild, standaloneItem }

class FlatNode {
  final String id;
  final FlatNodeType type;
  final SideMenuGroup? group;
  final SideMenuItem? item;
  final String? parentGroupId;
  final int topLevelNodeIndex;
  final int childIndex;

  FlatNode({
    required this.id,
    required this.type,
    this.group,
    this.item,
    this.parentGroupId,
    required this.topLevelNodeIndex,
    required this.childIndex,
  });
}

List<FlatNode> getFlatNodes(SideMenuConfig config) {
  final flat = <FlatNode>[];
  for (int i = 0; i < config.nodes.length; i++) {
    final node = config.nodes[i];
    if (node.type == SideMenuNodeType.group) {
      final group = node.group!;
      flat.add(
        FlatNode(
          id: 'group_${group.id}',
          type: FlatNodeType.groupHeader,
          group: group,
          topLevelNodeIndex: i,
          childIndex: -1,
        ),
      );
      for (int j = 0; j < group.items.length; j++) {
        final item = group.items[j];
        flat.add(
          FlatNode(
            id: 'item_${item.id}',
            type: FlatNodeType.groupChild,
            group: group,
            item: item,
            parentGroupId: group.id,
            topLevelNodeIndex: i,
            childIndex: j,
          ),
        );
      }
    } else {
      final item = node.item!;
      flat.add(
        FlatNode(
          id: 'item_${item.id}',
          type: FlatNodeType.standaloneItem,
          item: item,
          topLevelNodeIndex: i,
          childIndex: -1,
        ),
      );
    }
  }
  return flat;
}

class SideMenuConfigNotifier extends Notifier<SideMenuConfig> {
  SharedPreferences? _prefs;

  @override
  SideMenuConfig build() {
    _initPrefs();
    return SideMenuConfig.defaultConfig;
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final rawJson = _prefs?.getString(_kSideMenuConfigPrefKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(rawJson);
        final loadedConfig = SideMenuConfig.fromJson(decoded);
        state = _ensureAllDefaultItemsExist(loadedConfig);
      } catch (e) {
        state = SideMenuConfig.defaultConfig;
      }
    } else {
      state = SideMenuConfig.defaultConfig;
    }
  }

  /// Ensures that all standard system items exist in the configuration.
  SideMenuConfig _ensureAllDefaultItemsExist(SideMenuConfig config) {
    final existingItemIds = <String>{};
    for (final node in config.nodes) {
      if (node.type == SideMenuNodeType.item) {
        existingItemIds.add(node.item!.id);
      } else if (node.type == SideMenuNodeType.group) {
        for (final item in node.group!.items) {
          existingItemIds.add(item.id);
        }
      }
    }

    final updatedNodes = List<SideMenuNode>.from(config.nodes);
    bool modified = false;

    for (final entry in SideMenuConfig.defaultItems.entries) {
      if (!existingItemIds.contains(entry.key)) {
        updatedNodes.add(SideMenuNode.item(entry.value));
        modified = true;
      }
    }

    return modified ? SideMenuConfig(nodes: updatedNodes) : config;
  }

  Future<void> _save(SideMenuConfig newConfig) async {
    state = newConfig;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(
      _kSideMenuConfigPrefKey,
      jsonEncode(newConfig.toJson()),
    );
  }

  void reorderFlat(int oldIndex, int newIndex) {
    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (oldIndex == targetIndex) return;

    final flat = getFlatNodes(state);
    if (oldIndex < 0 || oldIndex >= flat.length) return;

    final dragged = flat[oldIndex];

    // Case 1: Dragging a Group Header (Container as a whole)
    if (dragged.type == FlatNodeType.groupHeader) {
      final targetNode = flat[targetIndex.clamp(0, flat.length - 1)];
      int targetTopLevelIdx = targetNode.topLevelNodeIndex;
      reorderNodes(dragged.topLevelNodeIndex, targetTopLevelIdx);
      return;
    }

    // Case 2 & 3: Dragging a Menu Item (Standalone or Child)
    final SideMenuItem targetItem = dragged.item!;

    // Step A: Extract targetItem from current location
    final nodesWithoutItem = <SideMenuNode>[];
    for (final node in state.nodes) {
      if (node.type == SideMenuNodeType.item) {
        if (node.item!.id != targetItem.id) {
          nodesWithoutItem.add(node);
        }
      } else if (node.type == SideMenuNodeType.group) {
        final remainingItems = node.group!.items
            .where((item) => item.id != targetItem.id)
            .toList();
        nodesWithoutItem.add(
          SideMenuNode.group(node.group!.copyWith(items: remainingItems)),
        );
      }
    }

    final tempConfig = SideMenuConfig(nodes: nodesWithoutItem);
    final tempFlat = getFlatNodes(tempConfig);

    if (tempFlat.isEmpty) {
      _save(SideMenuConfig(nodes: [SideMenuNode.item(targetItem)]));
      return;
    }

    int adjustedTargetIndex = targetIndex.clamp(0, tempFlat.length);

    if (adjustedTargetIndex >= tempFlat.length) {
      // Landed at the very end of the list
      final lastNode = tempFlat.last;
      if (lastNode.type == FlatNodeType.groupChild ||
          lastNode.type == FlatNodeType.groupHeader) {
        // Insert at end of last group
        final groupId = lastNode.group!.id;
        _insertItemIntoGroup(tempConfig, targetItem, groupId, null);
      } else {
        // Insert as last top-level item
        final updated = List<SideMenuNode>.from(tempConfig.nodes)
          ..add(SideMenuNode.item(targetItem));
        _save(SideMenuConfig(nodes: updated));
      }
      return;
    }

    final targetFlatNode = tempFlat[adjustedTargetIndex];

    if (targetFlatNode.type == FlatNodeType.groupChild) {
      // Landed inside a group
      _insertItemIntoGroup(
        tempConfig,
        targetItem,
        targetFlatNode.parentGroupId!,
        targetFlatNode.childIndex,
      );
    } else if (targetFlatNode.type == FlatNodeType.groupHeader) {
      // Landed directly on group header -> insert as first child of group
      _insertItemIntoGroup(tempConfig, targetItem, targetFlatNode.group!.id, 0);
    } else {
      // Landed on a standalone item -> insert as top-level item at target position
      final updated = List<SideMenuNode>.from(tempConfig.nodes);
      int topIdx = targetFlatNode.topLevelNodeIndex.clamp(0, updated.length);
      updated.insert(topIdx, SideMenuNode.item(targetItem));
      _save(SideMenuConfig(nodes: updated));
    }
  }

  void _insertItemIntoGroup(
    SideMenuConfig config,
    SideMenuItem item,
    String groupId,
    int? childIndex,
  ) {
    final nodes = config.nodes.map((node) {
      if (node.type == SideMenuNodeType.group && node.group!.id == groupId) {
        final items = List<SideMenuItem>.from(node.group!.items);
        if (childIndex != null &&
            childIndex >= 0 &&
            childIndex <= items.length) {
          items.insert(childIndex, item);
        } else {
          items.add(item);
        }
        return SideMenuNode.group(node.group!.copyWith(items: items));
      }
      return node;
    }).toList();

    _save(SideMenuConfig(nodes: nodes));
  }

  void reorderNodes(int oldIndex, int newIndex) {
    var index = newIndex;
    if (oldIndex < index) {
      index -= 1;
    }
    final nodes = List<SideMenuNode>.from(state.nodes);
    if (oldIndex < 0 || oldIndex >= nodes.length) return;
    index = index.clamp(0, nodes.length);
    final movedNode = nodes.removeAt(oldIndex);
    nodes.insert(index, movedNode);
    _save(SideMenuConfig(nodes: nodes));
  }

  void reorderGroupItems(String groupId, int oldIndex, int newIndex) {
    var index = newIndex;
    if (oldIndex < index) {
      index -= 1;
    }
    final nodes = state.nodes.map((node) {
      if (node.type == SideMenuNodeType.group && node.group!.id == groupId) {
        final items = List<SideMenuItem>.from(node.group!.items);
        if (oldIndex < 0 || oldIndex >= items.length) return node;
        index = index.clamp(0, items.length);
        final movedItem = items.removeAt(oldIndex);
        items.insert(index, movedItem);
        return SideMenuNode.group(node.group!.copyWith(items: items));
      }
      return node;
    }).toList();

    _save(SideMenuConfig(nodes: nodes));
  }

  void moveItemToGroup(String itemId, String? targetGroupId) {
    SideMenuItem? targetItem;

    final updatedNodes = <SideMenuNode>[];
    for (final node in state.nodes) {
      if (node.type == SideMenuNodeType.item) {
        if (node.item!.id == itemId) {
          targetItem = node.item;
        } else {
          updatedNodes.add(node);
        }
      } else if (node.type == SideMenuNodeType.group) {
        final remainingItems = <SideMenuItem>[];
        for (final item in node.group!.items) {
          if (item.id == itemId) {
            targetItem = item;
          } else {
            remainingItems.add(item);
          }
        }
        updatedNodes.add(
          SideMenuNode.group(node.group!.copyWith(items: remainingItems)),
        );
      }
    }

    if (targetItem == null) return;

    if (targetGroupId == null) {
      updatedNodes.add(SideMenuNode.item(targetItem));
    } else {
      final finalNodes = updatedNodes.map((node) {
        if (node.type == SideMenuNodeType.group &&
            node.group!.id == targetGroupId) {
          final items = List<SideMenuItem>.from(node.group!.items)
            ..add(targetItem!);
          return SideMenuNode.group(node.group!.copyWith(items: items));
        }
        return node;
      }).toList();
      updatedNodes.clear();
      updatedNodes.addAll(finalNodes);
    }

    _save(SideMenuConfig(nodes: updatedNodes));
  }

  void toggleNodeVisibility(String nodeId) {
    final nodes = state.nodes.map((node) {
      if (node.id == nodeId) {
        return node.copyWithHidden(!node.isHidden);
      }
      return node;
    }).toList();

    _save(SideMenuConfig(nodes: nodes));
  }

  void toggleGroupItemVisibility(String groupId, String itemId) {
    final nodes = state.nodes.map((node) {
      if (node.type == SideMenuNodeType.group && node.group!.id == groupId) {
        final items = node.group!.items.map((item) {
          if (item.id == itemId) {
            return item.copyWith(isHidden: !item.isHidden);
          }
          return item;
        }).toList();
        return SideMenuNode.group(node.group!.copyWith(items: items));
      }
      return node;
    }).toList();

    _save(SideMenuConfig(nodes: nodes));
  }

  void addGroup({
    required String title,
    required String iconName,
    required bool isCollapsible,
  }) {
    final newGroup = SideMenuGroup(
      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'New Container' : title.trim(),
      iconName: iconName,
      isCollapsible: isCollapsible,
      items: const [],
    );
    final nodes = List<SideMenuNode>.from(state.nodes)
      ..add(SideMenuNode.group(newGroup));
    _save(SideMenuConfig(nodes: nodes));
  }

  void updateGroup(
    String groupId, {
    required String title,
    required String iconName,
    required bool isCollapsible,
  }) {
    final nodes = state.nodes.map((node) {
      if (node.type == SideMenuNodeType.group && node.group!.id == groupId) {
        return SideMenuNode.group(
          node.group!.copyWith(
            title: title.trim().isEmpty ? node.group!.title : title.trim(),
            iconName: iconName,
            isCollapsible: isCollapsible,
          ),
        );
      }
      return node;
    }).toList();

    _save(SideMenuConfig(nodes: nodes));
  }

  void deleteGroup(String groupId) {
    final nodes = <SideMenuNode>[];
    for (final node in state.nodes) {
      if (node.type == SideMenuNodeType.group && node.group!.id == groupId) {
        for (final item in node.group!.items) {
          nodes.add(SideMenuNode.item(item));
        }
      } else {
        nodes.add(node);
      }
    }

    _save(SideMenuConfig(nodes: nodes));
  }

  void resetToDefault() {
    _save(SideMenuConfig.defaultConfig);
  }

  /// Overwrites the side menu layout (settings import).
  void replaceConfig(SideMenuConfig config) {
    _save(_ensureAllDefaultItemsExist(config));
  }
}

final sideMenuConfigProvider =
    NotifierProvider<SideMenuConfigNotifier, SideMenuConfig>(
      SideMenuConfigNotifier.new,
    );
