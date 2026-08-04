import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../providers/data_providers.dart';
import '../providers/paginated_transactions_provider.dart';
import '../theme/app_theme.dart';
import 'confirmation_dialog.dart';

enum EntityLinkingSourceType { payee, category, tag }

enum EntityLinkingTargetType { category, tag, budget }

extension EntityLinkingSourceTypeX on EntityLinkingSourceType {
  String get label {
    switch (this) {
      case EntityLinkingSourceType.payee:
        return 'Payee';
      case EntityLinkingSourceType.category:
        return 'Category';
      case EntityLinkingSourceType.tag:
        return 'Tag';
    }
  }
}

extension EntityLinkingTargetTypeX on EntityLinkingTargetType {
  String get label {
    switch (this) {
      case EntityLinkingTargetType.category:
        return 'Category';
      case EntityLinkingTargetType.tag:
        return 'Tag';
      case EntityLinkingTargetType.budget:
        return 'Budget';
    }
  }
}

void showEntityLinkingDialog({
  required BuildContext context,
  required WidgetRef ref,
  required EntityLinkingSourceType sourceType,
  required String sourceName,
}) {
  showDialog(
    context: context,
    builder: (ctx) =>
        _EntityLinkingDialog(sourceType: sourceType, sourceName: sourceName),
  );
}

class _EntityLinkingDialog extends ConsumerStatefulWidget {
  final EntityLinkingSourceType sourceType;
  final String sourceName;

  const _EntityLinkingDialog({
    required this.sourceType,
    required this.sourceName,
  });

  @override
  ConsumerState<_EntityLinkingDialog> createState() =>
      __EntityLinkingDialogState();
}

class __EntityLinkingDialogState extends ConsumerState<_EntityLinkingDialog> {
  EntityLinkingTargetType _targetType = EntityLinkingTargetType.category;
  String? _selectedTargetName;
  String? _selectedTargetId;
  bool _applyToRecurring = true;
  bool _isSaving = false;

  bool _matchesSource(Transaction tx) {
    switch (widget.sourceType) {
      case EntityLinkingSourceType.payee:
        return tx.sourceName == widget.sourceName ||
            tx.destinationName == widget.sourceName ||
            tx.resolvedSplits().any(
              (s) =>
                  s.sourceName == widget.sourceName ||
                  s.destinationName == widget.sourceName,
            );
      case EntityLinkingSourceType.category:
        return categoryGroupKey(tx.categoryName) ==
            categoryGroupKey(widget.sourceName);
      case EntityLinkingSourceType.tag:
        return tx.tags.contains(widget.sourceName);
    }
  }

  bool _matchesSourceRecurrence(Recurrence rec) {
    final tx = rec.primaryTransaction;
    if (tx == null) return false;
    switch (widget.sourceType) {
      case EntityLinkingSourceType.payee:
        return tx.sourceName == widget.sourceName ||
            tx.destinationName == widget.sourceName;
      case EntityLinkingSourceType.category:
        return categoryGroupKey(tx.categoryName) ==
            categoryGroupKey(widget.sourceName);
      case EntityLinkingSourceType.tag:
        return tx.tags.contains(widget.sourceName);
    }
  }

  RecurrenceInput _buildRecurrenceInput(
    Recurrence rec, {
    String? categoryId,
    String? budgetId,
    List<String>? tags,
  }) {
    final primaryTx = rec.primaryTransaction;
    final updatedTags = tags ?? primaryTx?.tags ?? const <String>[];

    final txInput = RecurrenceTransactionInput(
      id: primaryTx?.id,
      description: primaryTx?.description ?? rec.title,
      amount: primaryTx?.amount ?? 0,
      currencyCode: primaryTx?.currencyCode ?? 'EUR',
      sourceId: primaryTx?.sourceId ?? '',
      destinationId: primaryTx?.destinationId ?? '',
      categoryId: categoryId ?? primaryTx?.categoryId,
      budgetId: budgetId ?? primaryTx?.budgetId,
      tags: updatedTags,
    );

    final repInputs = rec.repetitions
        .map(
          (r) => RecurrenceRepetitionInput(
            type: r.type,
            moment: r.moment,
            skip: r.skip,
            weekend: r.weekend,
          ),
        )
        .toList();

    return RecurrenceInput(
      type: rec.type,
      title: rec.title,
      description: rec.description,
      firstDate: rec.firstDate,
      repeatUntil: rec.repeatUntil,
      nrOfRepetitions: rec.nrOfRepetitions,
      applyRules: rec.applyRules,
      active: rec.active,
      notes: rec.notes,
      repetitions: repInputs,
      transactions: [txInput],
    );
  }

  Future<void> _applyLink(
    List<Transaction> impactedTxs,
    List<Recurrence> impactedRecs,
  ) async {
    final targetName = _selectedTargetName?.trim();
    if (targetName == null || targetName.isEmpty) return;

    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Confirm Bulk Link & Assign',
      message:
          'You are about to assign ${_targetType.label} "$targetName" to ${impactedTxs.length} transaction(s)'
          '${_applyToRecurring && impactedRecs.isNotEmpty ? " and ${impactedRecs.length} recurring transaction(s)" : ""}'
          ' matching ${widget.sourceType.label} "${widget.sourceName}".',
      confirmLabel: 'Apply Bulk Link',
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    final service = ref.read(apiServiceProvider);
    if (service == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    try {
      int txUpdatedCount = 0;
      for (final tx in impactedTxs) {
        Transaction updated;
        switch (_targetType) {
          case EntityLinkingTargetType.category:
            updated = tx.copyWith(
              categoryName: targetName,
              categoryId: _selectedTargetId,
            );
            break;
          case EntityLinkingTargetType.tag:
            final updatedTags = List<String>.from(tx.tags);
            if (!updatedTags.contains(targetName)) {
              updatedTags.add(targetName);
            }
            updated = tx.copyWith(tags: updatedTags);
            break;
          case EntityLinkingTargetType.budget:
            updated = tx.copyWith(
              budgetName: targetName,
              budgetId: _selectedTargetId,
            );
            break;
        }
        await service.updateTransaction(updated);
        txUpdatedCount++;
      }

      int recUpdatedCount = 0;
      if (_applyToRecurring) {
        for (final rec in impactedRecs) {
          RecurrenceInput input;
          switch (_targetType) {
            case EntityLinkingTargetType.category:
              input = _buildRecurrenceInput(rec, categoryId: _selectedTargetId);
              break;
            case EntityLinkingTargetType.tag:
              final currentTags =
                  rec.primaryTransaction?.tags ?? const <String>[];
              final updatedTags = List<String>.from(currentTags);
              if (!updatedTags.contains(targetName)) {
                updatedTags.add(targetName);
              }
              input = _buildRecurrenceInput(rec, tags: updatedTags);
              break;
            case EntityLinkingTargetType.budget:
              input = _buildRecurrenceInput(rec, budgetId: _selectedTargetId);
              break;
          }
          await service.updateRecurrence(rec.id, input);
          recUpdatedCount++;
        }
      }

      ref.invalidate(transactionsProvider);
      ref.invalidate(paginatedTransactionsProvider);
      ref.invalidate(counterpartyAccountsProvider);
      ref.invalidate(payeesProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(tagsProvider);
      ref.invalidate(budgetsProvider);
      ref.invalidate(recurrencesProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully linked and updated $txUpdatedCount transaction(s)'
              '${recUpdatedCount > 0 ? " and $recUpdatedCount recurring transaction(s)" : ""}'
              '!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to apply link: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final transactionsAsync = ref.watch(transactionsProvider);
    final recurrencesAsync = ref.watch(recurrencesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final budgetsAsync = ref.watch(budgetsProvider);

    final allTransactions = transactionsAsync.value ?? const <Transaction>[];
    final allRecurrences = recurrencesAsync.value ?? const <Recurrence>[];

    final matchingTransactions = allTransactions.where(_matchesSource).toList();
    final matchingRecurrences = allRecurrences
        .where(_matchesSourceRecurrence)
        .toList();

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
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
                      LucideIcons.link2,
                      color: colors.accent.acc,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Link ${widget.sourceType.label}: "${widget.sourceName}"',
                          style: TextStyle(
                            fontFamily: 'Comfortaa',
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Auto-assign budget, category, or tag to matching transactions.',
                          style: TextStyle(color: colors.text3, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Target Type Selection
              Text(
                'Target Attribute to Assign',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colors.text2,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<EntityLinkingTargetType>(
                segments: const [
                  ButtonSegment(
                    value: EntityLinkingTargetType.category,
                    label: Text('Category'),
                    icon: Icon(LucideIcons.folder, size: 16),
                  ),
                  ButtonSegment(
                    value: EntityLinkingTargetType.tag,
                    label: Text('Tag'),
                    icon: Icon(LucideIcons.tag, size: 16),
                  ),
                  ButtonSegment(
                    value: EntityLinkingTargetType.budget,
                    label: Text('Budget'),
                    icon: Icon(LucideIcons.piggyBank, size: 16),
                  ),
                ],
                selected: {_targetType},
                onSelectionChanged: (selection) {
                  setState(() {
                    _targetType = selection.first;
                    _selectedTargetName = null;
                    _selectedTargetId = null;
                  });
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? colors.accent.acc
                        : colors.surface,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : colors.text2,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Target Selection Dropdown
              Text(
                'Select Target ${_targetType.label}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colors.text2,
                ),
              ),
              const SizedBox(height: 8),
              if (_targetType == EntityLinkingTargetType.category)
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed to load categories: $e'),
                  data: (categories) {
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedTargetName,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                      items: categories.map((c) {
                        return DropdownMenuItem(
                          value: c.name,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedTargetName = val;
                          _selectedTargetId = categories
                              .where((c) => c.name == val)
                              .firstOrNull
                              ?.id;
                        });
                      },
                      hint: const Text('Choose category...'),
                    );
                  },
                )
              else if (_targetType == EntityLinkingTargetType.tag)
                tagsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed to load tags: $e'),
                  data: (tags) {
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedTargetName,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                      items: tags.map((t) {
                        return DropdownMenuItem(
                          value: t.name,
                          child: Text('#${t.name}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedTargetName = val;
                          _selectedTargetId = tags
                              .where((t) => t.name == val)
                              .firstOrNull
                              ?.id;
                        });
                      },
                      hint: const Text('Choose tag...'),
                    );
                  },
                )
              else
                budgetsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed to load budgets: $e'),
                  data: (budgets) {
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedTargetName,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                      items: budgets.map((b) {
                        return DropdownMenuItem(
                          value: b.name,
                          child: Text(b.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedTargetName = val;
                          _selectedTargetId = budgets
                              .where((b) => b.name == val)
                              .firstOrNull
                              ?.id;
                        });
                      },
                      hint: const Text('Choose budget...'),
                    );
                  },
                ),
              const SizedBox(height: 16),

              // Apply to recurring transactions toggle
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Apply to recurring transactions / subscriptions',
                  style: TextStyle(fontSize: 14),
                ),
                value: _applyToRecurring,
                onChanged: (val) =>
                    setState(() => _applyToRecurring = val ?? true),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: colors.accent.acc,
              ),
              const SizedBox(height: 16),

              // Impact Analysis Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.accent.acc.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.accent.acc.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.info,
                          color: colors.accent.acc,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Impact Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: colors.accent.acc,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Matching Transactions:',
                          style: TextStyle(fontSize: 13, color: colors.text2),
                        ),
                        Text(
                          '${matchingTransactions.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Matching Recurring Transactions:',
                          style: TextStyle(fontSize: 13, color: colors.text2),
                        ),
                        Text(
                          _applyToRecurring
                              ? '${matchingRecurrences.length}'
                              : '0 (disabled)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Target to Assign:',
                          style: TextStyle(fontSize: 13, color: colors.text2),
                        ),
                        Text(
                          _selectedTargetName != null
                              ? '${_targetType.label}: "$_selectedTargetName"'
                              : 'Not selected',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _selectedTargetName != null
                                ? colors.text
                                : colors.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.link2, size: 16),
                    label: Text(_isSaving ? 'Applying...' : 'Apply Link'),
                    onPressed:
                        (_isSaving ||
                            _selectedTargetName == null ||
                            _selectedTargetName!.trim().isEmpty)
                        ? null
                        : () => _applyLink(
                            matchingTransactions,
                            matchingRecurrences,
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent.acc,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
