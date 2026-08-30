import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:test/test.dart';

Account _account({
  required String name,
  required String type,
  double balance = 0,
  bool active = true,
}) {
  return Account(
    id: name,
    name: name,
    type: type,
    role: 'defaultAsset',
    currentBalance: balance,
    currencySymbol: '€',
    currencyCode: 'EUR',
    active: active,
  );
}

Transaction _tx({
  required String type,
  required DateTime date,
  double amount = 100,
  String category = 'Food',
  String source = 'Checking',
  String destination = 'Groceries',
  String id = '',
}) {
  return Transaction(
    id: id.isEmpty ? '${type}_${date.millisecondsSinceEpoch}' : id,
    type: type,
    date: date,
    amount: amount,
    description: 'Test',
    sourceName: source,
    destinationName: destination,
    categoryName: category,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('fr');
  });

  group('resolveCurrency', () {
    test('prefers primary symbol then first transaction then euro', () {
      expect(resolveCurrency('kr', const []), 'kr');
      expect(
        resolveCurrency(null, [
          _tx(type: 'deposit', date: DateTime(2026, 1, 1)),
        ]),
        '€',
      );
      expect(resolveCurrency('', const []), '€');
      expect(resolveCurrency(null, const []), '€');
    });
  });

  group('net worth helpers', () {
    test('computeNetWorthBreakdown excludes inactive accounts', () {
      final breakdown = computeNetWorthBreakdown([
        _account(name: 'Checking', type: 'asset', balance: 1000),
        _account(name: 'Closed', type: 'asset', balance: -500, active: false),
        _account(name: 'Loan', type: 'liability', balance: -200),
        _account(
          name: 'Old loan',
          type: 'liability',
          balance: -999,
          active: false,
        ),
      ]);
      expect(breakdown.assets, 1000);
      expect(breakdown.liabilities, 200);
      expect(breakdown.netWorth, 800);
    });

    test('asset and liability totals and assetAccounts filter', () {
      final accounts = [
        _account(name: 'Checking', type: 'asset', balance: 1000),
        _account(name: 'Loan', type: 'liability', balance: -200),
        _account(name: 'Expense', type: 'expense', balance: 0),
      ];
      expect(computeAssetsTotal(accounts), 1000);
      expect(computeLiabilitiesTotal(accounts), 200);
      expect(computeNetWorth(accounts), 800);
      expect(assetAccounts(accounts).map((a) => a.name), ['Checking']);
    });
  });

  group('computeDashboardKpis', () {
    test('period totals and percent deltas vs comparison', () {
      final period = DateRangeBounds(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      );
      final prior = DateRangeBounds(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 7, 1),
      );
      final kpis = computeDashboardKpis(
        accounts: [_account(name: 'Checking', type: 'asset', balance: 500)],
        transactions: [
          _tx(type: 'deposit', date: DateTime(2026, 7, 5), amount: 300),
          _tx(type: 'withdrawal', date: DateTime(2026, 7, 10), amount: 100),
          _tx(type: 'deposit', date: DateTime(2026, 6, 10), amount: 200),
          _tx(type: 'withdrawal', date: DateTime(2026, 6, 12), amount: 50),
        ],
        periodRange: period,
        comparisonRange: prior,
        periodLabel: 'July',
        primaryCurrencySymbol: 'kr',
      );

      expect(kpis.periodIncome, 300);
      expect(kpis.periodSpending, 100);
      expect(kpis.periodSaved, 200);
      expect(kpis.periodLabel, 'July');
      expect(kpis.currency, 'kr');
      expect(kpis.incomeDelta.kind, DeltaKind.percent);
      expect(kpis.spendingDelta.kind, DeltaKind.percent);
      expect(kpis.savedDelta.kind, DeltaKind.percent);
    });

    test('noChange and newActivity delta kinds', () {
      final period = DateRangeBounds(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      );
      final prior = DateRangeBounds(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 7, 1),
      );

      final flat = computeDashboardKpis(
        accounts: [_account(name: 'Checking', type: 'asset', balance: 0)],
        transactions: const [],
        periodRange: period,
        comparisonRange: prior,
        periodLabel: 'July',
      );
      expect(flat.incomeDelta.kind, DeltaKind.noChange);

      final fresh = computeDashboardKpis(
        accounts: [_account(name: 'Checking', type: 'asset', balance: 0)],
        transactions: [
          _tx(type: 'deposit', date: DateTime(2026, 7, 5), amount: 50),
        ],
        periodRange: period,
        comparisonRange: prior,
        periodLabel: 'July',
      );
      expect(fresh.incomeDelta.kind, DeltaKind.newActivity);

      final noCompare = computeDashboardKpis(
        accounts: [_account(name: 'Checking', type: 'asset', balance: 10)],
        transactions: const [],
        periodRange: period,
        periodLabel: 'July',
        netWorth: 42,
      );
      expect(noCompare.totalBalance, 42);
      expect(noCompare.incomeDelta.kind, DeltaKind.noChange);
    });
  });

  group('computeCashFlowBuckets', () {
    test('monthly buckets for this year and trims empty edges', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.thisYear,
        reference: DateTime(2026, 7, 15),
      );
      final buckets = computeCashFlowBuckets(
        [
          _tx(type: 'deposit', date: DateTime(2026, 2, 1), amount: 100),
          _tx(type: 'withdrawal', date: DateTime(2026, 4, 1), amount: 50),
          _tx(type: 'deposit', date: DateTime(2026, 7, 1), amount: 25),
          _tx(type: 'transfer', date: DateTime(2026, 7, 2), amount: 10),
        ],
        range,
        reference: DateTime(2026, 7, 15),
        languageCode: 'en',
      );

      expect(buckets.first.label, 'Feb');
      expect(buckets.last.label, 'Jul');
      expect(buckets.map((b) => b.label), contains('Mar'));
      expect(buckets.singleWhere((b) => b.label == 'Mar').hasActivity, isFalse);

      final frMonths = computeCashFlowBuckets(
        [_tx(type: 'deposit', date: DateTime(2026, 2, 1), amount: 100)],
        range,
        reference: DateTime(2026, 7, 15),
        languageCode: 'fr',
      );
      expect(frMonths, isNotEmpty);
    });

    test('day buckets for short ranges', () {
      final buckets = computeCashFlowBuckets(
        [
          _tx(type: 'deposit', date: DateTime(2026, 7, 2), amount: 40),
          _tx(type: 'withdrawal', date: DateTime(2026, 7, 3), amount: 10),
        ],
        DateRangeBounds(
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 10),
        ),
        languageCode: 'fr',
      );
      expect(buckets, isNotEmpty);
      expect(buckets.fold(0.0, (s, b) => s + b.income), 40);
      expect(buckets.fold(0.0, (s, b) => s + b.spending), 10);
    });

    test('week buckets for medium ranges', () {
      final buckets = computeCashFlowBuckets(
        [_tx(type: 'deposit', date: DateTime(2026, 7, 5), amount: 80)],
        DateRangeBounds(start: DateTime(2026, 6, 1), end: DateTime(2026, 8, 1)),
        languageCode: 'fr',
      );
      expect(buckets.any((b) => b.income == 80), isTrue);
    });

    test('quarter buckets for long ranges', () {
      final buckets = computeCashFlowBuckets(
        [
          _tx(type: 'deposit', date: DateTime(2024, 3, 1), amount: 10),
          _tx(type: 'withdrawal', date: DateTime(2025, 9, 1), amount: 5),
        ],
        DateRangeBounds(start: DateTime(2024, 1, 1), end: DateTime(2026, 1, 1)),
        languageCode: 'en',
      );
      expect(buckets.any((b) => b.label.startsWith('Q')), isTrue);
      expect(buckets.fold(0.0, (s, b) => s + b.income), 10);
      expect(buckets.fold(0.0, (s, b) => s + b.spending), 5);
    });

    test('all-time uses year buckets', () {
      final buckets = computeCashFlowBuckets(
        [
          _tx(type: 'deposit', date: DateTime(2024, 5, 1), amount: 10),
          _tx(type: 'deposit', date: DateTime(2025, 5, 1), amount: 20),
        ],
        const DateRangeBounds(),
        languageCode: 'en',
      );
      expect(buckets, hasLength(2));
      expect(buckets.map((b) => b.income), [10, 20]);

      final frYears = computeCashFlowBuckets(
        [_tx(type: 'deposit', date: DateTime(2024, 5, 1), amount: 10)],
        const DateRangeBounds(),
        languageCode: 'fr',
      );
      expect(frYears, hasLength(1));
    });

    test('all-time with no transactions is empty', () {
      expect(
        computeCashFlowBuckets(const [], const DateRangeBounds()),
        isEmpty,
      );
    });

    test('trimEmptyCashFlowEdges returns empty when none have activity', () {
      expect(
        trimEmptyCashFlowEdges(const [
          CashFlowBucket(label: 'a', income: 0, spending: 0),
        ]),
        isEmpty,
      );
      expect(trimEmptyCashFlowEdges(const []), isEmpty);
    });

    test('open-ended range uses reference for end', () {
      final buckets = computeCashFlowBuckets(
        [_tx(type: 'deposit', date: DateTime(2026, 7, 2), amount: 15)],
        DateRangeBounds(start: DateTime(2026, 7, 1)),
        reference: DateTime(2026, 7, 8),
        languageCode: 'en',
      );
      expect(buckets.fold(0.0, (s, b) => s + b.income), 15);
    });
  });

  group('categories and recent', () {
    test('computeCategoryBreakdown ranks expenses', () {
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
          type: 'deposit',
          date: DateTime(2026, 7, 3),
          amount: 999,
          category: 'Income',
        ),
      ], range);

      expect(categories, hasLength(2));
      expect(categories.first.name, 'Food');
      expect(categories.first.share, closeTo(0.8, 0.001));
    });

    test('computeCategoryBreakdown empty when no expenses', () {
      expect(
        computeCategoryBreakdown(const [], const DateRangeBounds()),
        isEmpty,
      );
    });

    test('recentTransactions and transactionsInRange sort newest first', () {
      final range = DateRangeBounds(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      );
      final txs = [
        _tx(type: 'deposit', date: DateTime(2026, 7, 1), id: 'a'),
        _tx(type: 'deposit', date: DateTime(2026, 7, 10), id: 'b'),
        _tx(type: 'deposit', date: DateTime(2026, 6, 1), id: 'old'),
      ];
      final recent = recentTransactions(txs, range, limit: 1);
      expect(recent.single.id, 'b');

      final inRange = transactionsInRange(txs, range);
      expect(inRange.map((t) => t.id), ['b', 'a']);
    });
  });

  group('outlook and sparklines', () {
    test('computeEndOfMonthOutlook projects savings and warning', () {
      final ok = computeEndOfMonthOutlook(
        transactions: [
          _tx(type: 'deposit', date: DateTime(2026, 7, 2), amount: 300),
          _tx(type: 'withdrawal', date: DateTime(2026, 7, 3), amount: 50),
        ],
        reference: DateTime(2026, 7, 10),
      );
      expect(ok.savedSoFarPositive, isTrue);
      expect(ok.showWarning, isFalse);
      expect(ok.projectedSavings, greaterThan(0));

      final warn = computeEndOfMonthOutlook(
        transactions: [
          _tx(type: 'withdrawal', date: DateTime(2026, 7, 2), amount: 500),
        ],
        reference: DateTime(2026, 7, 10),
      );
      expect(warn.savedSoFarPositive, isFalse);
      expect(warn.showWarning, isTrue);

      // Hits the DateTime.now() fallback when reference is omitted.
      final live = computeEndOfMonthOutlook(transactions: const []);
      expect(live.projectedSavings, 0);
    });

    test('reconstructAccountBalance walks history backwards', () {
      final history = reconstructAccountBalance('Checking', 130, [
        _tx(
          type: 'deposit',
          date: DateTime(2026, 7, 2),
          amount: 50,
          source: 'Job',
          destination: 'Checking',
          id: 'in',
        ),
        _tx(
          type: 'withdrawal',
          date: DateTime(2026, 7, 3),
          amount: 20,
          source: 'Checking',
          destination: 'Store',
          id: 'out',
        ),
      ]);
      expect(history.last, 130);
      expect(history.length, greaterThanOrEqualTo(2));

      final lonely = reconstructAccountBalance('Checking', 50, const []);
      expect(lonely, [50, 50]);
    });

    test('reconstructAccountBalanceInRange pads short history', () {
      final history = reconstructAccountBalanceInRange(
        accountName: 'Checking',
        openingBalance: 100,
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
        transactions: const [],
      );
      expect(history, [100, 100]);
    });

    test('netWorthSparkline helpers', () {
      final fromBuckets = netWorthSparklineFromBuckets(
        netWorth: 1000,
        buckets: const [CashFlowBucket(label: 'a', income: 100, spending: 40)],
      );
      expect(fromBuckets.last, 1000);
      expect(fromBuckets.first, 940);
      expect(netWorthSparklineFromBuckets(netWorth: 5, buckets: const []), [
        5,
        5,
      ]);

      final spark = netWorthSparkline(
        accounts: [_account(name: 'Checking', type: 'asset', balance: 1000)],
        transactions: [
          _tx(type: 'deposit', date: DateTime(2026, 7, 5), amount: 100),
        ],
        range: DateRangeBounds(
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 8, 1),
        ),
      );
      expect(spark, isNotEmpty);
    });

    test('projectionOutlook clamps negatives to zero', () {
      final outlook = projectionOutlook(
        100,
        [_tx(type: 'withdrawal', date: DateTime(2026, 7, 2), amount: 50)],
        DateRangeBounds(
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 11),
        ),
        days: 5,
      );
      expect(outlook, hasLength(6));
      expect(outlook.every((v) => v >= 0), isTrue);

      final allTime = projectionOutlook(
        50,
        [_tx(type: 'deposit', date: DateTime(2026, 1, 1), amount: 10)],
        const DateRangeBounds(),
        days: 3,
      );
      expect(allTime, hasLength(4));
    });
  });
}
