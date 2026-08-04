import 'package:flutter/material.dart';

/// Shared expand/collapse state for grouped transaction lists.
mixin TransactionListCollapseMixin<T extends StatefulWidget> on State<T> {
  final Set<String> expandedGroups = {};
  bool futureExpanded = false;
  bool _defaultExpansionApplied = false;

  /// Expands only the first (most recent) group on first render; others stay collapsed.
  void ensureDefaultGroupExpansion(List<String> sortedKeys) {
    if (_defaultExpansionApplied || sortedKeys.isEmpty) return;
    _defaultExpansionApplied = true;
    expandedGroups.add(sortedKeys.first);
  }

  bool isGroupExpanded(String key) => expandedGroups.contains(key);

  void toggleGroupCollapse(String key) {
    setState(() {
      if (expandedGroups.contains(key)) {
        expandedGroups.remove(key);
      } else {
        expandedGroups.add(key);
      }
    });
  }

  void toggleFutureCollapse() {
    setState(() => futureExpanded = !futureExpanded);
  }
}
