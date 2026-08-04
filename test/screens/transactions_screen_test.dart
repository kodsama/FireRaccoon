import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:fireracoon/providers/view_mode_provider.dart';
import 'package:fireracoon/screens/transactions_screen.dart';
import 'package:fireracoon/widgets/selection_check_control.dart';
import 'package:fireracoon/widgets/small_loading_indicator.dart';
import 'package:fireracoon/widgets/transaction_entity_card.dart';
import 'package:fireracoon/widgets/transaction_month_header.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';

bool _isExpandedForHeader(WidgetTester tester, Finder header) {
  final group = tester.widget<SliverCollapsibleTransactionGroup>(
    find
        .ancestor(
          of: header,
          matching: find.byType(SliverCollapsibleTransactionGroup),
        )
        .first,
  );
  return group.expanded;
}

void main() {
  FakeFireflyService transactionsFake() => FakeFireflyService(
    accounts: sampleAccounts,
    transactionPages: {
      1: TransactionPageResult(
        transactions: sampleTransactions,
        currentPage: 1,
        totalPages: 1,
        total: sampleTransactions.length,
      ),
    },
  );

  testWidgets('TransactionsScreen shows loading indicator while fetching', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = transactionsFake()..responseDelay = const Duration(seconds: 5);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        fireflyService: fake,
        viewMode: ViewMode.compact,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(PageLoadingIndicator), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);

    // Drain the delayed fake response so no pending timers remain.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('TransactionsScreen shows loading then transactions', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        fireflyService: transactionsFake(),
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Salary'), findsWidgets);
    expect(find.text('Groceries'), findsWidgets);
  });

  testWidgets('TransactionsScreen shows error when fetch fails', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = transactionsFake()..throwOn = Exception('network down');

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        fireflyService: fake,
      ),
    );
    await pumpScreen(tester);

    expect(find.textContaining('network down'), findsOneWidget);
  });

  testWidgets('TransactionsScreen filters by account from route', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = FakeFireflyService(
      accounts: sampleAccounts,
      accountTransactionPages: {
        '1': {
          1: TransactionPageResult(
            transactions: sampleTransactions,
            currentPage: 1,
            totalPages: 1,
            total: sampleTransactions.length,
          ),
        },
      },
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        initialLocation: '/?account=Checking',
        fireflyService: fake,
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    expect(find.textContaining('Checking'), findsWidgets);
    expect(find.text('Salary'), findsWidgets);
  });

  testWidgets('TransactionsScreen shows balance check when account selected', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = FakeFireflyService(
      accounts: sampleAccounts,
      accountTransactionPages: {
        '1': {
          1: TransactionPageResult(
            transactions: sampleTransactions,
            currentPage: 1,
            totalPages: 1,
            total: sampleTransactions.length,
          ),
        },
      },
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        initialLocation: '/transactions?account=Checking',
        fireflyService: fake,
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    expect(find.text('Check balance'), findsOneWidget);

    await tester.tap(find.text('Check balance'));
    await tester.pumpAndSettle();

    expect(find.text('Balance from selected'), findsOneWidget);
    expect(find.textContaining('€2,500.00'), findsWidgets);
  });

  testWidgets('TransactionsScreen disables reconcile when nothing is pending', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = FakeFireflyService(
      accounts: sampleAccounts,
      accountTransactionPages: {
        '1': {
          1: TransactionPageResult(
            transactions: sampleTransactions,
            currentPage: 1,
            totalPages: 1,
            total: sampleTransactions.length,
          ),
        },
      },
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        initialLocation: '/transactions?account=Checking&reconcile=1',
        fireflyService: fake,
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    // Default selection excludes unreconciled rows, so selected balance is
    // reportedBalance - unselectedEffect = 2500 - (1200 - 45) = 1345.
    expect(find.text('Balance from selected'), findsOneWidget);
    expect(find.textContaining('€1,345.00'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, '1345');
    await tester.pump();

    expect(find.text('Balances match'), findsOneWidget);
    expect(find.textContaining('Nothing to reconcile'), findsOneWidget);

    final reconcileButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reconcile selected'),
    );
    expect(reconcileButton.onPressed, isNull);
    expect(fake.updatedTransactions, isEmpty);
  });

  testWidgets(
    'TransactionsScreen reconciles after opting in unreconciled rows',
    (tester) async {
      configureLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      final fake = FakeFireflyService(
        accounts: sampleAccounts,
        accountTransactionPages: {
          '1': {
            1: TransactionPageResult(
              transactions: sampleTransactions,
              currentPage: 1,
              totalPages: 1,
              total: sampleTransactions.length,
            ),
          },
        },
      );

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: const TransactionsScreen(),
          initialLocation: '/transactions?account=Checking&reconcile=1',
          fireflyService: fake,
          viewMode: ViewMode.compact,
        ),
      );
      await pumpScreen(tester);

      // Month-header check opts in every unreconciled row in the group.
      final monthHeaderCheck = find.descendant(
        of: find.byType(TransactionMonthHeader),
        matching: find.byType(SelectionCheckControl),
      );
      expect(monthHeaderCheck, findsOneWidget);
      await tester.tap(monthHeaderCheck);
      await tester.pumpAndSettle();

      expect(find.textContaining('€2,500.00'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, '2500');
      await tester.pump();

      expect(find.text('Balances match'), findsOneWidget);
      expect(find.textContaining('Nothing to reconcile'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Reconcile selected'));
      await tester.pumpAndSettle();

      expect(find.text('Selected transactions reconciled'), findsOneWidget);
      expect(fake.updatedTransactions, hasLength(2));
      expect(fake.updatedTransactions.every((tx) => tx.isReconciled), isTrue);
    },
  );

  testWidgets('TransactionsScreen auto-enables reconcile mode from route', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = FakeFireflyService(
      accounts: sampleAccounts,
      accountTransactionPages: {
        '1': {
          1: TransactionPageResult(
            transactions: sampleTransactions,
            currentPage: 1,
            totalPages: 1,
            total: sampleTransactions.length,
          ),
        },
      },
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        initialLocation: '/transactions?account=Checking&reconcile=1',
        fireflyService: fake,
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    // Balance-check mode is active without the user tapping "Check balance".
    expect(find.text('Balance from selected'), findsOneWidget);
  });

  testWidgets('TransactionsScreen groups by category from route', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        initialLocation: '/?group=category',
        fireflyService: transactionsFake(),
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    expect(find.text('Income'), findsWidgets);
    expect(find.text('Food'), findsWidgets);
  });

  testWidgets('TransactionsScreen opens account filter menu', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        fireflyService: transactionsFake(),
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('Filter Account'));
    await tester.pumpAndSettle();

    expect(find.text('All accounts'), findsOneWidget);
    expect(find.text('Checking'), findsWidgets);

    await tester.tap(find.text('Checking').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Checking'), findsWidgets);
  });

  testWidgets('TransactionsScreen opens grouping menu', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        fireflyService: transactionsFake(),
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('Group By'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Group by Account').last);
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsWidgets);
  });

  testWidgets('TransactionsScreen opens new transaction dialog', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        fireflyService: transactionsFake(),
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('New Transaction'));
    await tester.pumpAndSettle();

    expect(find.text('Withdrawal'), findsOneWidget);
    expect(find.text('Deposit'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
  });

  testWidgets('TransactionsScreen creates a transfer from the flow', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        fireflyService: transactionsFake(),
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);
    await tester.tap(find.text('New Transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Checking');
    await tester.enterText(fields.at(1), '5.00');
    await tester.enterText(fields.at(2), 'Checking');
    final description = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Description',
    );
    await tester.enterText(description, 'Coffee');
    await tester.pump();

    final save = find.widgetWithText(ElevatedButton, 'Save');
    expect(tester.widget<ElevatedButton>(save).onPressed, isNotNull);
    await tester.ensureVisible(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pump();
    final validationMessages = [
      'Please enter a description.',
      'Please enter an amount.',
      'Amount must be a valid number greater than 0.',
      'Please select both source and destination accounts.',
    ].where((message) => find.text(message).evaluate().isNotEmpty).toList();
    expect(validationMessages, isEmpty);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'Save'), findsNothing);
  });

  testWidgets('TransactionsScreen duplicates transaction from row actions', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = transactionsFake();

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        fireflyService: fake,
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Duplicate').first);
    await tester.pumpAndSettle();

    expect(find.text('Transaction duplicated.'), findsOneWidget);
  });

  testWidgets('TransactionsScreen collapses and expands a period group', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final transactions = [
      Transaction(
        id: 'june',
        type: 'withdrawal',
        date: DateTime(2026, 6, 12),
        amount: 80,
        description: 'June payment',
        sourceName: 'Checking',
        destinationName: 'Store',
        categoryName: 'Food',
        currencySymbol: '€',
        currencyCode: 'EUR',
      ),
      ...sampleTransactions,
    ];

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        fireflyService: FakeFireflyService(
          accounts: sampleAccounts,
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

    final juneHeader = find.text('June 2026');
    expect(_isExpandedForHeader(tester, juneHeader), isFalse);

    await tester.tap(juneHeader);
    await tester.pumpAndSettle();

    expect(_isExpandedForHeader(tester, juneHeader), isTrue);
  });

  testWidgets(
    'TransactionsScreen keeps future transactions collapsed until expanded',
    (tester) async {
      configureLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      final transactions = [
        ...sampleTransactions,
        Transaction(
          id: 'future',
          type: 'withdrawal',
          date: DateTime(2099, 3, 15),
          amount: 99,
          description: 'Scheduled rent',
          sourceName: 'Checking',
          destinationName: 'Landlord',
          categoryName: 'Housing',
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
      ];

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: const TransactionsScreen(),
          fireflyService: FakeFireflyService(
            accounts: sampleAccounts,
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

      final futureHeader = find.text('Future transactions');
      expect(futureHeader, findsOneWidget);
      expect(_isExpandedForHeader(tester, futureHeader), isFalse);

      await tester.tap(futureHeader);
      await tester.pumpAndSettle();

      expect(_isExpandedForHeader(tester, futureHeader), isTrue);
      expect(find.text('Scheduled rent'), findsWidgets);

      await tester.tap(futureHeader);
      await tester.pumpAndSettle();

      expect(_isExpandedForHeader(tester, futureHeader), isFalse);
    },
  );

  testWidgets('TransactionsScreen renders in tight rows mode', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        fireflyService: transactionsFake(),
        viewMode: ViewMode.tight,
      ),
    );
    await pumpScreen(tester);

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.byType(TightRowsHeaderRow), findsWidgets);
    expect(find.text('Salary'), findsWidgets);
  });
}
