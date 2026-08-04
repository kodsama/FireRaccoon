import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fireracoon/models/account.dart';
import 'package:fireracoon/models/transaction.dart';
import 'package:fireracoon/utils/dashboard_period.dart';
import 'package:fireracoon/utils/dashboard_stats.dart';
import 'package:fireracoon/utils/transaction_filters.dart';

Account _account({
  required String name,
  required String type,
  double balance = 0,
}) {
  return Account(
    id: name,
    name: name,
    type: type,
    role: 'defaultAsset',
    currentBalance: balance,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

Transaction _tx({
  required String type,
  required DateTime date,
  double amount = 100,
  String category = 'Food',
}) {
  return Transaction(
    id: '${type}_${date.millisecondsSinceEpoch}',
    type: type,
    date: date,
    amount: amount,
    description: 'Test',
    sourceName: 'Checking',
    destinationName: 'Groceries',
    categoryName: category,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  group('computeNetWorthBreakdown', () {
    test('computes assets, liabilities, and net worth in one pass', () {
      final breakdown = computeNetWorthBreakdown([
        _account(name: 'Checking', type: 'asset', balance: 187_008.05),
        _account(name: 'Mortgage', type: 'liability', balance: -2_629_887),
      ]);

      expect(breakdown.assets, 187_008.05);
      expect(breakdown.liabilities, 2_629_887);
      expect(breakdown.netWorth, closeTo(-2_442_878.95, 0.01));
    });

    test('excludes inactive accounts from net worth', () {
      final breakdown = computeNetWorthBreakdown([
        _account(name: 'Checking', type: 'asset', balance: 1000),
        Account(
          id: 'old',
          name: 'Closed virtuel',
          type: 'asset',
          role: 'defaultAsset',
          currentBalance: -14527.62,
          currencySymbol: 'kr',
          currencyCode: 'SEK',
          active: false,
        ),
        _account(name: 'Old loan', type: 'liability', balance: -500),
        Account(
          id: 'old-loan-closed',
          name: 'Closed loan',
          type: 'liability',
          role: 'defaultAsset',
          currentBalance: -99999,
          currencySymbol: 'kr',
          currencyCode: 'SEK',
          active: false,
        ),
      ]);

      expect(breakdown.assets, 1000);
      expect(breakdown.liabilities, 500);
      expect(breakdown.netWorth, 500);
    });
  });

  group('computeNetWorth', () {
    test('subtracts liabilities from assets', () {
      final netWorth = computeNetWorth([
        _account(name: 'Checking', type: 'asset', balance: 1000),
        _account(name: 'Loan', type: 'liability', balance: 200),
      ]);
      expect(netWorth, 800);
    });

    test('subtracts liability magnitude when source balance is negative', () {
      final netWorth = computeNetWorth([
        _account(name: 'Checking', type: 'asset', balance: 1000),
        _account(name: 'Credit Card', type: 'liability', balance: -200),
      ]);
      expect(netWorth, 800);
    });

    test('returns negative net worth when liabilities exceed assets', () {
      final netWorth = computeNetWorth([
        _account(name: 'Checking', type: 'asset', balance: 187_008.05),
        _account(name: 'Mortgage', type: 'liability', balance: -2_629_887),
      ]);
      expect(netWorth, closeTo(-2_442_878.95, 0.01));
    });
  });

  group('computeLiabilitiesTotal', () {
    test('sums absolute liability balances for display', () {
      final total = computeLiabilitiesTotal([
        _account(name: 'Card', type: 'liability', balance: -120.5),
        _account(name: 'Loan', type: 'liability', balance: -200),
      ]);
      expect(total, 320.5);
    });
  });

  group('computeDashboardKpis', () {
    test('uses selected period transactions only', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.thisMonth,
        reference: DateTime(2026, 7, 15),
      );
      final comparison = previousDashboardPeriodRange(
        period: DashboardPeriod.thisMonth,
        reference: DateTime(2026, 7, 15),
      );
      final kpis = computeDashboardKpis(
        accounts: [_account(name: 'Checking', type: 'asset', balance: 500)],
        transactions: [
          _tx(type: 'deposit', date: DateTime(2026, 7, 5), amount: 300),
          _tx(type: 'withdrawal', date: DateTime(2026, 7, 10), amount: 100),
          _tx(type: 'deposit', date: DateTime(2026, 6, 10), amount: 900),
        ],
        periodRange: range,
        comparisonRange: comparison,
        periodLabel: 'July',
      );

      expect(kpis.periodIncome, 300);
      expect(kpis.periodSpending, 100);
      expect(kpis.periodSaved, 200);
      expect(kpis.periodLabel, 'July');
      expect(kpis.totalBalance, 500);
    });
  });

  group('computeCashFlowBuckets', () {
    test('returns monthly buckets for this year', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.thisYear,
        reference: DateTime(2026, 7, 15),
      );
      final buckets = computeCashFlowBuckets(
        [
          _tx(type: 'deposit', date: DateTime(2026, 7, 1), amount: 100),
          _tx(type: 'withdrawal', date: DateTime(2026, 6, 1), amount: 50),
        ],
        range,
        reference: DateTime(2026, 7, 15),
        languageCode: 'en',
      );

      expect(buckets.length, greaterThanOrEqualTo(2));
      final totalIncome = buckets.fold(
        0.0,
        (sum, bucket) => sum + bucket.income,
      );
      final totalSpending = buckets.fold(
        0.0,
        (sum, bucket) => sum + bucket.spending,
      );
      expect(totalIncome, 100);
      expect(totalSpending, 50);
    });

    test('drops leading and trailing empty months but keeps gaps', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.thisYear,
        reference: DateTime(2026, 7, 15),
      );
      final buckets = computeCashFlowBuckets(
        [
          _tx(type: 'deposit', date: DateTime(2026, 2, 1), amount: 100),
          _tx(type: 'withdrawal', date: DateTime(2026, 4, 1), amount: 50),
          _tx(type: 'deposit', date: DateTime(2026, 7, 1), amount: 25),
        ],
        range,
        reference: DateTime(2026, 7, 15),
        languageCode: 'en',
      );

      expect(buckets.first.label, 'Feb');
      expect(buckets.last.label, 'Jul');
      expect(buckets.map((bucket) => bucket.label), contains('Mar'));
      expect(buckets.map((bucket) => bucket.label), isNot(contains('Jan')));
      expect(buckets.map((bucket) => bucket.label), isNot(contains('Aug')));
      expect(
        buckets.singleWhere((bucket) => bucket.label == 'Mar').hasActivity,
        isFalse,
      );
    });
  });

  group('computeCategoryBreakdown', () {
    test('ranks expense categories for selected range', () {
      final range = DateRangeBounds(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      );
      final categories = computeCategoryBreakdown([
        _tx(
          type: 'withdrawal',
          date: DateTime(2026, 7, 2),
          amount: 80,
          category: 'Food',
        ),
        _tx(
          type: 'withdrawal',
          date: DateTime(2026, 7, 3),
          amount: 20,
          category: 'Travel',
        ),
        _tx(
          type: 'withdrawal',
          date: DateTime(2026, 6, 3),
          amount: 999,
          category: 'Old',
        ),
      ], range);

      expect(categories, hasLength(2));
      expect(categories.first.name, 'Food');
      expect(categories.first.amount, 80);
    });
  });

  group('recentTransactions', () {
    test('returns newest transactions first within range', () {
      final range = DateRangeBounds(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      );
      final recent = recentTransactions(
        [
          _tx(type: 'deposit', date: DateTime(2026, 7, 1)),
          _tx(type: 'deposit', date: DateTime(2026, 7, 10)),
        ],
        range,
        limit: 1,
      );

      expect(recent, hasLength(1));
      expect(recent.first.date.day, 10);
    });
  });
}
