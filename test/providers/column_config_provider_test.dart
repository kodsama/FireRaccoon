import 'dart:convert';

import 'package:fireracoon/providers/column_config_provider.dart';
import 'package:fireracoon/providers/tight_rows_columns_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> readyAccounts() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(accountColumnConfigProvider, (_, _) {});
    addTearDown(sub.close);
    container.read(accountColumnConfigProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return container;
  }

  Future<ProviderContainer> readyTransactions() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(transactionColumnConfigProvider, (_, _) {});
    addTearDown(sub.close);
    container.read(transactionColumnConfigProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return container;
  }

  group('AccountColumnConfig', () {
    test('JSON round-trip and defaults on bad input', () {
      final original = AccountColumnConfig.defaults.copyWith(
        order: [
          AccountColumn.balance,
          AccountColumn.account,
          AccountColumn.role,
          AccountColumn.endOfMonth,
        ],
        widths: {
          ...AccountColumnConfig.defaults.widths,
          AccountColumn.account: 250,
        },
      );
      final decoded = AccountColumnConfig.fromJson(original.toJson());
      expect(decoded.order.first, AccountColumn.balance);
      expect(decoded.widths[AccountColumn.account], 250);

      expect(AccountColumnConfig.fromJson({}), AccountColumnConfig.defaults);
      expect(
        AccountColumnConfig.fromJson({
          'order': ['account'],
          'widths': {'account': 40, 'role': 'x'},
        }).widths[AccountColumn.account],
        AccountColumnConfig.minWidth,
      );
    });

    test('loads, resizes, reorders, resets, and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await readyAccounts();
      final notifier = container.read(accountColumnConfigProvider.notifier);

      notifier.resizeColumn(AccountColumn.account, 40);
      expect(
        container
            .read(accountColumnConfigProvider)
            .widths[AccountColumn.account],
        240,
      );
      notifier.resizeColumn(
        AccountColumn.account,
        0.1,
      ); // no-op under threshold

      notifier.reorderColumn(0, 2);
      expect(
        container.read(accountColumnConfigProvider).order.first,
        isNot(AccountColumn.account),
      );
      notifier.reorderColumn(1, 1);

      notifier.resetToDefaults();
      expect(
        container.read(accountColumnConfigProvider).order,
        AccountColumnConfig.defaults.order,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('account_column_config'), isNotNull);
    });

    test('loads saved config', () async {
      final saved = AccountColumnConfig.defaults.copyWith(
        widths: {
          ...AccountColumnConfig.defaults.widths,
          AccountColumn.role: 180,
        },
      );
      SharedPreferences.setMockInitialValues({
        'account_column_config': jsonEncode(saved.toJson()),
      });
      final container = await readyAccounts();
      expect(
        container.read(accountColumnConfigProvider).widths[AccountColumn.role],
        180,
      );
    });

    test('invalid saved JSON leaves defaults', () async {
      SharedPreferences.setMockInitialValues({
        'account_column_config': '{broken',
      });
      final container = await readyAccounts();
      expect(
        container.read(accountColumnConfigProvider).order,
        AccountColumnConfig.defaults.order,
      );
    });
  });

  group('TransactionColumnConfig', () {
    test('JSON round-trip and defaults on bad input', () {
      final original = TransactionColumnConfig.defaults.copyWith(
        order: [
          TightRowColumn.amount,
          ...TransactionColumnConfig.defaults.order.where(
            (c) => c != TightRowColumn.amount,
          ),
        ],
      );
      final decoded = TransactionColumnConfig.fromJson(original.toJson());
      expect(decoded.order.first, TightRowColumn.amount);
      expect(
        TransactionColumnConfig.fromJson({}),
        TransactionColumnConfig.defaults,
      );
      final partial = TransactionColumnConfig.fromJson({
        'order': ['date'],
        'widths': {'date': 200},
      });
      expect(
        partial.widths[TightRowColumn.payee],
        TransactionColumnConfig.defaults.widths[TightRowColumn.payee],
      );
    });

    test('loads, resizes, reorders, resets, and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await readyTransactions();
      final notifier = container.read(transactionColumnConfigProvider.notifier);

      notifier.resizeColumn(TightRowColumn.payee, 20);
      expect(
        container
            .read(transactionColumnConfigProvider)
            .widths[TightRowColumn.payee],
        160,
      );
      notifier.resizeColumn(TightRowColumn.payee, 0.1);

      notifier.reorderColumn(0, 3);
      expect(
        container.read(transactionColumnConfigProvider).order.first,
        isNot(TightRowColumn.date),
      );
      notifier.reorderColumn(2, 2);

      notifier.resetToDefaults();
      expect(
        container.read(transactionColumnConfigProvider).order,
        TransactionColumnConfig.defaults.order,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transaction_column_config'), isNotNull);
    });

    test('loads saved config', () async {
      final saved = TransactionColumnConfig.defaults.copyWith(
        widths: {
          ...TransactionColumnConfig.defaults.widths,
          TightRowColumn.description: 220,
        },
      );
      SharedPreferences.setMockInitialValues({
        'transaction_column_config': jsonEncode(saved.toJson()),
      });
      final container = await readyTransactions();
      expect(
        container
            .read(transactionColumnConfigProvider)
            .widths[TightRowColumn.description],
        220,
      );
    });
  });
}
