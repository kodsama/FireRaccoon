import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/data_providers.dart';
import '../providers/undo_history_provider.dart';
import '../widgets/account_create_dialog.dart';
import '../widgets/budget_create_dialog.dart';
import '../widgets/piggy_bank_form_dialog.dart';
import '../widgets/liability_create_dialog.dart';
import '../widgets/recurring_transaction_form_dialog.dart';
import '../widgets/subscription_form_dialog.dart';
import '../widgets/transaction_edit_panel.dart';
import '../widgets/transaction_entity_card.dart';

final _log = AppLogger.scoped('flows.create');

Account? _firstAccount(
  Iterable<Account> accounts,
  bool Function(Account) test,
) {
  return accounts.where(test).firstOrNull;
}

Transaction _transactionTemplateForType({
  required String type,
  required List<Account> accounts,
  required String currencySymbol,
  required String currencyCode,
  Account? preferredAccount,
}) {
  final assetLike = _firstAccount(
    accounts,
    (a) => a.type == 'asset' || a.type == 'cash',
  );
  final revenue = _firstAccount(accounts, (a) => a.type == 'revenue');
  final expense = _firstAccount(accounts, (a) => a.type == 'expense');

  return switch (type) {
    'deposit' => () {
      final destination =
          preferredAccount ??
          _firstAccount(
            accounts,
            (a) =>
                (a.type == 'asset' || a.type == 'cash') &&
                (revenue == null || a.currencyCode == revenue.currencyCode),
          ) ??
          assetLike;
      final symbol = destination?.currencySymbol ?? currencySymbol;
      final code = destination?.currencyCode ?? currencyCode;
      return newTransactionTemplate(
        currencySymbol: symbol,
        currencyCode: code,
        type: 'deposit',
        sourceName: revenue?.name,
        sourceId: revenue?.id,
        destinationName: destination?.name,
        destinationId: destination?.id,
      );
    }(),
    'withdrawal' => newTransactionTemplate(
      currencySymbol: preferredAccount?.currencySymbol ?? currencySymbol,
      currencyCode: preferredAccount?.currencyCode ?? currencyCode,
      type: 'withdrawal',
      sourceName: preferredAccount?.name ?? assetLike?.name,
      sourceId: preferredAccount?.id ?? assetLike?.id,
      destinationName: expense?.name,
      destinationId: expense?.id,
    ),
    'transfer' => () {
      final assets = accounts.where((a) => a.type == 'asset').toList();
      final source = preferredAccount?.type == 'asset'
          ? preferredAccount
          : assets.firstOrNull ?? assetLike;
      final destination =
          assets
              .where((a) => a.id != source?.id)
              .where((a) => a.currencyCode == source?.currencyCode)
              .firstOrNull ??
          assets.where((a) => a.id != source?.id).firstOrNull;
      final symbol = source?.currencySymbol ?? currencySymbol;
      final code = source?.currencyCode ?? currencyCode;
      return newTransactionTemplate(
        currencySymbol: symbol,
        currencyCode: code,
        type: 'transfer',
        sourceName: source?.name,
        sourceId: source?.id,
        destinationName: destination?.name,
        destinationId: destination?.id,
      );
    }(),
    _ => newTransactionTemplate(
      currencySymbol: currencySymbol,
      currencyCode: currencyCode,
      type: type,
    ),
  };
}

Future<void> openNewTransactionFlow(
  BuildContext context,
  WidgetRef ref, {
  required String type,
  String? accountName,
  bool invalidateTransactions = false,
  String? filterAccount,
  bool lockType = true,
}) async {
  final l10n = context.l10n;
  _log.info(
    'Open new transaction flow (type=$type, accountName=$accountName, '
    'invalidateTransactions=$invalidateTransactions, filterAccount=$filterAccount)',
  );
  try {
    final currency = await ref.read(primaryCurrencyProvider.future);
    final accounts = await ref.read(accountsProvider.future);
    final preferred = accountName != null
        ? accounts.where((a) => a.name == accountName).firstOrNull
        : null;

    final initial = _transactionTemplateForType(
      type: type,
      accounts: accounts,
      currencySymbol: preferred?.currencySymbol ?? currency.symbol,
      currencyCode: preferred?.currencyCode ?? currency.code,
      preferredAccount: preferred,
    );

    if (!context.mounted) return;

    final created = await showNewTransactionDialog(
      context: context,
      ref: ref,
      initial: initial,
      lockedType: lockType ? type : null,
      onCreate: (transaction) async {
        final service = ref.read(apiServiceProvider);
        _log.fine(
          'Submitting transaction create (type=${transaction.type}, '
          'amount=${transaction.amount}, source=${transaction.sourceId}, '
          'destination=${transaction.destinationId})',
        );
        final created = await service?.createTransaction(transaction);
        if (created != null) {
          ref
              .read(undoHistoryProvider.notifier)
              .record(
                title: 'Transaction created',
                details: 'Created transaction "${created.description}"',
                type: UndoActionType.transactionCreate,
                undoPayload: {'transactionId': created.id},
                redoPayload: transactionUndoPayload(created),
              );
        }
        if (invalidateTransactions) {
          await refreshTransactionLists(ref, filterAccount, upsert: created);
          _log.finer('Patched transaction caches after transaction create');
        }
      },
    );

    if (created == true && context.mounted) {
      _log.info('Transaction create flow completed successfully');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.transactionCreated)));
    }
  } catch (e) {
    // coverage:ignore-start
    _log.warning('Transaction create flow failed: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToCreateTransaction(e.toString()))),
      );
    }
    // coverage:ignore-end
  }
}

Future<void> openCreateAccountDialog(
  BuildContext context,
  WidgetRef ref, {
  required String accountType,
}) async {
  _log.info('Open account create flow (accountType=$accountType)');
  if (accountType == 'liability') {
    final created = await showLiabilityCreateDialog(context: context, ref: ref);
    if (created == true) {
      _log.info('Liability created successfully');
    }
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.liabilityCreated)));
    }
    return;
  }

  final created = await showAccountCreateDialog(
    context: context,
    ref: ref,
    accountType: accountType,
  );
  // coverage:ignore-start
  if (created == true) {
    _log.info('Account created successfully (accountType=$accountType)');
  }
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.accountCreated)));
  }
  // coverage:ignore-end
}

Future<void> openCreateBudgetDialog(BuildContext context, WidgetRef ref) async {
  _log.info('Open budget create flow');
  final created = await showBudgetCreateDialog(context: context, ref: ref);
  if (created == true) {
    _log.info('Budget created successfully');
  }
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.budgetCreated)));
  }
}

Future<void> openCreateSubscriptionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  _log.info('Open subscription create flow');
  final created = await showSubscriptionFormDialog(context: context, ref: ref);
  if (created == true) {
    _log.info('Subscription created successfully');
  }
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.subscriptionCreated)));
  }
}

Future<void> openCreateRecurringTransactionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  _log.info('Open recurring transaction create flow');
  final created = await showRecurringTransactionFormDialog(
    context: context,
    ref: ref,
  );
  if (created == true) {
    _log.info('Recurring transaction created successfully');
  }
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.recurringTransactionCreated)),
    );
  }
}

Future<void> openCreatePiggyBankDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  _log.info('Open piggy bank create flow');
  final created = await showPiggyBankFormDialog(context: context, ref: ref);
  if (created == true) {
    _log.info('Piggy bank created successfully');
  }
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.piggyBankCreated)));
  }
}
