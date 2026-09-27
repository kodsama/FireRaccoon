import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/l10n/app_localizations_en.dart';
import 'package:fireraccoon/router/stats_route.dart';
import 'package:fireraccoon/utils/locale_formatting.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Label extensions', () {
    test('expense period labels map to expected strings', () {
      expect(ExpensePeriod.week.label, 'This Week');
      expect(ExpensePeriod.month.label, 'This Month');
      expect(ExpensePeriod.lastMonth.label, 'Last Month');
      expect(ExpensePeriod.quarter.label, 'This Quarter');
      expect(ExpensePeriod.semester.label, 'This Semester');
      expect(ExpensePeriod.year.label, 'This Year');
      expect(ExpensePeriod.all.label, 'All Time');
    });

    test('transaction type labels map to expected strings', () {
      expect(TransactionTypeFilter.all.label, 'All Types');
      expect(TransactionTypeFilter.expense.label, 'Expenses');
      expect(TransactionTypeFilter.income.label, 'Income');
      expect(TransactionTypeFilter.transfer.label, 'Transfers');
    });
  });

  group('StatsRoute.location', () {
    test('leaves out everything at its default', () {
      expect(StatsRoute.location(), '/stats');
    });

    test('names the types in page order, whatever order they came in', () {
      final uri = Uri.parse(
        StatsRoute.location(
          types: {
            TransactionTypeFilter.transfer,
            TransactionTypeFilter.expense,
          },
        ),
      );
      expect(uri.queryParameters['types'], 'expense,transfer');
    });

    test('encodes every filter it is given', () {
      final uri = Uri.parse(
        StatsRoute.location(
          types: {TransactionTypeFilter.income},
          category: 'Salary',
          tag: '5-stan trip 2026',
          budget: 'Travel',
          account: 'Checking',
          from: '2026-01-01',
          to: '2026-06-30',
        ),
      );
      expect(uri.path, '/stats');
      expect(uri.queryParameters, {
        'types': 'income',
        'category': 'Salary',
        'tag': '5-stan trip 2026',
        'budget': 'Travel',
        'account': 'Checking',
        'from': '2026-01-01',
        'to': '2026-06-30',
      });
    });

    test('bounds a multi-year dashboard default with dates', () {
      final uri = Uri.parse(
        StatsRoute.location(defaultDashboardPeriod: DashboardPeriod.last2Years),
      );
      expect(uri.queryParameters['from'], isNotNull);
      expect(uri.queryParameters['to'], isNotNull);
    });
  });

  group('StatsRoute.filtersFromUri', () {
    test('reads every filter back', () {
      final filters = StatsRoute.filtersFromUri(
        Uri.parse(
          '/stats?types=income,transfer&period=quarter&category=Travel'
          '&tag=Holiday&budget=Fun&account=Savings'
          '&from=2026-01-15&to=2026-02-20',
        ),
      );
      expect(filters.types, {
        TransactionTypeFilter.income,
        TransactionTypeFilter.transfer,
      });
      expect(filters.period, ExpensePeriod.quarter);
      expect(filters.category, 'Travel');
      expect(filters.tag, 'Holiday');
      expect(filters.budget, 'Fun');
      expect(filters.account, 'Savings');
      expect(filters.from, DateTime(2026, 1, 15));
      expect(filters.to, DateTime(2026, 2, 20));
      expect(filters.hasActiveFilters, isTrue);
    });

    test('defaults to this month of expenses', () {
      final filters = StatsRoute.filtersFromUri(Uri.parse('/stats'));
      expect(filters.types, {TransactionTypeFilter.expense});
      expect(filters.singleType, TransactionTypeFilter.expense);
      expect(filters.period, ExpensePeriod.month);
      expect(filters.hasActiveFilters, isFalse);
    });

    test('falls back to expenses when no type it names is real', () {
      final filters = StatsRoute.filtersFromUri(
        Uri.parse('/stats?types=all,nonsense'),
      );
      expect(filters.types, {TransactionTypeFilter.expense});
    });

    test('tolerates malformed dates', () {
      final filters = StatsRoute.filtersFromUri(
        Uri.parse('/stats?from=invalid&to=2026-13-99&period=week'),
      );
      expect(filters.period, ExpensePeriod.week);
      expect(filters.from, isNull);
      expect(filters.to, DateTime(2027, 4, 9));
    });

    test('filtersFrom reads router state', () {
      final filters = StatsRoute.filtersFrom(
        _RouteStateStub(Uri.parse('/stats?account=Checking&period=year')),
      );
      expect(filters.account, 'Checking');
      expect(filters.period, ExpensePeriod.year);
    });
  });

  group('StatsRouteFilters', () {
    test('orderedTypes follows the page, singleType only for one', () {
      const filters = StatsRouteFilters(
        types: {TransactionTypeFilter.transfer, TransactionTypeFilter.income},
      );
      expect(filters.orderedTypes, [
        TransactionTypeFilter.income,
        TransactionTypeFilter.transfer,
      ]);
      expect(filters.singleType, isNull);
    });

    test('a type other than expenses counts as a filter', () {
      const filters = StatsRouteFilters(types: {TransactionTypeFilter.income});
      expect(filters.hasActiveFilters, isTrue);
    });

    test('a tag or budget alone counts as a filter', () {
      expect(const StatsRouteFilters(tag: 'Holiday').hasActiveFilters, isTrue);
      expect(const StatsRouteFilters(budget: 'Fun').hasActiveFilters, isTrue);
    });

    test('location keeps what it is not told to change', () {
      final filters = StatsRoute.filtersFromUri(
        Uri.parse(
          '/stats?types=income&tag=Holiday&from=2026-01-01&to=2026-01-31',
        ),
      );
      final next = StatsRoute.filtersFromUri(
        Uri.parse(filters.location(budget: 'Fun')),
      );
      expect(next.types, {TransactionTypeFilter.income});
      expect(next.tag, 'Holiday');
      expect(next.budget, 'Fun');
      expect(next.from, DateTime(2026, 1, 1));
      expect(next.to, DateTime(2026, 1, 31));
    });

    test('location clears a filter passed as null', () {
      const filters = StatsRouteFilters(tag: 'Holiday', category: 'Food');
      final next = StatsRoute.filtersFromUri(
        Uri.parse(filters.location(tag: null)),
      );
      expect(next.tag, isNull);
      expect(next.category, 'Food');
    });

    test('a new period drops custom dates and new dates drop the period', () {
      final dated = StatsRouteFilters(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );
      final byPeriod = StatsRoute.filtersFromUri(
        Uri.parse(dated.location(period: ExpensePeriod.year)),
      );
      expect(byPeriod.period, ExpensePeriod.year);
      expect(byPeriod.hasCustomDateRange, isFalse);

      const yearly = StatsRouteFilters(period: ExpensePeriod.year);
      final uri = Uri.parse(
        yearly.location(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31)),
      );
      expect(uri.queryParameters.containsKey('period'), isFalse);
      expect(uri.queryParameters['from'], '2026-03-01');
    });

    test('periodLabel shows custom dates, else the preset', () {
      final dated = StatsRouteFilters(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );
      expect(dated.periodLabel, '2026-01-01 – 2026-01-31');
      expect(
        const StatsRouteFilters(period: ExpensePeriod.week).periodLabel,
        'This Week',
      );
    });

    test('localizedPeriodLabel formats custom range with l10n', () {
      final filters = StatsRouteFilters(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );
      final label = filters.localizedPeriodLabel(
        AppLocalizationsEn(),
        LocaleFormatting(const Locale('en')),
      );
      expect(label, '2026-01-01 – 2026-01-31');
    });

    test('formatDate returns ISO date string', () {
      expect(StatsRouteFilters.formatDate(DateTime(2026, 7, 6)), '2026-07-06');
    });
  });
}

class _RouteStateStub extends Fake implements GoRouterState {
  _RouteStateStub(this._uri);
  final Uri _uri;

  @override
  Uri get uri => _uri;
}
