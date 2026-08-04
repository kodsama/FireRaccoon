import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/utils/locale_formatting.dart';
import 'package:fireracoon/widgets/account_balance_check_panel.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import '../helpers/screen_test_app.dart';

Account _paymentAccount() {
  return Account(
    id: 'pay',
    name: 'Allkonto',
    type: 'asset',
    role: 'defaultAsset',
    currentBalance: 1000,
    currencySymbol: 'kr',
    currencyCode: 'SEK',
  );
}

void main() {
  testWidgets('AccountBalanceCheckPanel shows match when balances align', (
    tester,
  ) async {
    final format = LocaleFormatting(const Locale('en'));

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: AccountBalanceCheckPanel(
          expectedBalance: 2500,
          currencySymbol: '€',
          format: format,
        ),
      ),
    );
    await pumpScreen(tester);

    expect(find.text('Check balance'), findsOneWidget);
    expect(find.text('Expected balance'), findsOneWidget);
    expect(find.textContaining('€2,500.00'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '2500');
    await tester.pump();

    expect(find.text('Balances match'), findsOneWidget);
  });

  testWidgets('AccountBalanceCheckPanel shows difference on mismatch', (
    tester,
  ) async {
    final format = LocaleFormatting(const Locale('en'));

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: AccountBalanceCheckPanel(
          expectedBalance: 2500,
          currencySymbol: '€',
          format: format,
        ),
      ),
    );
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), '2490');
    await tester.pump();

    expect(find.textContaining('Difference:'), findsOneWidget);
    expect(find.textContaining('-€10.00'), findsOneWidget);
  });

  testWidgets('AccountBalanceCheckPanel fits in compact width', (tester) async {
    final format = LocaleFormatting(const Locale('en'));

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: SizedBox(
          width: 244,
          child: AccountBalanceCheckPanel(
            expectedBalance: 2500,
            currencySymbol: '€',
            format: format,
            compact: true,
          ),
        ),
      ),
    );
    await pumpScreen(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Expected balance'), findsOneWidget);
  });

  testWidgets('reconcile is disabled when there is no pending reconcile work', (
    tester,
  ) async {
    final format = LocaleFormatting(const Locale('en'));
    var reconcileTapped = false;

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: AccountBalanceCheckPanel(
          expectedBalance: 100,
          currencySymbol: 'kr',
          format: format,
          onReconcile: () => reconcileTapped = true,
          hasPendingReconcileWork: false,
        ),
      ),
    );
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();

    expect(find.text('Balances match'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.textContaining('Nothing to reconcile'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(reconcileTapped, isFalse);
  });

  testWidgets(
    'reconcile stays enabled when pending work exists and balances match',
    (tester) async {
      final format = LocaleFormatting(const Locale('en'));
      var reconcileTapped = false;

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: AccountBalanceCheckPanel(
            expectedBalance: 100,
            currencySymbol: 'kr',
            format: format,
            onReconcile: () => reconcileTapped = true,
            hasPendingReconcileWork: true,
          ),
        ),
      );
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), '100');
      await tester.pump();

      expect(find.text('Balances match'), findsOneWidget);
      expect(find.textContaining('Nothing to reconcile'), findsNothing);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(reconcileTapped, isTrue);
    },
  );

  testWidgets(
    'reconcile is disabled while reconciling even with pending work',
    (tester) async {
      final format = LocaleFormatting(const Locale('en'));

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: AccountBalanceCheckPanel(
            expectedBalance: 100,
            currencySymbol: 'kr',
            format: format,
            onReconcile: () {},
            hasPendingReconcileWork: true,
            isReconciling: true,
          ),
        ),
      );
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), '100');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'credit-card payback disables reconcile until payment account selected',
    (tester) async {
      final format = LocaleFormatting(const Locale('en'));
      var reconcileTapped = false;

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: AccountBalanceCheckPanel(
            expectedBalance: 0,
            currencySymbol: 'kr',
            format: format,
            onReconcile: () => reconcileTapped = true,
            creditCardPayback: CreditCardPaybackFields(
              paymentAccounts: [_paymentAccount()],
              selectedPaymentAccountId: null,
              onPaymentAccountChanged: (_) {},
              paybackDate: DateTime(2026, 7, 31),
              onPaybackDateChanged: (_) {},
              paybackTotal: 100,
              hasEligiblePurchases: true,
            ),
          ),
        ),
      );
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();

      expect(find.text('Payment account'), findsOneWidget);
      expect(find.text('Payback date'), findsOneWidget);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(reconcileTapped, isFalse);
    },
  );

  testWidgets(
    'credit-card payback enables reconcile when payment account ready',
    (tester) async {
      final format = LocaleFormatting(const Locale('en'));
      var reconcileTapped = false;

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: AccountBalanceCheckPanel(
            expectedBalance: 0,
            currencySymbol: 'kr',
            format: format,
            onReconcile: () => reconcileTapped = true,
            creditCardPayback: CreditCardPaybackFields(
              paymentAccounts: [_paymentAccount()],
              selectedPaymentAccountId: 'pay',
              onPaymentAccountChanged: (_) {},
              paybackDate: DateTime(2026, 7, 31),
              onPaybackDateChanged: (_) {},
              paybackTotal: 100,
              hasEligiblePurchases: true,
            ),
          ),
        ),
      );
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();

      expect(find.textContaining('Payback:'), findsOneWidget);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(reconcileTapped, isTrue);
    },
  );

  testWidgets('AccountBalanceCheckPanel shows invalid amount status', (
    tester,
  ) async {
    final format = LocaleFormatting(const Locale('en'));

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: AccountBalanceCheckPanel(
          expectedBalance: 100,
          currencySymbol: 'kr',
          format: format,
        ),
      ),
    );
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), '..');
    await tester.pump();

    expect(find.text('Enter a valid amount'), findsOneWidget);
  });

  testWidgets(
    'credit-card payback shows warnings when accounts or purchases missing',
    (tester) async {
      final format = LocaleFormatting(const Locale('en'));

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: AccountBalanceCheckPanel(
            expectedBalance: 0,
            currencySymbol: 'kr',
            format: format,
            onReconcile: () {},
            creditCardPayback: CreditCardPaybackFields(
              paymentAccounts: const [],
              selectedPaymentAccountId: 'missing',
              onPaymentAccountChanged: (_) {},
              paybackDate: DateTime(2026, 7, 31),
              onPaybackDateChanged: (_) {},
              paybackTotal: 0,
              hasEligiblePurchases: false,
            ),
          ),
        ),
      );
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();

      expect(find.text('No eligible payment accounts'), findsOneWidget);
      expect(
        find.text('Select at least one credit card purchase'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('credit-card payback date picker updates selected date', (
    tester,
  ) async {
    final format = LocaleFormatting(const Locale('en'));
    DateTime? paybackDate = DateTime(2026, 7, 31);
    var changeCount = 0;

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: StatefulBuilder(
          builder: (context, setState) {
            return AccountBalanceCheckPanel(
              expectedBalance: 0,
              currencySymbol: 'kr',
              format: format,
              onReconcile: () {},
              creditCardPayback: CreditCardPaybackFields(
                paymentAccounts: [_paymentAccount()],
                selectedPaymentAccountId: 'pay',
                onPaymentAccountChanged: (_) {},
                paybackDate: paybackDate!,
                onPaybackDateChanged: (date) {
                  setState(() {
                    paybackDate = date;
                    changeCount++;
                  });
                },
                paybackTotal: 100,
                hasEligiblePurchases: true,
              ),
            );
          },
        ),
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(changeCount, 1);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(changeCount, 1);
  });

  testWidgets('AccountBalanceCheckToggle reflects enabled state', (
    tester,
  ) async {
    var enabled = false;

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: StatefulBuilder(
          builder: (context, setState) {
            return AccountBalanceCheckToggle(
              enabled: enabled,
              onToggle: () => setState(() => enabled = !enabled),
            );
          },
        ),
      ),
    );
    await pumpScreen(tester);

    expect(find.text('Check balance'), findsOneWidget);
    await tester.tap(find.text('Check balance'));
    await tester.pump();
    expect(enabled, isTrue);

    await tester.tap(find.text('Check balance'));
    await tester.pump();
    expect(enabled, isFalse);
  });

  test('CreditCardPaybackFields resolves selected account and readiness', () {
    final pay = _paymentAccount();
    final ready = CreditCardPaybackFields(
      paymentAccounts: [pay],
      selectedPaymentAccountId: 'pay',
      onPaymentAccountChanged: (_) {},
      paybackDate: DateTime(2026, 7, 31),
      onPaybackDateChanged: (_) {},
      paybackTotal: 50,
      hasEligiblePurchases: true,
    );
    expect(ready.isReady, isTrue);
    expect(ready.selectedPaymentAccount, same(pay));

    final missing = CreditCardPaybackFields(
      paymentAccounts: [pay],
      selectedPaymentAccountId: 'nope',
      onPaymentAccountChanged: (_) {},
      paybackDate: DateTime(2026, 7, 31),
      onPaybackDateChanged: (_) {},
      paybackTotal: 50,
      hasEligiblePurchases: true,
    );
    expect(missing.isReady, isFalse);
    expect(missing.selectedPaymentAccount, isNull);

    final none = CreditCardPaybackFields(
      paymentAccounts: [pay],
      selectedPaymentAccountId: null,
      onPaymentAccountChanged: (_) {},
      paybackDate: DateTime(2026, 7, 31),
      onPaybackDateChanged: (_) {},
      paybackTotal: 50,
      hasEligiblePurchases: true,
    );
    expect(none.isReady, isFalse);
    expect(none.selectedPaymentAccount, isNull);
  });
}
