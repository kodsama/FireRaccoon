import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/models/transaction.dart';
import 'package:fireracoon/widgets/transactions_expanded_panel.dart';

import '../helpers/screen_test_app.dart';

Transaction _tx(String id, DateTime date, {double amount = 100}) => Transaction(
  id: id,
  type: 'withdrawal',
  date: date,
  amount: amount,
  description: 'Row $id',
  sourceName: 'Checking',
  destinationName: 'Shop',
  categoryName: 'Food',
  currencySymbol: 'kr',
  currencyCode: 'SEK',
);

void main() {
  final today = DateTime.now();
  final past = DateTime(today.year, today.month, today.day - 3);
  final ahead = DateTime(today.year, today.month, today.day + 30);

  Future<void> pump(
    WidgetTester tester, {
    List<Transaction>? posted,
    List<Transaction>? future,
    Future<void> Function()? onRefresh,
    bool loading = false,
    String? errorMessage,
  }) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: SingleChildScrollView(
            child: TransactionsExpandedPanel(
              loading: loading,
              transactions: posted,
              futureTransactions: future,
              emptyLabel: 'Nothing here',
              errorMessage: errorMessage,
              onRefresh: onRefresh,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('future rows start collapsed, out of the posted list', (
    tester,
  ) async {
    // A ledger with write-ahead recurrences has months of future rows, and the
    // newest twenty were almost all of them, so the account showed no history.
    await pump(
      tester,
      posted: [_tx('p1', past)],
      future: [_tx('f1', ahead), _tx('f2', ahead)],
    );

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Row p1'), findsOneWidget);
    expect(find.text('Row f1'), findsNothing);

    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();

    expect(find.text('Row f1'), findsOneWidget);
    expect(find.text('Row f2'), findsOneWidget);
  });

  testWidgets('no future rows means no heading at all', (tester) async {
    await pump(tester, posted: [_tx('p1', past)], future: const []);

    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('Row p1'), findsOneWidget);
  });

  testWidgets('the refresh button re-reads the rows', (tester) async {
    var calls = 0;
    await pump(
      tester,
      posted: [_tx('p1', past)],
      onRefresh: () async => calls++,
    );

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('a failed load can be retried without closing the row', (
    tester,
  ) async {
    // The count row and its button render whatever the body is doing, so the
    // only way out of an error was not closing and reopening the row.
    var calls = 0;
    await pump(
      tester,
      posted: null,
      errorMessage: 'Could not reach Firefly',
      onRefresh: () async => calls++,
    );

    expect(find.text('Could not reach Firefly'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('no refresh callback means no button', (tester) async {
    await pump(tester, posted: [_tx('p1', past)]);

    expect(find.byTooltip('Refresh'), findsNothing);
  });
}
