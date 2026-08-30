import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/data_providers.dart';
import '../theme/app_theme.dart';
import 'tooltip_helpers.dart';

Future<bool?> showPayeeFormDialog({
  required BuildContext context,
  required WidgetRef ref,
  Account? payee,
  String? initialName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _PayeeFormDialog(payee: payee, initialName: initialName),
  ).then((created) {
    if (created == true) {
      ref.invalidate(payeesProvider);
      ref.invalidate(counterpartyAccountsProvider);
    }
    return created;
  });
}

class _PayeeFormDialog extends ConsumerStatefulWidget {
  final Account? payee;
  final String? initialName;

  const _PayeeFormDialog({this.payee, this.initialName});

  @override
  ConsumerState<_PayeeFormDialog> createState() => _PayeeFormDialogState();
}

class _PayeeFormDialogState extends ConsumerState<_PayeeFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.payee?.name ?? widget.initialName ?? '',
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final existingPayees = <Account>[];
    try {
      final List<Account> payees =
          ref.read(payeesProvider).value ??
          await ref.read(payeesProvider.future);
      existingPayees.addAll(payees);
    } catch (_) {}
    try {
      final List<Account> counterparties =
          ref.read(counterpartyAccountsProvider).value ??
          await ref.read(counterpartyAccountsProvider.future);
      existingPayees.addAll(counterparties);
    } catch (_) {}
    try {
      final List<Account> accounts =
          ref.read(accountsProvider).value ??
          await ref.read(accountsProvider.future);
      existingPayees.addAll(accounts);
    } catch (_) {}

    final duplicate = existingPayees.any(
      (a) =>
          a.id != widget.payee?.id &&
          a.name.trim().toLowerCase() == name.toLowerCase(),
    );

    if (duplicate) {
      if (mounted) {
        setState(() {
          _errorMessage = 'A payee named "$name" already exists.';
          _saving = false;
        });
      }
      return;
    }

    try {
      final service = ref.read(apiServiceProvider);
      if (service == null) throw Exception('Firefly API disconnected');

      if (widget.payee == null) {
        final currency = await ref.read(primaryCurrencyProvider.future);
        await service.createAccount(
          name: name,
          type: 'expense',
          currencyCode: currency.code,
        );
      } else {
        await service.updateAccount(
          widget.payee!.id,
          name: name,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
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
              ? 'A payee named "$name" already exists.'
              : 'Failed to save payee: ${errStr.replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isEdit = widget.payee != null;

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
                      isEdit ? LucideIcons.pencil : LucideIcons.store,
                      color: colors.accent.acc,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    isEdit ? 'Edit Payee' : 'New Payee',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: TextStyle(color: colors.text),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Payee / Destination Name',
                  errorText: _errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: TextStyle(color: colors.text),
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent.acc,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                        : Text(isEdit ? 'Save' : l10n.create),
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
