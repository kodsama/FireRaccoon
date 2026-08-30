import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../models/account.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/autocomplete_suggestions.dart';

const allAccountsSentinel = '__all__';

Future<String?> showAccountFilterDialog({
  required BuildContext context,
  required WidgetRef ref,
  required List<Account> accounts,
  required String? currentFilter,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) =>
        _AccountFilterDialog(accounts: accounts, currentFilter: currentFilter),
  );
}

class _AccountFilterDialog extends ConsumerStatefulWidget {
  final List<Account> accounts;
  final String? currentFilter;

  const _AccountFilterDialog({
    required this.accounts,
    required this.currentFilter,
  });

  @override
  ConsumerState<_AccountFilterDialog> createState() =>
      _AccountFilterDialogState();
}

class _AccountFilterDialogState extends ConsumerState<_AccountFilterDialog> {
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
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);

    final sortedAccounts = List<Account>.from(widget.accounts)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final filteredNames = AutocompleteSuggestions.filterContains(
      _query,
      sortedAccounts.map((a) => a.name),
    );

    final showAllAccounts =
        _query.isEmpty ||
        fun.allAccounts.toLowerCase().contains(_query.toLowerCase());

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
                        fun.filterAccount,
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
                      if (showAllAccounts) ...[
                        _AccountOptionTile(
                          title: fun.allAccounts,
                          isSelected: widget.currentFilter == null,
                          icon: LucideIcons.layers,
                          onTap: () =>
                              Navigator.of(context).pop(allAccountsSentinel),
                        ),
                        if (filteredNames.isNotEmpty) const Divider(height: 16),
                      ],
                      if (filteredNames.isEmpty && !showAllAccounts)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              l10n.noAccountsFound,
                              style: TextStyle(
                                color: colors.text3,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ...filteredNames.map((accountName) {
                          final isSelected =
                              widget.currentFilter == accountName;
                          return _AccountOptionTile(
                            title: accountName,
                            isSelected: isSelected,
                            icon: LucideIcons.wallet,
                            onTap: () => Navigator.of(context).pop(accountName),
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

class _AccountOptionTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _AccountOptionTile({
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
