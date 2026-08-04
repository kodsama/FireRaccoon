import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:fireracoon/router/expenses_route.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('ExpensesRoute', () {
    test('location without filters returns base path', () {
      expect(ExpensesRoute.location(), '/expenses');
    });

    test('location with category encodes query parameter', () {
      expect(
        ExpensesRoute.location(category: 'Food'),
        '/expenses?category=Food',
      );
    });

    test('location with period and type encodes query parameters', () {
      final uri = Uri.parse(
        ExpensesRoute.location(
          period: ExpensePeriod.year,
          type: TransactionTypeFilter.income,
        ),
      );
      expect(uri.path, '/expenses');
      expect(uri.queryParameters['period'], 'year');
      expect(uri.queryParameters['type'], 'income');
    });

    test('location with account and custom dates includes all parameters', () {
      final uri = Uri.parse(
        ExpensesRoute.location(
          account: 'Checking',
          from: '2026-01-01',
          to: '2026-06-30',
          category: 'Groceries',
        ),
      );
      expect(uri.queryParameters['account'], 'Checking');
      expect(uri.queryParameters['from'], '2026-01-01');
      expect(uri.queryParameters['to'], '2026-06-30');
      expect(uri.queryParameters['category'], 'Groceries');
    });

    test('filtersFromUri reads all query parameters', () {
      final filters = ExpensesRoute.filtersFromUri(
        Uri.parse(
          '/expenses?period=quarter&type=transfer&category=Travel&account=Savings&from=2026-01-15&to=2026-02-20',
        ),
      );
      expect(filters.period, ExpensePeriod.quarter);
      expect(filters.type, TransactionTypeFilter.transfer);
      expect(filters.category, 'Travel');
      expect(filters.account, 'Savings');
      expect(filters.from, DateTime(2026, 1, 15));
      expect(filters.to, DateTime(2026, 2, 20));
      expect(filters.hasActiveFilters, isTrue);
    });

    test('filtersFromUri defaults period and type', () {
      final filters = ExpensesRoute.filtersFromUri(Uri.parse('/expenses'));
      expect(filters.period, ExpensePeriod.month);
      expect(filters.type, TransactionTypeFilter.expense);
      expect(filters.hasActiveFilters, isFalse);
    });

    test('formatDate returns ISO date string', () {
      expect(ExpensesRoute.formatDate(DateTime(2026, 7, 6)), '2026-07-06');
    });

    test('category accessors read category from uri/state path', () {
      final uri = Uri.parse('/expenses?category=Food');
      expect(ExpensesRoute.categoryFromUri(uri), 'Food');
      expect(
        ExpensesRoute.categoryFrom(
          _RouteStateStub(Uri.parse('/expenses?category=Fuel')),
        ),
        'Fuel',
      );
    });
  });

  group('IncomeRoute', () {
    test('location and filtersFromUri mirror analytics route', () {
      final uri = Uri.parse(
        IncomeRoute.location(
          period: ExpensePeriod.week,
          type: TransactionTypeFilter.income,
          account: 'Checking',
        ),
      );
      final filters = IncomeRoute.filtersFromUri(uri);
      expect(uri.path, '/income');
      expect(filters.period, ExpensePeriod.week);
      expect(filters.type, TransactionTypeFilter.income);
      expect(filters.account, 'Checking');
    });

    test('formatDate returns ISO date string', () {
      expect(IncomeRoute.formatDate(DateTime(2026, 7, 6)), '2026-07-06');
    });

    test('filtersFrom reads values from router state', () {
      final filters = IncomeRoute.filtersFrom(
        _RouteStateStub(Uri.parse('/income?account=Checking&period=year')),
      );
      expect(filters.account, 'Checking');
      expect(filters.period, ExpensePeriod.year);
    });
  });
}

class _RouteStateStub extends Fake implements GoRouterState {
  _RouteStateStub(this._uri);
  final Uri _uri;

  @override
  Uri get uri => _uri;
}
