import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fireracoon/l10n/app_localizations_en.dart';
import 'package:fireracoon/router/transaction_analytics_route.dart';
import 'package:fireracoon/utils/locale_formatting.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

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

  group('ExpenseRouteFilters', () {
    test('hasCustomDateRange and periodLabel reflect custom dates', () {
      final filters = ExpenseRouteFilters(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );

      expect(filters.hasCustomDateRange, isTrue);
      expect(filters.periodLabel, '2026-01-01 – 2026-01-31');
    });

    test('hasActiveFilters uses default type comparison', () {
      const filters = ExpenseRouteFilters(
        type: TransactionTypeFilter.income,
        defaultType: TransactionTypeFilter.income,
      );
      expect(filters.hasActiveFilters, isFalse);
    });

    test('periodLabel falls back to preset label without custom dates', () {
      const filters = ExpenseRouteFilters(period: ExpensePeriod.week);
      expect(filters.periodLabel, 'This Week');
    });

    test('localizedPeriodLabel formats custom range with l10n', () {
      final filters = ExpenseRouteFilters(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );
      final label = filters.localizedPeriodLabel(
        AppLocalizationsEn(),
        LocaleFormatting(const Locale('en')),
      );
      expect(label, '2026-01-01 – 2026-01-31');
    });
  });

  group('TransactionAnalyticsRoute', () {
    const route = TransactionAnalyticsRoute(
      path: '/expenses',
      defaultType: TransactionTypeFilter.expense,
    );

    test('location excludes default filters', () {
      expect(route.location(), '/expenses');
    });

    test('filtersFromUri tolerates malformed dates', () {
      final filters = route.filtersFromUri(
        Uri.parse('/expenses?from=invalid&to=2026-13-99&period=week'),
      );

      expect(filters.period, ExpensePeriod.week);
      expect(filters.from, isNull);
      expect(filters.to, isNotNull);
      expect(filters.to, DateTime(2027, 4, 9));
    });

    test('transfers route default type is transfer', () {
      final filters = transfersAnalyticsRoute.filtersFromUri(
        Uri.parse('/transfers'),
      );
      expect(filters.type, TransactionTypeFilter.transfer);
    });

    test('location applies bounds for multi-year dashboard defaults', () {
      final uri = Uri.parse(
        route.location(defaultDashboardPeriod: DashboardPeriod.last2Years),
      );

      expect(uri.queryParameters['from'], isNotNull);
      expect(uri.queryParameters['to'], isNotNull);
    });
  });
}
