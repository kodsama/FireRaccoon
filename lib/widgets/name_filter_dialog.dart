import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../models/account.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/autocomplete_suggestions.dart';

/// What [showNameFilterDialog] returns when the "all" row is picked, as
/// opposed to `null` for a dismissed dialog.
const allNamesSentinel = '__all__';

/// Searchable single-choice picker over [names], for filters whose options
/// can run to hundreds (accounts, tags) where a popup menu would not fit.
/// Without an [allLabel] there is no row for "all", for pickers that add
/// one name to a set rather than narrow to it.
Future<String?> showNameFilterDialog({
  required BuildContext context,
  required String title,
  required String? allLabel,
  required String emptyLabel,
  required List<String> names,
  required String? currentFilter,
  required IconData icon,
  String Function(String name)? labelOf,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _NameFilterDialog(
      title: title,
      allLabel: allLabel,
      emptyLabel: emptyLabel,
      names: names,
      currentFilter: currentFilter,
      icon: icon,
      labelOf: labelOf ?? (name) => name,
    ),
  );
}

Future<String?> showAccountFilterDialog({
  required BuildContext context,
  required WidgetRef ref,
  required List<Account> accounts,
  required String? currentFilter,
}) {
  final fun = context.funL10n(ref.read(themeProvider).isRaccoonMode);
  return showNameFilterDialog(
    context: context,
    title: fun.filterAccount,
    allLabel: fun.allAccounts,
    emptyLabel: context.l10n.noAccountsFound,
    names: accounts.map((a) => a.name).toList(),
    currentFilter: currentFilter,
    icon: LucideIcons.wallet,
  );
}

class _NameFilterDialog extends ConsumerStatefulWidget {
  final String title;
  final String? allLabel;
  final String emptyLabel;
  final List<String> names;
  final String? currentFilter;
  final IconData icon;
  final String Function(String name) labelOf;

  const _NameFilterDialog({
    required this.title,
    required this.allLabel,
    required this.emptyLabel,
    required this.names,
    required this.currentFilter,
    required this.icon,
    required this.labelOf,
  });

  @override
  ConsumerState<_NameFilterDialog> createState() => _NameFilterDialogState();
}

class _NameFilterDialogState extends ConsumerState<_NameFilterDialog> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);

    final labels = {
      for (final name in widget.names) widget.labelOf(name): name,
    };
    final sortedLabels = labels.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final filteredLabels = AutocompleteSuggestions.filterContains(
      _query,
      sortedLabels,
    );

    final allLabel = widget.allLabel;
    final showAll =
        allLabel != null &&
        (_query.isEmpty ||
            allLabel.toLowerCase().contains(_query.toLowerCase()));

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.filter,
                        size: 20,
                        color: colors.accent.acc,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.title,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 18, color: colors.text3),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: colors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: fun.search,
                  hintStyle: TextStyle(color: colors.text3),
                  prefixIcon: Icon(
                    LucideIcons.search,
                    size: 18,
                    color: colors.text3,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            LucideIcons.x,
                            size: 16,
                            color: colors.text3,
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colors.surface2,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colors.accent.acc,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (showAll) ...[
                        _NameOptionTile(
                          title: allLabel,
                          isSelected: widget.currentFilter == null,
                          icon: LucideIcons.layers,
                          onTap: () =>
                              Navigator.of(context).pop(allNamesSentinel),
                        ),
                        if (filteredLabels.isNotEmpty)
                          const Divider(height: 16),
                      ],
                      if (filteredLabels.isEmpty && !showAll)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              widget.emptyLabel,
                              style: TextStyle(
                                color: colors.text3,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ...filteredLabels.map((label) {
                          final name = labels[label]!;
                          return _NameOptionTile(
                            title: label,
                            isSelected: widget.currentFilter == name,
                            icon: widget.icon,
                            onTap: () => Navigator.of(context).pop(name),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameOptionTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _NameOptionTile({
    required this.title,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accent.acc.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? colors.accent.acc : colors.text3,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? colors.accent.acc : colors.text,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isSelected)
                Icon(LucideIcons.check, size: 16, color: colors.accent.acc),
            ],
          ),
        ),
      ),
    );
  }
}
