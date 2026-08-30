import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/data_providers.dart';
import '../providers/undo_history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/autocomplete_suggestions.dart';
import 'autocomplete_text_field.dart';
import 'tooltip_helpers.dart';

Future<bool?> showAccountCreateDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String accountType,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _AccountCreateDialog(accountType: accountType),
  ).then((created) {
    if (created == true) {
      ref.invalidate(accountsProvider);
    }
    return created;
  });
}

class _AccountCreateDialog extends ConsumerStatefulWidget {
  final String accountType;

  const _AccountCreateDialog({required this.accountType});

  @override
  ConsumerState<_AccountCreateDialog> createState() =>
      _AccountCreateDialogState();
}

class _AccountCreateDialogState extends ConsumerState<_AccountCreateDialog> {
  late final TextEditingController _nameController;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final existing = <Account>[];
    try {
      final List<Account> accs =
          ref.read(accountsProvider).value ??
          await ref.read(accountsProvider.future);
      existing.addAll(accs);
    } catch (_) {}
    try {
      final List<Account> payees =
          ref.read(payeesProvider).value ??
          await ref.read(payeesProvider.future);
      existing.addAll(payees);
    } catch (_) {}

    final duplicate = existing.any(
      (a) => a.name.trim().toLowerCase() == name.toLowerCase(),
    );

    if (duplicate) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An account named "$name" already exists.';
          _saving = false;
        });
      }
      return;
    }

    try {
      final currency = await ref.read(primaryCurrencyProvider.future);
      final service = ref.read(apiServiceProvider);
      final created = await service?.createAccount(
        name: name,
        type: widget.accountType,
        currencyCode: currency.code,
      );
      if (created != null) {
        ref
            .read(undoHistoryProvider.notifier)
            .record(
              title: 'Account created',
              details: 'Created account "${created.name}"',
              type: UndoActionType.accountCreate,
              undoPayload: {'accountId': created.id},
              redoPayload: {
                'name': created.name,
                'type': created.type,
                'currencyCode': created.currencyCode,
              },
            );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        final isDuplicate =
            errStr.contains('422') ||
            errStr.contains('already been taken') ||
            errStr.toLowerCase().contains('already exists');
        setState(() {
          _saving = false;
          _errorMessage = isDuplicate
              ? 'An account named "$name" already exists.'
              : context.l10n.failedToCreateAccount(
                  errStr.replaceAll('Exception: ', ''),
                );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isLiability = widget.accountType == 'liability';
    final accounts = ref.watch(accountsProvider).value ?? [];

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.accent.acc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.plus,
                      color: colors.accent.acc,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    isLiability ? l10n.newLiability : l10n.newAccount,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              withTooltip(
                l10n.tooltipAccountName,
                AutocompleteTextField(
                  controller: _nameController,
                  autofocus: true,
                  suggestions: AutocompleteSuggestions.accountNames(accounts),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: l10n.accountName,
                    errorText: _errorMessage,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.alertCircle,
                        size: 18,
                        color: colors.danger,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: colors.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  withTooltip(
                    l10n.tooltipCancel,
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  withTooltip(
                    l10n.tooltipCreate,
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent.acc,
                        foregroundColor: Colors.white,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.create),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
