import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/utils/create_flows.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/dialog_test_helpers.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/ui_test_data.dart';

FakeFireflyService _fake({bool mismatchedTransferCurrency = false}) =>
    buildDialogFireflyService(
      accounts: [
        checkingAccount,
        Account(
          id: '2b',
          name: 'Savings',
          type: 'asset',
          role: 'defaultAsset',
          currentBalance: 500,
          currencySymbol: mismatchedTransferCurrency ? '\$' : '€',
          currencyCode: mismatchedTransferCurrency ? 'USD' : 'EUR',
        ),
        Account(
          id: '3',
          name: 'Salary',
          type: 'revenue',
          role: '',
          currentBalance: 0,
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
        Account(
          id: '4',
          name: 'Groceries',
          type: 'expense',
          role: '',
          currentBalance: 0,
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
      ],
    );

Finder _fieldLabeled(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _openFlow(
  WidgetTester tester, {
  required Future<void> Function(BuildContext, WidgetRef) open,
  FakeFireflyService? fireflyService,
  bool largeSurface = false,
}) async {
  allowDialogLayoutOverflow();
  if (largeSurface) {
    configureLargeScreen(tester);
  } else {
    configureDialogTestSurface(tester);
  }
  addTearDown(() => tester.view.resetPhysicalSize());

  await tester.pumpWidget(
    await buildScreenTestApp(
      child: Consumer(
        builder: (context, ref, _) {
          return ElevatedButton(
            onPressed: () => open(context, ref),
            child: const Text('Open'),
          );
        },
      ),
      fireflyService: fireflyService ?? _fake(),
      authSettings: AuthSettings(
        serverUrl: 'https://firefly.test',
        apiToken: 'token',
      ),
    ),
  );
  await settleIgnoringOverflow(tester);
  await tester.tap(find.text('Open'));
  await settleIgnoringOverflow(tester);
}

Future<void> _dismissDialog(WidgetTester tester) async {
  final cancel = find.widgetWithText(TextButton, 'Cancel');
  if (cancel.evaluate().isNotEmpty) {
    await tester.ensureVisible(cancel.last);
    await tester.tap(cancel.last, warnIfMissed: false);
    await settleIgnoringOverflow(tester);
    return;
  }
  await tester.tapAt(const Offset(8, 8));
  await settleIgnoringOverflow(tester);
}

void main() {
  testWidgets('openNewTransactionFlow covers deposit/withdrawal/transfer', (
    tester,
  ) async {
    for (final type in [
      'withdrawal',
      'deposit',
      'transfer',
      'reconciliation',
    ]) {
      await _openFlow(
        tester,
        open: (context, ref) => openNewTransactionFlow(
          context,
          ref,
          type: type,
          accountName: type == 'deposit' ? 'Checking' : null,
        ),
      );
      expect(find.byType(TextField), findsWidgets);
      await _dismissDialog(tester);
    }
  });

  testWidgets('openCreateAccountDialog asset and liability', (tester) async {
    await _openFlow(
      tester,
      open: (context, ref) =>
          openCreateAccountDialog(context, ref, accountType: 'asset'),
    );
    expect(find.byType(Dialog), findsWidgets);
    await _dismissDialog(tester);

    await _openFlow(
      tester,
      open: (context, ref) =>
          openCreateAccountDialog(context, ref, accountType: 'liability'),
    );
    expect(find.byType(Dialog), findsWidgets);
    await _dismissDialog(tester);
  });

  testWidgets('openCreateSubscriptionDialog opens form', (tester) async {
    await _openFlow(
      tester,
      open: (context, ref) => openCreateSubscriptionDialog(context, ref),
    );
    expect(find.byType(TextField), findsWidgets);
    await _dismissDialog(tester);
  });

  testWidgets('openCreateRecurringTransactionDialog opens form', (
    tester,
  ) async {
    await _openFlow(
      tester,
      open: (context, ref) =>
          openCreateRecurringTransactionDialog(context, ref),
    );
    expect(find.byType(Dialog), findsWidgets);
    await _dismissDialog(tester);
  });

  testWidgets('openCreatePiggyBankDialog opens form', (tester) async {
    await _openFlow(
      tester,
      open: (context, ref) => openCreatePiggyBankDialog(context, ref),
    );
    expect(find.byType(TextField), findsWidgets);
    await _dismissDialog(tester);
  });

  testWidgets('deposit without preferred and withdrawal with preferred', (
    tester,
  ) async {
    await _openFlow(
      tester,
      open: (context, ref) =>
          openNewTransactionFlow(context, ref, type: 'deposit'),
    );
    expect(find.byType(TextField), findsWidgets);
    await _dismissDialog(tester);

    await _openFlow(
      tester,
      open: (context, ref) => openNewTransactionFlow(
        context,
        ref,
        type: 'withdrawal',
        accountName: 'Checking',
      ),
    );
    expect(find.byType(TextField), findsWidgets);
    await _dismissDialog(tester);

    await _openFlow(
      tester,
      fireflyService: _fake(mismatchedTransferCurrency: true),
      open: (context, ref) =>
          openNewTransactionFlow(context, ref, type: 'transfer'),
    );
    expect(find.byType(TextField), findsWidgets);
    await _dismissDialog(tester);
  });

  testWidgets('completes withdrawal create and shows snackbar', (tester) async {
    await _openFlow(
      tester,
      largeSurface: true,
      open: (context, ref) => openNewTransactionFlow(
        context,
        ref,
        type: 'withdrawal',
        accountName: 'Checking',
        invalidateTransactions: true,
      ),
    );

    await tester.enterText(_fieldLabeled('Description'), 'Coffee');
    await tester.enterText(_fieldLabeled('Amount'), '4.50');
    await tester.enterText(_fieldLabeled('Asset account'), 'Checking');
    await tester.enterText(_fieldLabeled('Payee'), 'Groceries');
    await tester.pump();

    await tapDialogPrimaryAction(tester, label: 'Save');
    await settleIgnoringOverflow(tester);

    expect(find.text('Transaction created.'), findsOneWidget);
  });

  testWidgets('deposit with cash-only accounts and no revenue', (tester) async {
    final cashOnly = buildDialogFireflyService(
      accounts: [
        Account(
          id: 'cash-1',
          name: 'Wallet',
          type: 'cash',
          role: '',
          currentBalance: 20,
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
      ],
    );

    await _openFlow(
      tester,
      fireflyService: cashOnly,
      open: (context, ref) =>
          openNewTransactionFlow(context, ref, type: 'deposit'),
    );
    expect(find.byType(TextField), findsWidgets);
    await _dismissDialog(tester);
  });
}
