import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fireraccoon/router/stats_route.dart';
import 'package:fireraccoon/screens/stats_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:fireraccoon/widgets/filter_pill.dart';
import 'package:fireraccoon/widgets/stats_donut.dart';
import 'package:fireraccoon/widgets/stats_over_time.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireraccoon/widgets/loading_body.dart';
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
    expect(find.byType(RaccoonLoader), findsOneWidget);
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

  testWidgets('StatsScreen shows expenses and income by category by default', (
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
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Income'))
          .selected,
      isTrue,
    );
    expect(find.text('Clear filters'), findsNothing);
    expect(find.textContaining('Net:'), findsOneWidget);
  });

  testWidgets('StatsScreen adds a type and shows the net of the two', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats?types=expense',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Income'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(StatsScreen));
    expect(GoRouterState.of(context).uri.toString(), '/stats');
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
        initialLocation: '/stats?types=expense',
      ),
    );
    await tester.pumpAndSettle();

    final expenses = find.widgetWithText(FilterChip, 'Expenses');
    // Left enabled so it keeps its selected look, and a tap does nothing.
    expect(tester.widget<FilterChip>(expenses).onSelected, isNotNull);
    await tester.tap(expenses);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(StatsScreen));
    expect(GoRouterState.of(context).uri.toString(), '/stats?types=expense');
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

  testWidgets('StatsScreen narrows the totals to the tags picked', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final base = sampleTransactions.last;
    final service = FakeFireflyService(
      accounts: sampleAccounts,
      transactions: [
        base.copyWith(tags: ['Holiday']),
        base.copyWith(id: 'bus', categoryName: 'Transport', amount: 3),
        base.copyWith(
          id: 'train',
          categoryName: 'Travel',
          amount: 30,
          tags: ['Work'],
        ),
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
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(StatsScreen));
    expect(
      GoRouterState.of(context).uri.queryParametersAll['tag'],
      unorderedEquals(['Holiday', 'Work']),
    );
    expect(find.text('Transport'), findsNothing);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget);
    expect(find.widgetWithText(FilterPill, 'Holiday +1'), findsOneWidget);
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

  testWidgets('StatsScreen lays the types out over time and opens a month', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats?period=year',
        prefsValues: const {
          'isRaccoonMode': false,
          'statsMerged': true,
          'statsLevel': 'types',
        },
      ),
    );
    await tester.pumpAndSettle();
    Uri uri() => GoRouterState.of(tester.element(find.byType(StatsScreen))).uri;

    await tester.tap(find.widgetWithText(FilterPill, 'By category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Over time').last);
    await tester.pumpAndSettle();
    expect(uri().queryParameters['view'], 'time');
    expect(find.byType(BarChart), findsOneWidget);
    // A year picks months on its own and says so.
    expect(find.widgetWithText(FilterPill, 'Month by month'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterPill, 'Month by month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quarter by quarter'));
    await tester.pumpAndSettle();
    expect(uri().queryParameters['interval'], 'quarter');
    await tester.tap(find.widgetWithText(FilterPill, 'Quarter by quarter'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Automatic'));
    await tester.pumpAndSettle();
    expect(uri().queryParameters.containsKey('interval'), isFalse);

    await tester.tap(find.text('Lines'));
    await tester.pumpAndSettle();
    expect(uri().queryParameters['chart'], 'line');
    expect(find.byType(LineChart), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Net'));
    await tester.pumpAndSettle();
    expect(uri().queryParameters['net'], '1');
    // Income 1,200 less expenses 45, in the month the samples sit in.
    expect(find.textContaining('1,155'), findsWidgets);

    final now = DateTime.now();
    await tester.tap(find.text(DateFormat.yMMMM('en').format(now)));
    await tester.pumpAndSettle();
    expect(uri().path, '/transactions');
    expect(
      uri().queryParameters['from'],
      StatsRouteFilters.formatDate(DateTime(now.year, now.month)),
    );
    expect(
      uri().queryParameters['to'],
      StatsRouteFilters.formatDate(DateTime(now.year, now.month + 1, 0)),
    );
  });

  testWidgets('StatsScreen groups by tag as columns and opens a tag', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final base = sampleTransactions.last;
    final service = FakeFireflyService(
      accounts: sampleAccounts,
      transactions: [
        base.copyWith(tags: ['Holiday']),
        base.copyWith(id: 'work', amount: 300, tags: ['Work']),
      ],
      primaryCurrency: sampleCurrency,
      currentUser: sampleUser,
    );
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats?types=expense',
        fireflyService: service,
      ),
    );
    await tester.pumpAndSettle();
    Uri uri() => GoRouterState.of(tester.element(find.byType(StatsScreen))).uri;

    await tester.tap(find.widgetWithText(FilterPill, 'By category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('By tag').last);
    await tester.pumpAndSettle();
    expect(uri().queryParameters['view'], 'tag');
    // The list under the chart is titled by the grouping.
    expect(find.text('By tag'), findsWidgets);
    expect(find.text('Work'), findsWidgets);

    await tester.tap(find.text('Bars'));
    await tester.pumpAndSettle();
    expect(uri().queryParameters['chart'], 'bars');
    expect(find.byType(StatsDonut), findsNothing);
    // Upright columns, named along the bottom.
    expect(find.byType(BarChart), findsOneWidget);
    expect(
      find.descendant(of: find.byType(BarChart), matching: find.text('Work')),
      findsOneWidget,
    );

    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();
    expect(uri().path, '/transactions');
    expect(uri().queryParametersAll['tag'], ['Work']);
  });

  testWidgets('StatsScreen separates or merges the types and remembers it', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats?view=time&period=year',
      ),
    );
    await tester.pumpAndSettle();
    Uri uri() => GoRouterState.of(tester.element(find.byType(StatsScreen))).uri;

    // In detail and separated to start with: a stacked chart per type, and
    // no net, which needs both on one chart.
    expect(find.byType(StatsSeriesChart), findsNWidgets(2));
    expect(find.widgetWithText(FilterChip, 'Net'), findsNothing);
    expect(find.widgetWithText(FilterPill, 'Stacked by category'), findsOne);

    await tester.tap(find.text('Merged'));
    await tester.pumpAndSettle();
    expect(find.byType(StatsSeriesChart), findsOneWidget);
    expect(find.textContaining('left to right'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Net'));
    await tester.pumpAndSettle();
    expect(uri().queryParameters['net'], '1');

    await tester.tap(find.widgetWithText(FilterPill, 'Stacked by category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stacked by tag').last);
    await tester.pumpAndSettle();
    expect(uri().queryParameters['split'], 'tag');
    expect(find.textContaining('(none)'), findsWidgets);

    await tester.tap(find.text('Types'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterPill, 'Stacked by tag'), findsNothing);
    expect(
      tester.widget<StatsSeriesChart>(find.byType(StatsSeriesChart)).byParts,
      isFalse,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('statsMerged'), isTrue);
    expect(prefs.getString('statsLevel'), 'types');
  });

  testWidgets('StatsScreen draws the types alone as one donut', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats',
        prefsValues: const {'isRaccoonMode': false, 'statsLevel': 'types'},
      ),
    );
    await tester.pumpAndSettle();

    final donut = tester.widget<StatsDonut>(find.byType(StatsDonut));
    expect(donut.outer.map((slice) => slice.label), ['Expenses', 'Income']);
    expect(donut.inner, isEmpty);
    // Nothing to separate once the types stand alone.
    expect(find.text('Merged'), findsNothing);
  });

  testWidgets('StatsScreen merges the types into a two-ring donut', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const StatsScreen(),
        initialLocation: '/stats',
        prefsValues: const {'isRaccoonMode': false, 'statsMerged': true},
      ),
    );
    await tester.pumpAndSettle();

    final donut = tester.widget<StatsDonut>(find.byType(StatsDonut));
    expect(donut.inner.map((slice) => slice.label), ['Expenses', 'Income']);
    expect(donut.outer.map((slice) => slice.label), ['Food', 'Income']);
    // Money out in red, money in in green, whatever else is on the page.
    expect(
      HSLColor.fromColor(donut.outer.first.color).hue,
      closeTo(HSLColor.fromColor(donut.inner.first.color).hue, 1),
    );
  });
}
