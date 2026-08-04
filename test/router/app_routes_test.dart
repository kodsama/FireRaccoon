import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon/providers/undo_history_provider.dart';
import 'package:fireracoon/router/accounts_route.dart';
import 'package:fireracoon/router/budgets_route.dart';
import 'package:fireracoon/router/categories_tags_route.dart';
import 'package:fireracoon/router/dashboard_route.dart';
import 'package:fireracoon/router/history_route.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:fireracoon/router/expenses_route.dart';
import 'package:fireracoon/router/projection_route.dart';
import 'package:fireracoon/router/transactions_route.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('DashboardRoute', () {
    test('defaults to insights tab and this month period', () {
      expect(DashboardRoute.location(), '/');
      expect(DashboardRoute.tabFromUri(Uri.parse('/')), DashboardTab.insights);
      expect(
        DashboardRoute.filtersFromUri(Uri.parse('/')).period,
        DashboardPeriod.thisMonth,
      );
    });

    test('encodes tab and period query parameters', () {
      expect(DashboardRoute.location(tab: DashboardTab.focus), '/?tab=focus');
      expect(
        DashboardRoute.location(period: DashboardPeriod.lastMonth),
        '/?period=lastMonth',
      );
      expect(
        DashboardRoute.filtersFromUri(Uri.parse('/?period=lastQuarter')).period,
        DashboardPeriod.lastQuarter,
      );
    });

    test('encodes custom date range', () {
      expect(
        DashboardRoute.location(from: '2026-01-01', to: '2026-03-31'),
        '/?from=2026-01-01&to=2026-03-31',
      );
      final filters = DashboardRoute.filtersFromUri(
        Uri.parse('/?from=2026-01-01&to=2026-03-31'),
      );
      expect(filters.from, DateTime(2026, 1, 1));
      expect(filters.to, DateTime(2026, 3, 31));
      expect(filters.hasCustomDateRange, isTrue);
    });

    test('tabFrom reads tab from router state wrapper', () {
      expect(
        DashboardRoute.tabFrom(_RouteStateStub(Uri.parse('/?tab=focus'))),
        DashboardTab.focus,
      );
    });
  });

  group('AccountsRoute', () {
    test('filters by account type', () {
      expect(
        AccountsRoute.location(type: AccountTypeFilter.asset),
        '/accounts?type=asset',
      );
    });
  });

  group('BudgetsRoute', () {
    test('encodes expanded budget', () {
      expect(
        BudgetsRoute.location(budget: 'Groceries'),
        '/budgets?budget=Groceries',
      );
    });
  });

  group('ExpensesRoute', () {
    test('encodes category filter', () {
      expect(
        ExpensesRoute.location(category: 'Food'),
        '/expenses?category=Food',
      );
    });

    test('encodes period and type filters', () {
      expect(
        ExpensesRoute.location(
          period: ExpensePeriod.semester,
          type: TransactionTypeFilter.all,
        ),
        '/expenses?period=semester&type=all',
      );
    });
  });

  group('ProjectionRoute', () {
    test('encodes projection period', () {
      expect(
        ProjectionRoute.location(period: ProjectionPeriod.y1),
        '/projection?period=y1',
      );
      expect(
        ProjectionRoute.periodFromUri(Uri.parse('/projection?period=m3')),
        ProjectionPeriod.m3,
      );
    });

    test('encodes projection type and parameters', () {
      expect(
        ProjectionRoute.location(
          type: ProjectionType.compound,
          whatIf: 20,
          rate: 8.5,
        ),
        '/projection?type=compound&whatif=20&rate=8.5',
      );
      final params = ProjectionRoute.paramsFromUri(
        Uri.parse(
          '/projection?type=portfolio&whatif=15&rate=9&vol=18&chart=lines',
        ),
      );
      expect(params.type, ProjectionType.portfolio);
      expect(params.whatIfPercent, 15);
      expect(params.annualReturnPercent, 9);
      expect(params.volatilityPercent, 18);
      expect(params.chartStyle, ProjectionChartStyle.lines);
    });
  });

  group('TransactionsRoute', () {
    test('location with account encodes query parameter', () {
      expect(
        TransactionsRoute.location(account: 'Test account'),
        '/transactions?account=Test+account&period=all',
      );
    });

    test('groupFromUri reads group query parameter', () {
      expect(
        TransactionsRoute.groupFromUri(Uri.parse('/transactions?group=type')),
        TransactionGroupType.type,
      );
    });
  });

  group('HistoryRoute', () {
    test('encodes search and type', () {
      expect(HistoryRoute.location(), '/history');
      expect(
        HistoryRoute.location(
          search: 'budget',
          type: UndoActionType.budgetUpdate,
        ),
        '/history?search=budget&type=budgetUpdate',
      );
      final state = _RouteStateStub(
        Uri.parse('/history?q=x&type=transactionCreate'),
      );
      expect(HistoryRoute.searchFrom(state), 'x');
      expect(HistoryRoute.typeFrom(state), UndoActionType.transactionCreate);
      expect(HistoryRoute.typeFromUri(Uri.parse('/history')), isNull);
      expect(
        HistoryRoute.typeFromUri(Uri.parse('/history?type=notAType')),
        isNull,
      );
    });
  });

  group('CategoriesTagsRoute', () {
    test('encodes tab and search', () {
      expect(CategoriesTagsRoute.location(), '/categories-tags');
      expect(
        CategoriesTagsRoute.location(
          tab: CategoriesTagsTab.tags,
          search: 'food',
        ),
        '/categories-tags?tab=tags&search=food',
      );
      final state = _RouteStateStub(Uri.parse('/categories-tags?tab=tags&q=x'));
      expect(CategoriesTagsRoute.tabFrom(state), CategoriesTagsTab.tags);
      expect(CategoriesTagsRoute.searchFrom(state), 'x');
      expect(
        CategoriesTagsRoute.tabFromUri(Uri.parse('/categories-tags')),
        CategoriesTagsTab.categories,
      );
    });
  });
}

class _RouteStateStub extends Fake implements GoRouterState {
  _RouteStateStub(this._uri);
  final Uri _uri;

  @override
  Uri get uri => _uri;
}
