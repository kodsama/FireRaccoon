import 'package:fireraccoon/l10n/app_localizations_en.dart';
import 'package:fireraccoon/router/budgets_route.dart';
import 'package:fireraccoon/utils/locale_formatting.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('location encodes budget and explicit period filters', () {
    final uri = Uri.parse(
      BudgetsRoute.location(
        budget: 'Food',
        period: ExpensePeriod.year,
        from: '2026-01-01',
        to: '2026-12-31',
      ),
    );

    expect(uri.path, '/budgets');
    expect(uri.queryParameters, {
      'budget': 'Food',
      'period': 'year',
      'from': '2026-01-01',
      'to': '2026-12-31',
    });
    expect(BudgetsRoute.budgetFromUri(uri), 'Food');
  });

  test('filtersFromUri parses custom dates and active period state', () {
    final filters = BudgetsRoute.filtersFromUri(
      Uri.parse('/budgets?period=year&from=2026-01-01&to=2026-12-31'),
    );

    expect(filters.period, ExpensePeriod.year);
    expect(filters.from, DateTime(2026, 1, 1));
    expect(filters.to, DateTime(2026, 12, 31));
    expect(filters.hasCustomDateRange, isTrue);
    expect(filters.hasActivePeriodFilter, isTrue);
    expect(filters.dateRange.start, isNotNull);
  });

  test('localizedPeriodLabel handles preset and custom ranges', () {
    final l10n = AppLocalizationsEn();
    final format = LocaleFormatting(const Locale('en'));

    expect(
      const BudgetRouteFilters(
        period: ExpensePeriod.year,
      ).localizedPeriodLabel(l10n, format),
      'This Year',
    );
    expect(
      BudgetRouteFilters(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      ).localizedPeriodLabel(l10n, format),
      '2026-01-01 – 2026-01-31',
    );
  });

  test('filtersFromUri tolerates malformed dates', () {
    final filters = BudgetsRoute.filtersFromUri(
      Uri.parse('/budgets?period=month&from=bad&to=2026-xx-31'),
    );

    expect(filters.from, isNull);
    expect(filters.to, isNull);
    expect(BudgetRouteFilters.formatDate(DateTime(2026, 7, 3)), '2026-07-03');
  });

  test('location applies bounds for multi-year dashboard defaults', () {
    final uri = Uri.parse(
      BudgetsRoute.location(defaultDashboardPeriod: DashboardPeriod.last2Years),
    );

    expect(uri.queryParameters['from'], isNotNull);
    expect(uri.queryParameters['to'], isNotNull);
  });
}
