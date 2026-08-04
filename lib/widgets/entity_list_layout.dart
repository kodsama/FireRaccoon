import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/view_mode_provider.dart';
import '../theme/app_theme.dart';

/// Switches between a bordered compact list and a spaced grid of cards.
class EntityListLayout extends ConsumerWidget {
  final List<Widget> gridItems;
  final List<Widget> compactItems;
  final List<Widget>? tightItems;
  final Widget? tightHeader;

  const EntityListLayout({
    super.key,
    required this.gridItems,
    required this.compactItems,
    this.tightItems,
    this.tightHeader,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final viewMode = ref.watch(viewModeProvider);

    if (viewMode == ViewMode.tight) {
      final items = tightItems ?? compactItems;
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        child: Column(
          children: [
            ?tightHeader,
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  Divider(color: colors.border, height: 1),
              itemBuilder: (context, index) => items[index],
            ),
          ],
        ),
      );
    }

    if (viewMode == ViewMode.compact) {
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: compactItems.length,
          separatorBuilder: (context, index) =>
              Divider(color: colors.border, height: 1),
          itemBuilder: (context, index) => compactItems[index],
        ),
      );
    }

    return Wrap(spacing: 16, runSpacing: 16, children: gridItems);
  }
}
