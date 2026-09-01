import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon/providers/view_mode_provider.dart';
import 'package:fireraccoon/screens/transactions_screen.dart';
import 'package:fireraccoon/widgets/selection_check_control.dart';
import 'package:fireraccoon/widgets/small_loading_indicator.dart';
import 'package:fireraccoon/widgets/transaction_month_header.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';

/// Expansion of a bare header, for the future block, which is a header over
/// month groups rather than over rows.
bool _headerExpanded(WidgetTester tester, Finder header) {
  final widget = tester.widget<TransactionMonthHeader>(
    find
        .ancestor(of: header, matching: find.byType(TransactionMonthHeader))
        .first,
  );
  return widget.expanded ?? false;
}

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
    'TransactionsScreen reveals future months, then the rows inside one',
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
      expect(_headerExpanded(tester, futureHeader), isFalse);
      expect(find.text('March 2099 · Upcoming'), findsNothing);

      await tester.tap(futureHeader);
      await tester.pumpAndSettle();

      // The months carry the expected balance, so the block opens onto them
      // and the rows sit one level further in.
      expect(_headerExpanded(tester, futureHeader), isTrue);
      final monthHeader = find.text('March 2099 · Upcoming');
      expect(monthHeader, findsOneWidget);
      // Marked, so it cannot be mistaken for the posted month of the same name.
      expect(find.text('Scheduled rent'), findsNothing);

      await tester.tap(monthHeader);
      await tester.pumpAndSettle();

      expect(find.text('Scheduled rent'), findsWidgets);

      await tester.tap(futureHeader);
      await tester.pumpAndSettle();

      expect(_headerExpanded(tester, futureHeader), isFalse);
      expect(find.text('March 2099 · Upcoming'), findsNothing);
    },
  );

  testWidgets('TransactionsScreen reads the balance at a chosen date', (
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
      balancesByDate: const {
        '1': {'*': 4321.0},
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

    // Today, straight from the account.
    expect(find.textContaining('\u20ac2,500.00'), findsWidgets);

    await tester.tap(find.text('Balance:'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // The picker opens on today, so confirming it asks the ledger for a date
    // rather than reading the account's own balance.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.textContaining('\u20ac4,321.00'), findsWidgets);

    // Clearing it goes back to today, straight from the account.
    await tester.tap(find.byTooltip('today'));
    await tester.pumpAndSettle();

    expect(find.textContaining('\u20ac2,500.00'), findsWidgets);
  });

  testWidgets(
    'TransactionsScreen shows Refresh instead of view mode switcher',
    (tester) async {
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

      expect(find.text('Refresh'), findsOneWidget);
      expect(find.byTooltip('Re-fetch data from Firefly III'), findsOneWidget);
      // View mode lives in the app shell header, not on this filter bar.
      expect(find.text('Rows'), findsNothing);
    },
  );

  testWidgets('TransactionsScreen Refresh re-fetches from Firefly', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final liveAccounts = List<Account>.from(sampleAccounts);
    final liveTransactions = List<Transaction>.from(sampleTransactions);
    final fake = _CountingTransactionsFake(
      accounts: liveAccounts,
      transactions: liveTransactions,
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionsScreen(),
        fireflyService: fake,
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    expect(find.text('Salary'), findsWidgets);
    final accountsAfterWarm = fake.accountReads;
    final transactionsAfterWarm = fake.transactionReads;

    liveAccounts
      ..clear()
      ..add(
        sampleAccounts.first.copyWith(
          name: 'Refreshed Checking',
          currentBalance: 42,
        ),
      );
    liveTransactions
      ..clear()
      ..add(
        sampleTransactions.first.copyWith(description: 'Edited in Firefly'),
      );
    fake.transactionPages[1] = TransactionPageResult(
      transactions: List<Transaction>.from(liveTransactions),
      currentPage: 1,
      totalPages: 1,
      total: liveTransactions.length,
    );

    await tester.tap(find.text('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(fake.accountReads, greaterThan(accountsAfterWarm));
    expect(fake.transactionReads, greaterThan(transactionsAfterWarm));
    expect(find.text('Edited in Firefly'), findsWidgets);
    expect(find.text('Salary'), findsNothing);
  });
}

class _CountingTransactionsFake extends FakeFireflyService {
  _CountingTransactionsFake({
    required super.accounts,
    required super.transactions,
  }) : super(
         transactionPages: {
           1: TransactionPageResult(
             transactions: transactions,
             currentPage: 1,
             totalPages: 1,
             total: transactions.length,
           ),
         },
       );

  int accountReads = 0;
  int transactionReads = 0;

  @override
  Future<List<Account>> getAccounts({
    List<String> types = const ['asset', 'liability'],
  }) async {
    accountReads++;
    return super.getAccounts(types: types);
  }

  @override
  Future<List<Transaction>> getTransactions({
    DateTime? start,
    DateTime? end,
    String? type,
    void Function(List<Transaction> firstPage)? onFirstPage,
    void Function(int loadedPages, int totalPages)? onPageProgress,
  }) async {
    transactionReads++;
    return super.getTransactions(
      start: start,
      end: end,
      type: type,
      onFirstPage: onFirstPage,
    );
  }

  @override
  Future<TransactionPageResult> getTransactionsPage({
    required int page,
    required int limit,
    DateTime? start,
    DateTime? end,
  }) async {
    transactionReads++;
    return super.getTransactionsPage(
      page: page,
      limit: limit,
      start: start,
      end: end,
    );
  }
}
