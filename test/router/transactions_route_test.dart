import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/l10n/app_localizations_en.dart';
import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/router/transactions_route.dart';
import 'package:fireraccoon/utils/locale_formatting.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('TransactionsRoute', () {
    test('location without filters returns base path', () {
      expect(TransactionsRoute.location(), '/transactions');
    });

    test('location with account encodes query parameter', () {
      expect(
        TransactionsRoute.location(account: 'Test account'),
        '/transactions?account=Test+account&period=all',
      );
    });

    test('location with group adds group query parameter', () {
      expect(
        TransactionsRoute.location(group: TransactionGroupType.category),
        '/transactions?group=category',
      );
    });

    test('location with account and group includes both parameters', () {
      final uri = Uri.parse(
        TransactionsRoute.location(
          account: 'Checking',
          group: TransactionGroupType.payee,
        ),
      );
      expect(uri.path, '/transactions');
      expect(uri.queryParameters['account'], 'Checking');
      expect(uri.queryParameters['group'], 'payee');
    });

    test('location with accounts encodes as a csv query parameter', () {
      final uri = Uri.parse(
        TransactionsRoute.location(accounts: ['Checking', 'Savings']),
      );
      expect(uri.path, '/transactions');
      expect(uri.queryParameters['accounts'], 'Checking,Savings');
    });

    test('location with analytics filters encodes scoped query parameters', () {
      final uri = Uri.parse(
        TransactionsRoute.location(
          category: 'Housing',
          period: ExpensePeriod.year,
          type: TransactionTypeFilter.expense,
          from: '2026-01-01',
          to: '2026-12-31',
        ),
      );
      expect(uri.queryParameters['category'], 'Housing');
      expect(uri.queryParameters['period'], 'year');
      expect(uri.queryParameters['type'], 'expense');
      expect(uri.queryParameters['from'], '2026-01-01');
      expect(uri.queryParameters['to'], '2026-12-31');
    });

    test('accountFromUri reads account query parameter', () {
      final uri = Uri.parse('/transactions?account=Savings');
      expect(TransactionsRoute.accountFromUri(uri), 'Savings');
    });

    test('accountsFromUri reads and normalizes account list', () {
      final uri = Uri.parse(
        '/transactions?accounts=Checking,Savings,Checking,%20',
      );
      expect(TransactionsRoute.accountsFromUri(uri), ['Checking', 'Savings']);
    });

    test('groupFromUri reads group query parameter', () {
      final uri = Uri.parse('/transactions?group=type');
      expect(TransactionsRoute.groupFromUri(uri), TransactionGroupType.type);
    });

    test('filtersFromUri reads analytics filters', () {
      final filters = TransactionsRoute.filtersFromUri(
        Uri.parse(
          '/transactions?category=Housing&period=year&type=expense&from=2026-01-01&to=2026-12-31',
        ),
      );
      expect(filters.category, 'Housing');
      expect(filters.period, ExpensePeriod.year);
      expect(filters.type, TransactionTypeFilter.expense);
      expect(filters.from, DateTime(2026, 1, 1));
      expect(filters.to, DateTime(2026, 12, 31));
      expect(filters.hasScopedFilters, isTrue);
    });

    test(
      'locationPreservingScope keeps analytics filters when changing group',
      () {
        final base = TransactionsRoute.filtersFromUri(
          Uri.parse('/transactions?category=Housing&period=year&type=expense'),
        );
        final uri = Uri.parse(
          TransactionsRoute.locationPreservingScope(
            base,
            group: TransactionGroupType.category,
          ),
        );
        expect(uri.queryParameters['category'], 'Housing');
        expect(uri.queryParameters['period'], 'year');
        expect(uri.queryParameters['type'], 'expense');
        expect(uri.queryParameters['group'], 'category');
      },
    );

    test('localizedSummary describes category, period, type, and account', () {
      final summary =
          TransactionsRouteFilters(
            category: 'Housing',
            period: ExpensePeriod.year,
            type: TransactionTypeFilter.expense,
            account: 'Checking',
          ).localizedSummary(
            AppLocalizationsEn(),
            LocaleFormatting(const Locale('en')),
          );

      expect(summary, contains('Housing'));
      expect(summary, contains('Year'));
      expect(summary, contains('Expense'));
      expect(summary, contains('Checking'));
    });

    test('localizedSummary formats a custom date range', () {
      final summary =
          TransactionsRouteFilters(
            from: DateTime(2026, 1, 1),
            to: DateTime(2026, 1, 31),
          ).localizedSummary(
            AppLocalizationsEn(),
            LocaleFormatting(const Locale('en')),
          );

      expect(summary, '2026-01-01 – 2026-01-31');
    });

    test('filters parse reconciliation and tolerate malformed dates', () {
      final filters = TransactionsRoute.filtersFromUri(
        Uri.parse(
          '/transactions?period=month&from=bad&to=2026-xx-31'
          '&reconcile=1&reconciled_filter=unreconciled',
        ),
      );

      expect(filters.from, isNull);
      expect(filters.to, isNull);
      expect(filters.reconcile, isTrue);
      expect(filters.reconciledFilter, ReconciledFilter.unreconciled);
    });

    test('location normalizes accounts and emits reconciliation filters', () {
      final uri = Uri.parse(
        TransactionsRoute.location(
          accounts: [' Checking ', '', 'Checking', 'Savings'],
          reconcile: true,
          reconciledFilter: ReconciledFilter.reconciled,
        ),
      );

      expect(uri.queryParameters['accounts'], 'Checking,Savings');
      expect(uri.queryParameters['reconcile'], '1');
      expect(uri.queryParameters['reconciled_filter'], 'reconciled');
    });

    test('missing-field filters round-trip through the query', () {
      final uri = Uri.parse(
        TransactionsRoute.location(
          missingFields: const {
            TransactionField.tags,
            TransactionField.category,
          },
        ),
      );

      // Declaration order, so the same selection always makes the same link.
      expect(uri.queryParameters['missing'], 'category,tags');
      expect(TransactionsRoute.filtersFromUri(uri).missingFields, {
        TransactionField.category,
        TransactionField.tags,
      });
    });

    test('an unrecognised missing field is ignored, not fatal', () {
      // A stale link narrows the list less than it asked rather than failing
      // to open at all.
      final filters = TransactionsRoute.filtersFromUri(
        Uri.parse('/transactions?missing=category,colour'),
      );

      expect(filters.missingFields, {TransactionField.category});
    });

    test('no missing filter leaves the parameter off entirely', () {
      final uri = Uri.parse(TransactionsRoute.location());

      expect(uri.queryParameters.containsKey('missing'), isFalse);
      expect(TransactionsRoute.filtersFromUri(uri).missingFields, isEmpty);
    });

    test('state helpers read account, accounts, group, and filters', () {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/transactions',
            builder: (_, _) => const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);
      final uri = Uri.parse(
        '/transactions?account=Checking&accounts=Checking,Savings'
        '&group=payee&type=expense',
      );
      final state = GoRouterState(
        router.configuration,
        uri: uri,
        matchedLocation: '/transactions',
        fullPath: '/transactions',
        pathParameters: const {},
        pageKey: const ValueKey('transactions'),
      );

      expect(TransactionsRoute.accountFrom(state), 'Checking');
      expect(TransactionsRoute.accountsFrom(state), ['Checking', 'Savings']);
      expect(TransactionsRoute.groupFrom(state), TransactionGroupType.payee);
      expect(
        TransactionsRoute.filtersFrom(state).type,
        TransactionTypeFilter.expense,
      );
    });

    test('location applies date defaults for multi-year dashboard periods', () {
      final uri = Uri.parse(
        TransactionsRoute.location(
          defaultDashboardPeriod: DashboardPeriod.last2Years,
        ),
      );

      expect(uri.queryParameters['from'], isNotNull);
      expect(uri.queryParameters['to'], isNotNull);
    });

    test('locationPreservingScope retains base grouping and custom dates', () {
      final base = TransactionsRouteFilters(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
        group: TransactionGroupType.type,
      );

      final uri = Uri.parse(TransactionsRoute.locationPreservingScope(base));

      expect(uri.queryParameters['group'], 'type');
      expect(uri.queryParameters['from'], '2026-01-01');
      expect(uri.queryParameters['to'], '2026-01-31');
    });
  });
}
