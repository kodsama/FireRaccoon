import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon/providers/view_mode_provider.dart';
import 'package:fireraccoon/widgets/transaction_entity_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fireraccoon/utils/display_labels.dart';

import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';

void main() {
  testWidgets('TightRowsHeaderRow displays column labels and settings button', (
    tester,
  ) async {
    final widget = await buildScreenTestApp(
      child: const Scaffold(body: TightRowsHeaderRow()),
      viewMode: ViewMode.tight,
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.slidersHorizontal), findsOneWidget);
  });

  testWidgets('TightRowsColumnSelectionDialog opens from header button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final widget = await buildScreenTestApp(
      child: const Scaffold(body: TightRowsHeaderRow()),
      viewMode: ViewMode.tight,
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Tap column chooser button
    await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
    await tester.pumpAndSettle();

    expect(find.byType(TightRowsColumnSelectionDialog), findsOneWidget);
  });

  testWidgets('TransactionEntityTightRow renders transaction title', (
    tester,
  ) async {
    final tx = sampleTransactions.first;

    final widget = await buildScreenTestApp(
      child: Scaffold(body: TransactionEntityTightRow(transaction: tx)),
      viewMode: ViewMode.tight,
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text(tx.displayTitle()), findsOneWidget);
  });

  testWidgets(
    'TransactionEntityTightRow renders running balance when provided',
    (tester) async {
      final tx = sampleTransactions.first;

      final widget = await buildScreenTestApp(
        child: Scaffold(
          body: TransactionEntityTightRow(
            transaction: tx,
            runningBalance: 12345.67,
          ),
        ),
        viewMode: ViewMode.tight,
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.textContaining('12,345.67'), findsOneWidget);
    },
  );

  group('computeRunningBalances', () {
    test('returns null when filterAccount is null', () {
      final balances = computeRunningBalances(
        filterAccount: null,
        transactions: sampleTransactions,
        accounts: sampleAccounts,
        prognosis: null,
      );
      expect(balances, isNull);
    });

    test('computes running balance for single account', () {
      final account = sampleAccounts.first;
      final balances = computeRunningBalances(
        filterAccount: account.name,
        transactions: sampleTransactions,
        accounts: sampleAccounts,
        prognosis: null,
      );
      expect(balances, isNotNull);
      expect(balances!.containsKey(sampleTransactions.first.id), isTrue);
    });

    test('an upcoming row shows the balance it leaves, not today\'s', () {
      // current_balance is as of today, so it holds the settled rows and none
      // of the upcoming ones. Walking back from it subtracted every upcoming
      // row a second time and put the whole block out by its own net: on a
      // card that reads as a payback booked backwards, not as a column fault.
      final card = Account(
        id: 'cc',
        name: 'Platinum',
        type: 'asset',
        role: 'ccAsset',
        currencyCode: 'SEK',
        currencySymbol: 'kr',
        currentBalance: -26918.84,
      );
      Transaction row({
        required String id,
        required DateTime date,
        required double amount,
        required bool incoming,
      }) => Transaction(
        id: id,
        type: incoming ? 'transfer' : 'withdrawal',
        date: date,
        amount: amount,
        description: id,
        sourceName: incoming ? 'Savings' : 'Platinum',
        destinationName: incoming ? 'Platinum' : 'Shop',
        categoryName: '',
        currencySymbol: 'kr',
        currencyCode: 'SEK',
      );

      final balances = computeRunningBalances(
        filterAccount: 'Platinum',
        transactions: [
          row(
            id: 'payback',
            date: DateTime(2026, 9, 30),
            amount: 26918.84,
            incoming: true,
          ),
          row(
            id: 'sub-120',
            date: DateTime(2026, 9, 25),
            amount: 120.00,
            incoming: false,
          ),
          row(
            id: 'sub-219',
            date: DateTime(2026, 9, 25),
            amount: 219.00,
            incoming: false,
          ),
        ],
        accounts: [card],
        prognosis: null,
        reference: DateTime(2026, 9, 16),
      )!;

      expect(balances['payback'], closeTo(-339.00, 0.005));
      expect(balances['sub-120'], closeTo(-27257.84, 0.005));
      expect(balances['sub-219'], closeTo(-27137.84, 0.005));
    });

    test('a settled row still walks back from the reported balance', () {
      final account = Account(
        id: 'a1',
        name: 'Checking',
        type: 'asset',
        role: 'defaultAsset',
        currencyCode: 'SEK',
        currencySymbol: 'kr',
        currentBalance: 1000.00,
      );
      final balances = computeRunningBalances(
        filterAccount: 'Checking',
        transactions: [
          Transaction(
            id: 'settled',
            type: 'withdrawal',
            date: DateTime(2026, 9, 10),
            amount: 250.00,
            description: 'settled',
            sourceName: 'Checking',
            destinationName: 'Shop',
            categoryName: '',
            currencySymbol: 'kr',
            currencyCode: 'SEK',
          ),
        ],
        accounts: [account],
        prognosis: null,
        reference: DateTime(2026, 9, 16),
      )!;

      // Nothing upcoming, so the seed is what Firefly reports and the newest
      // row sits on it.
      expect(balances['settled'], closeTo(1000.00, 0.005));
    });
  });
}
