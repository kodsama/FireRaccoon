import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/utils/locale_formatting.dart';
import 'package:fireraccoon/widgets/transaction_edit_panel.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../helpers/fixed_accounts_notifier.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';

Transaction _sampleTransaction({
  required String id,
  required String description,
  required double amount,
  required String currencyCode,
  required String currencySymbol,
}) {
  return Transaction(
    id: id,
    type: 'transfer',
    date: DateTime(2026, 6, 30, 22),
    amount: amount,
    description: description,
    sourceName: 'Source $id',
    destinationName: 'Destination $id',
    categoryName: 'Loan',
    currencySymbol: currencySymbol,
    currencyCode: currencyCode,
  );
}

class _TransactionEditHarness extends StatefulWidget {
  const _TransactionEditHarness({required this.initial, required this.next});

  final Transaction initial;
  final Transaction next;

  @override
  State<_TransactionEditHarness> createState() =>
      _TransactionEditHarnessState();
}

class _TransactionEditHarnessState extends State<_TransactionEditHarness> {
  late Transaction _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TransactionEditPanel(
          transaction: _current,
          embedded: false,
          onCancel: () {},
          onSave: (_) async {},
        ),
        TextButton(
          onPressed: () => setState(() => _current = widget.next),
          child: const Text('Switch transaction'),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('TransactionEditPanel reloads when transaction changes', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final loan = _sampleTransaction(
      id: 'loan-1',
      description: 'Mortgage amortization',
      amount: 3400,
      currencyCode: 'SEK',
      currencySymbol: 'kr',
    );
    final salary = _sampleTransaction(
      id: 'salary-1',
      description: 'Partner salary DKK -> DKK',
      amount: 25000,
      currencyCode: 'DKK',
      currencySymbol: 'kr.',
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: _TransactionEditHarness(initial: loan, next: salary),
      ),
    );
    await pumpScreen(tester);

    expect(find.text('Mortgage amortization'), findsOneWidget);

    await tester.tap(find.text('Switch transaction'));
    await pumpScreen(tester);

    expect(find.text('Partner salary DKK -> DKK'), findsOneWidget);
    expect(find.text('Mortgage amortization'), findsNothing);
  });

  testWidgets('a transfer can exchange its two accounts', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final transfer = Transaction(
      id: 'swap-1',
      type: 'transfer',
      date: DateTime(2026, 7, 1),
      amount: 500,
      description: 'Moving money',
      sourceName: 'Wallet',
      destinationName: 'Savings',
      categoryName: '',
      currencySymbol: 'kr',
      currencyCode: 'SEK',
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: transfer,
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );
    await pumpScreen(tester);

    TextField fieldWith(String value) => tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere((field) => field.controller?.text == value);

    // Both ends are present to begin with, each in its own field.
    expect(fieldWith('Wallet'), isNotNull);
    expect(fieldWith('Savings'), isNotNull);
    final sourceController = fieldWith('Wallet').controller!;
    final destinationController = fieldWith('Savings').controller!;

    await tester.tap(find.byIcon(LucideIcons.arrowUpDown));
    await pumpScreen(tester);

    // The same two controllers, holding each other's value.
    expect(sourceController.text, 'Savings');
    expect(destinationController.text, 'Wallet');
  });

  testWidgets('a withdrawal offers no account exchange', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final withdrawal = Transaction(
      id: 'no-swap',
      type: 'withdrawal',
      date: DateTime(2026, 7, 1),
      amount: 45,
      description: 'Groceries',
      sourceName: 'Checking',
      destinationName: 'Coop',
      categoryName: 'Food',
      currencySymbol: 'kr',
      currencyCode: 'SEK',
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: withdrawal,
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );
    await pumpScreen(tester);

    // Exchanging the ends of a withdrawal would make it a deposit, which is a
    // different transaction rather than the same one reversed.
    expect(find.byIcon(LucideIcons.arrowUpDown), findsNothing);
  });

  testWidgets('withdrawal leads with Payee and keeps currency optional', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final withdrawal = Transaction(
      id: 'w-layout',
      type: 'withdrawal',
      date: DateTime(2026, 7, 1),
      amount: 45,
      description: 'Groceries',
      sourceName: 'Checking',
      destinationName: 'Coop',
      categoryName: 'Food',
      currencySymbol: 'kr',
      currencyCode: 'SEK',
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: withdrawal,
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payee'), findsOneWidget);
    expect(find.text('Destination Account'), findsNothing);
    expect(find.text('Description'), findsOneWidget);

    // Currency is behind the optional-fields expansion when embedded.
    expect(find.text('Default Currency'), findsNothing);
    await tester.tap(find.text('Optional fields'));
    await tester.pumpAndSettle();
    expect(find.text('Default Currency'), findsOneWidget);

    final payeeY = tester.getTopLeft(find.text('Payee')).dy;
    final descriptionY = tester.getTopLeft(find.text('Description')).dy;
    final currencyY = tester.getTopLeft(find.text('Default Currency')).dy;
    expect(payeeY, lessThan(descriptionY));
    expect(descriptionY, lessThan(currencyY));
  });

  testWidgets('withdrawal destination field offers expense accounts', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final withdrawal = Transaction(
      id: 'w1',
      type: 'withdrawal',
      date: DateTime(2026, 7, 1),
      amount: 45,
      description: 'Groceries',
      sourceName: 'Checking',
      destinationName: 'Coop',
      categoryName: 'Food',
      currencySymbol: 'kr',
      currencyCode: 'SEK',
    );

    final expense = Account(
      id: 'e1',
      name: 'Coop',
      type: 'expense',
      role: '',
      currentBalance: 0,
      currencySymbol: 'kr',
      currencyCode: 'SEK',
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: withdrawal,
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
        fireflyService: FakeFireflyService(
          accounts: [...sampleAccounts, expense],
          transactions: [withdrawal],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The current expense destination must be resolvable and shown, not a
    // blank frozen field.
    expect(find.text('Coop'), findsWidgets);
  });

  testWidgets('shows date without time even when transaction has a time', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final format = LocaleFormatting(const Locale('en'));
    final dated = DateTime(2026, 6, 30, 22, 45);
    final tx = Transaction(
      id: 't1',
      type: 'withdrawal',
      date: dated,
      amount: 12,
      description: 'Coffee',
      sourceName: 'Checking',
      destinationName: 'Cafe',
      categoryName: 'Food',
      currencySymbol: 'kr',
      currencyCode: 'SEK',
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: tx,
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(format.formatMediumDate(dated)), findsOneWidget);
    expect(find.text(format.formatDateTime(dated)), findsNothing);
  });

  testWidgets('picking a date does not open a time picker', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final format = LocaleFormatting(const Locale('en'));
    final dated = DateTime(2026, 6, 30, 22, 45);
    final tx = Transaction(
      id: 't2',
      type: 'withdrawal',
      date: dated,
      amount: 12,
      description: 'Coffee',
      sourceName: 'Checking',
      destinationName: 'Cafe',
      categoryName: 'Food',
      currencySymbol: 'kr',
      currencyCode: 'SEK',
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: tx,
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(format.formatMediumDate(dated)));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.byType(TimePickerDialog), findsNothing);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.text(format.formatMediumDate(dated)), findsOneWidget);
    expect(find.text(format.formatDateTime(dated)), findsNothing);
  });

  Transaction splitTransaction() {
    final food = Transaction(
      id: 'split-1',
      type: 'withdrawal',
      date: DateTime(2026, 7, 1),
      amount: 40,
      description: 'Food',
      sourceName: 'Checking',
      destinationName: 'Store',
      categoryName: 'Groceries',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );
    final clothes = Transaction(
      id: 'split-1',
      type: 'withdrawal',
      date: DateTime(2026, 7, 1),
      amount: 60,
      description: 'Clothes',
      sourceName: 'Checking',
      destinationName: 'Store',
      categoryName: 'Shopping',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );
    return food.copyWith(groupTitle: 'Shopping trip', splits: [food, clothes]);
  }

  testWidgets('split edit exposes editable total amount', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: splitTransaction(),
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total amount'), findsOneWidget);
    expect(find.byKey(const ValueKey('split_main_amount')), findsOneWidget);

    final mainAmount = find.descendant(
      of: find.byKey(const ValueKey('split_main_amount')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(mainAmount).controller?.text, '100');

    await tester.enterText(mainAmount, '120');
    await tester.pump();

    expect(tester.widget<TextField>(mainAmount).controller?.text, '120');
    expect(find.textContaining('Remainder'), findsOneWidget);
  });

  testWidgets('split save blocked when total does not match split sum', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    var saved = false;
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: splitTransaction(),
              onCancel: () {},
              onSave: (_) async {
                saved = true;
              },
            ),
          ),
        ),
        fireflyService: FakeFireflyService(
          accounts: sampleAccounts,
          transactions: [splitTransaction()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mainAmount = find.descendant(
      of: find.byKey(const ValueKey('split_main_amount')),
      matching: find.byType(TextField),
    );
    await tester.enterText(mainAmount, '120');
    await tester.pump();

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saved, isFalse);
    expect(find.text('Split amounts must total €120.00.'), findsOneWidget);
  });

  testWidgets('split save succeeds when total matches split sum', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    Transaction? saved;
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: splitTransaction(),
              onCancel: () {},
              onSave: (tx) async {
                saved = tx;
              },
            ),
          ),
        ),
        fireflyService: FakeFireflyService(
          accounts: sampleAccounts,
          transactions: [splitTransaction()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mainAmount = find.descendant(
      of: find.byKey(const ValueKey('split_main_amount')),
      matching: find.byType(TextField),
    );
    await tester.enterText(mainAmount, '120');
    await tester.pump();

    // Split amounts are 40 and 60; raise the first to 60 so sum is 120.
    final firstSplitAmount = find.widgetWithText(TextField, '40.0');
    expect(firstSplitAmount, findsOneWidget);
    await tester.enterText(firstSplitAmount, '60');
    await tester.pump();

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.totalAmount, 120);
  });

  testWidgets('an expense counterparty does not make a spend foreign', (
    tester,
  ) async {
    // Firefly reports every counterparty in the installation's primary
    // currency whether or not one was set, and says which through
    // object_has_currency_setting. Taken at face value, a EUR spend on an SEK
    // installation looked like a currency crossing: the panel demanded a
    // foreign amount and refused to save without one, so the write never left
    // the app.
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final asset = Account(
      id: '10328',
      name: 'Revolut EUR',
      type: 'asset',
      role: 'defaultAsset',
      currentBalance: 500,
      currencySymbol: '€',
      currencyCode: 'EUR',
    );
    final counterparty = Account(
      id: '12581',
      name: 'Fabrica Do Meu Avo',
      type: 'expense',
      role: 'defaultAsset',
      currentBalance: 0,
      currencySymbol: 'kr',
      currencyCode: 'SEK',
      hasCurrencySetting: false,
    );

    final spend = Transaction(
      id: '111770',
      type: 'withdrawal',
      date: DateTime(2026, 8, 30),
      amount: 4.30,
      description: 'Lunch',
      sourceName: asset.name,
      destinationName: counterparty.name,
      categoryName: '',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );

    Transaction? saved;
    await tester.pumpWidget(
      await buildScreenTestApp(
        fireflyService: FakeFireflyService(accounts: [asset, counterparty]),
        extraOverrides: [
          accountsProvider.overrideWith(() => FixedAccountsNotifier([asset])),
          counterpartyAccountsProvider.overrideWith((ref) => [counterparty]),
        ],
        child: Material(
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: spend,
              onCancel: () {},
              onSave: (result) async => saved = result,
            ),
          ),
        ),
      ),
    );
    await pumpScreen(tester);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    // The spend leaves the app rather than stopping at a demand for a second
    // amount, and it carries no foreign amount, because there is no second
    // currency on it to carry.
    expect(saved, isNotNull);
    expect(saved!.foreignAmount, isNull);
  });

  testWidgets('a deposit source resolves to the revenue twin', (tester) async {
    // Firefly keeps an expense and a revenue account under one name for the
    // same counterparty. Matching on name alone returned whichever came first,
    // so a deposit could be saved with the expense twin's id and Firefly
    // refused the whole write: "Could not find a valid source account when
    // searching for ID ... or name ...", repeated once per candidate field.
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final asset = Account(
      id: '1',
      name: 'Revolut EUR',
      type: 'asset',
      role: 'defaultAsset',
      currentBalance: 500,
      currencySymbol: '\u20AC',
      currencyCode: 'EUR',
    );
    final expenseTwin = Account(
      id: '11553',
      name: 'Akademikernas a-kassa',
      type: 'expense',
      role: 'defaultAsset',
      currentBalance: 0,
      currencySymbol: '\u20AC',
      currencyCode: 'EUR',
    );
    final revenueTwin = Account(
      id: '20001',
      name: 'Akademikernas a-kassa',
      type: 'revenue',
      role: 'defaultAsset',
      currentBalance: 0,
      currencySymbol: '\u20AC',
      currencyCode: 'EUR',
    );

    final deposit = Transaction(
      id: '900',
      type: 'deposit',
      date: DateTime(2026, 8, 30),
      amount: 1200,
      description: 'A-kassa',
      sourceName: revenueTwin.name,
      destinationName: asset.name,
      categoryName: '',
      currencySymbol: '\u20AC',
      currencyCode: 'EUR',
    );

    Transaction? saved;
    await tester.pumpWidget(
      await buildScreenTestApp(
        fireflyService: FakeFireflyService(
          accounts: [asset, expenseTwin, revenueTwin],
        ),
        extraOverrides: [
          accountsProvider.overrideWith(() => FixedAccountsNotifier([asset])),
          // Expense first, so a name-only match reaches for the wrong one.
          counterpartyAccountsProvider.overrideWith(
            (ref) => [expenseTwin, revenueTwin],
          ),
        ],
        child: Material(
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: deposit,
              onCancel: () {},
              onSave: (result) async => saved = result,
            ),
          ),
        ),
      ),
    );
    await pumpScreen(tester);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.sourceId, '20001');
  });

  testWidgets('a split shows one date, with the group fields', (tester) async {
    // The date is held once and written to every split, so showing it inside
    // the first split's fields read as though it belonged to that split alone
    // while it quietly governed the rest.
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: splitTransaction(),
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Date')).dy,
      lessThan(tester.getTopLeft(find.text('Split 1')).dy),
    );
  });
}
