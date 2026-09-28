import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fireraccoon/screens/stats_screen.dart';
import 'package:fireraccoon/widgets/filter_pill.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';

class _HangingTransactionsService extends FakeFireflyService {
  _HangingTransactionsService()
    : super(
        accounts: sampleAccounts,
        transactions: sampleTransactions,
        primaryCurrency: sampleCurrency,
        currentUser: sampleUser,
      );

  final Completer<List<Transaction>> _transactions = Completer();

  @override
  Future<List<Transaction>> getTransactions({
    DateTime? start,
    DateTime? end,
    String? type,
    void Function(List<Transaction> firstPage)? onFirstPage,
    void Function(int loadedPages, int totalPages)? onPageProgress,
  }) {
    return _transactions.future;
  }
}

void main() {
  testWidgets('StatsScreen keeps period filter visible while analytics load', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats?types=income',
        fireflyService: _HangingTransactionsService(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('This Month'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('StatsScreen keeps period filter visible when analytics fail', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final service = FakeFireflyService(
      accounts: sampleAccounts,
      transactions: sampleTransactions,
      primaryCurrency: sampleCurrency,
      currentUser: sampleUser,
    )..throwOn = Exception('firefly down');

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats?types=income',
        fireflyService: service,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This Month'), findsOneWidget);
  });

  testWidgets('StatsScreen period selection updates the route', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats?types=income',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This Year'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(StatsScreen));
    expect(
      GoRouterState.of(context).uri.toString(),
      '/stats?types=income&period=year',
    );
    expect(find.text('This Year'), findsWidgets);
  });

  testWidgets('StatsScreen shows expenses by category by default', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stats'), findsWidgets);
    expect(find.text('Food'), findsWidgets);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Clear filters'), findsNothing);
    expect(find.textContaining('Net:'), findsNothing);
  });

  testWidgets('StatsScreen adds a type and shows the net of the two', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Income'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(StatsScreen));
    expect(
      GoRouterState.of(context).uri.toString(),
      '/stats?types=expense%2Cincome',
    );
    expect(find.textContaining('Net:'), findsOneWidget);
    expect(find.textContaining('1,155'), findsOneWidget);
  });

  testWidgets('StatsScreen will not switch off the last type shown', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats',
      ),
    );
    await tester.pumpAndSettle();

    final expenses = find.widgetWithText(FilterChip, 'Expenses');
    // Left enabled so it keeps its selected look, and a tap does nothing.
    expect(tester.widget<FilterChip>(expenses).onSelected, isNotNull);
    await tester.tap(expenses);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(StatsScreen));
    expect(GoRouterState.of(context).uri.toString(), '/stats');
    expect(tester.widget<FilterChip>(expenses).selected, isTrue);
  });

  testWidgets('StatsScreen marks a filter in use and clears it in place', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats?budget=Holidays',
      ),
    );
    await tester.pumpAndSettle();

    FilterPill pill(String label) =>
        tester.widget<FilterPill>(find.widgetWithText(FilterPill, label));
    expect(pill('Holidays').active, isTrue);
    expect(pill('Tag').active, isFalse);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(FilterPill, 'Holidays'),
        matching: find.byIcon(LucideIcons.x),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(StatsScreen));
    expect(GoRouterState.of(context).uri.queryParameters['budget'], isNull);
    expect(pill('Budget').active, isFalse);
  });

  testWidgets('StatsScreen narrows the totals to a picked tag', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final base = sampleTransactions.last;
    final service = FakeFireflyService(
      accounts: sampleAccounts,
      transactions: [
        base.copyWith(tags: ['Holiday']),
        base.copyWith(id: 'bus', categoryName: 'Transport', amount: 3),
      ],
      primaryCurrency: sampleCurrency,
      currentUser: sampleUser,
    );
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats',
        fireflyService: service,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Transport'), findsOneWidget);

    await tester.tap(find.text('Tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Holiday'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(StatsScreen));
    expect(GoRouterState.of(context).uri.queryParameters['tag'], 'Holiday');
    expect(find.text('Transport'), findsNothing);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
  });

  testWidgets('StatsScreen words go into the search and narrow the totals', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats?types=expense,income',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Words'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'salary');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(StatsScreen));
    expect(GoRouterState.of(context).uri.queryParameters['q'], 'salary');
    expect(find.text('"salary"'), findsOneWidget);
    expect(find.text('Food'), findsNothing);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(GoRouterState.of(context).uri.toString(), '/stats');
    expect(find.text('Food'), findsWidgets);
  });

  testWidgets('StatsScreen category checkbox toggles plot visibility', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats',
      ),
    );
    await tester.pumpAndSettle();

    final foodCheckbox = find.descendant(
      of: find.ancestor(of: find.text('Food'), matching: find.byType(Row)),
      matching: find.byType(Checkbox),
    );
    expect(foodCheckbox, findsOneWidget);
    await tester.tap(foodCheckbox);
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(foodCheckbox).value, isFalse);
    expect(
      find.text('No transactions match the current filters.'),
      findsOneWidget,
    );
  });

  testWidgets('StatsScreen hands its tag and budget to the transaction list', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final base = sampleTransactions.last;
    final service = FakeFireflyService(
      accounts: sampleAccounts,
      transactions: [
        base.copyWith(tags: ['Holiday'], budgetName: 'Fun'),
      ],
      primaryCurrency: sampleCurrency,
      currentUser: sampleUser,
    );
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats?tag=Holiday&budget=Fun',
        fireflyService: service,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Transactions'));
    await tester.pumpAndSettle();

    final uri = GoRouterState.of(tester.element(find.byType(StatsScreen))).uri;
    expect(uri.path, '/transactions');
    expect(uri.queryParameters['tag'], 'Holiday');
    expect(uri.queryParameters['budget'], 'Fun');
  });
}
