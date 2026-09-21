import 'package:flutter/material.dart';
import 'package:fireraccoon/providers/view_mode_provider.dart';
import 'package:fireraccoon/screens/prognosis_screen.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';

Account _account({
  required String id,
  required String name,
  bool active = true,
}) => Account(
  id: id,
  name: name,
  type: 'asset',
  role: 'defaultAsset',
  currentBalance: 1000,
  currencySymbol: '€',
  currencyCode: 'EUR',
  active: active,
);

Transaction _tx(String accountName) => Transaction(
  id: 't-$accountName',
  type: 'withdrawal',
  date: DateTime.now().subtract(const Duration(days: 5)),
  amount: 25,
  description: 'Groceries',
  sourceName: accountName,
  destinationName: 'Store',
  categoryName: 'Food',
  currencySymbol: '€',
  currencyCode: 'EUR',
);

void main() {
  testWidgets(
    'PrognosisScreen offers open accounts and leaves out closed ones',
    (tester) async {
      configureLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      // A closed account has nothing ahead of it, so a forecast of it is a
      // forecast of nothing.
      final accounts = [
        _account(id: '1', name: 'Everyday'),
        _account(id: '2', name: 'Old Savings', active: false),
      ];
      final transactions = [_tx('Everyday'), _tx('Old Savings')];

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: const PrognosisScreen(),
          fireflyService: FakeFireflyService(
            accounts: accounts,
            transactions: transactions,
            transactionPages: {
              1: TransactionPageResult(
                transactions: transactions,
                currentPage: 1,
                totalPages: 1,
                total: transactions.length,
              ),
            },
          ),
          viewMode: ViewMode.compact,
        ),
      );
      await pumpScreen(tester);

      final field = find.byType(DropdownMenu<String>);
      expect(field, findsOneWidget);

      final offered = tester
          .widget<DropdownMenu<String>>(field)
          .dropdownMenuEntries
          .map((entry) => entry.label)
          .toList();
      expect(offered, contains('Everyday'));
      expect(offered, isNot(contains('Old Savings')));
    },
  );

  testWidgets('the horizon runs from two weeks to a day of your own', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final accounts = [_account(id: '1', name: 'Everyday')];
    final transactions = [_tx('Everyday')];

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const PrognosisScreen(),
        fireflyService: FakeFireflyService(
          accounts: accounts,
          transactions: transactions,
          transactionPages: {
            1: TransactionPageResult(
              transactions: transactions,
              currentPage: 1,
              totalPages: 1,
              total: transactions.length,
            ),
          },
        ),
        viewMode: ViewMode.compact,
        prefsValues: {
          'isRaccoonMode': false,
          'prognosisHorizon': 'customDate',
          'prognosisCustomHorizonDate': DateTime(
            2026,
            11,
            20,
          ).toIso8601String(),
        },
      ),
    );
    await pumpScreen(tester);

    // A horizon of one's own reads as the day it runs to, not as the invitation
    // to pick one.
    expect(find.text('Until Nov 20, 2026'), findsWidgets);

    await tester.tap(
      find.byType(DropdownButtonFormField<PrognosisHorizon>).first,
    );
    await pumpScreen(tester);

    expect(find.text('2 weeks'), findsWidgets);
    expect(find.text('Mid next month'), findsWidgets);
  });

  testWidgets('the account dropdown opens, filters, and selects', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    // Both halves matter: the list opens on a click for a ledger of three
    // accounts, and narrows as it is typed into for a ledger of eighty.
    final accounts = [
      _account(id: '1', name: 'Everyday'),
      _account(id: '2', name: 'Holiday fund'),
    ];
    final transactions = [_tx('Everyday'), _tx('Holiday fund')];

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const PrognosisScreen(),
        fireflyService: FakeFireflyService(
          accounts: accounts,
          transactions: transactions,
          transactionPages: {
            1: TransactionPageResult(
              transactions: transactions,
              currentPage: 1,
              totalPages: 1,
              total: transactions.length,
            ),
          },
        ),
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    final picker = find.byType(DropdownMenu<String>);
    final field = find.descendant(of: picker, matching: find.byType(TextField));

    await tester.tap(field);
    await pumpScreen(tester);
    expect(find.text('Holiday fund'), findsWidgets);

    await tester.enterText(field, 'Holi');
    await pumpScreen(tester);
    expect(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text('Everyday'),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Holiday fund').last);
    await pumpScreen(tester);

    expect(
      tester.widget<DropdownMenu<String>>(picker).controller!.text,
      'Holiday fund',
    );
  });
}
