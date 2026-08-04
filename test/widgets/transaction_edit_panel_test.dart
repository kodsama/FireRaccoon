import 'package:fireracoon/utils/locale_formatting.dart';
import 'package:fireracoon/widgets/transaction_edit_panel.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
