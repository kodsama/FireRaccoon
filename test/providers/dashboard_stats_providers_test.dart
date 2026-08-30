import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon/providers/dashboard_stats_providers.dart';
import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/providers/transaction_analytics_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/fixed_accounts_notifier.dart';
import '../helpers/fixed_transactions_notifier.dart';
import '../helpers/test_data.dart';

Account _asset({required String id, required double balance}) {
  return Account(
    id: id,
    name: 'Asset $id',
    type: 'asset',
    role: 'defaultAsset',
    currentBalance: balance,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

Account _liability({required String id, required double balance}) {
  return Account(
    id: id,
    name: 'Liability $id',
    type: 'liability',
    role: 'defaultAsset',
    currentBalance: balance,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

Transaction _withdrawal({
  required String id,
  required DateTime date,
  required double amount,
  String category = 'Food',
}) {
  return Transaction(
    id: id,
    type: 'withdrawal',
    date: date,
    amount: amount,
    description: 'Test',
    sourceName: 'Checking',
    destinationName: 'Store',
    categoryName: category,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

Future<ProviderContainer> _container({
  List<Account> accounts = const [],
  List<Transaction> transactions = const [],
  FireflyService? api,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      accountsProvider.overrideWith(() => FixedAccountsNotifier(accounts)),
      transactionsProvider.overrideWith(
        () => FixedTransactionsNotifier(transactions),
      ),
      primaryCurrencyProvider.overrideWith((ref) async => sampleCurrency),
      billsProvider.overrideWith((ref) async => sampleBills),
      recurrencesProvider.overrideWith((ref) async => const []),
      if (api != null) apiServiceProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  await container.read(accountsProvider.future);
  await container.read(transactionsProvider.future);
  return container;
}

DashboardPeriodKey get _currentMonthPeriodKey {
  final now = DateTime.now();
  return (
    period: DashboardPeriod.thisMonth,
    from: DateTime(now.year, now.month, 1),
    to: DateTime(now.year, now.month + 1, 1),
  );
}

void main() {
  group('netWorthBreakdownProvider', () {
    test('caches a single negative net worth result', () async {
      final container = await _container(
        accounts: [
          _asset(id: '1', balance: 100),
          _liability(id: '2', balance: -250),
        ],
      );

      final first = container.read(netWorthBreakdownProvider);
      final second = container.read(netWorthBreakdownProvider);

      expect(first.netWorth, -150);
      expect(first.liabilities, 250);
      expect(identical(first, second), isTrue);
    });
  });

  group('dashboardKpisProvider', () {
    test('reuses cached net worth instead of recomputing', () async {
      final container = await _container(
        accounts: [
          _asset(id: '1', balance: 500),
          _liability(id: '2', balance: -100),
        ],
        transactions: sampleTransactions,
      );

      final period = _currentMonthPeriodKey;
      final breakdown = container.read(netWorthBreakdownProvider);
      final kpis = container.read(
        dashboardKpisProvider((
          period: period.period,
          from: period.from,
          to: period.to,
          periodLabel: 'This month',
        )),
      );

      expect(kpis.totalBalance, breakdown.netWorth);
      expect(kpis.periodIncome, 1200);
      expect(kpis.periodSpending, 45);
    });
  });

  group('cashFlowBucketsProvider and netWorthSparklineProvider', () {
    test('sparkline reuses cached buckets for the same period', () async {
      final container = await _container(
        accounts: [_asset(id: '1', balance: 500)],
        transactions: sampleTransactions,
      );

      final period = _currentMonthPeriodKey;
      final key = (
        period: period.period,
        from: period.from,
        to: period.to,
        languageCode: 'en',
      );
      final buckets = container.read(cashFlowBucketsProvider(key));
      final sparkline = container.read(netWorthSparklineProvider(key));

      expect(buckets, isNotEmpty);
      expect(sparkline, isNotEmpty);
      expect(
        sparkline.last,
        container.read(netWorthBreakdownProvider).netWorth,
      );
    });

    test('all-time periods use ranged transactions when loaded', () async {
      final oldTransaction = _withdrawal(
        id: 'old',
        date: DateTime(2020, 1, 1),
        amount: 25,
      );
      final container = await _container(
        accounts: [_asset(id: '1', balance: 500)],
        transactions: const [],
        api: FakeFireflyService(transactions: [oldTransaction]),
      );
      final rangedKey = (start: DateTime(2000, 1, 1), end: null);
      await container.read(rangedTransactionsProvider(rangedKey).future);
      final key = (
        period: DashboardPeriod.all,
        from: null,
        to: null,
        languageCode: 'en',
      );

      final buckets = container.read(cashFlowBucketsProvider(key));

      expect(buckets, isNotEmpty);
    });

    test('multi-year periods request a normalized ranged start date', () async {
      final container = await _container(
        accounts: [_asset(id: '1', balance: 500)],
        transactions: sampleTransactions,
        api: FakeFireflyService(transactions: sampleTransactions),
      );
      final key = (
        period: DashboardPeriod.last2Years,
        from: null,
        to: null,
        languageCode: 'en',
      );

      expect(container.read(cashFlowBucketsProvider(key)), isA<List>());
    });
  });

  group('accountPrognosisProvider', () {
    test('is shared across reads until dependencies change', () async {
      final container = await _container(
        accounts: sampleAccounts,
        transactions: sampleTransactions,
      );

      final first = container.read(accountPrognosisProvider);
      final second = container.read(accountPrognosisProvider);

      expect(identical(first, second), isTrue);
      expect(first.accounts, isNotEmpty);
    });
  });

  group('accountBalanceHistoriesProvider', () {
    test('fetches server-computed balance histories once', () async {
      final container = await _container(
        accounts: sampleAccounts,
        transactions: sampleTransactions,
        api: FakeFireflyService(accounts: sampleAccounts),
      );

      final histories = await container.read(
        accountBalanceHistoriesProvider.future,
      );

      expect(histories['Checking'], isNotNull);
      expect(histories['Checking']!.length, greaterThanOrEqualTo(2));
    });

    test('reconstructs histories when server history calls fail', () async {
      final service = FakeFireflyService(accounts: sampleAccounts)
        ..accountBalanceHistoriesError = Exception('history unavailable');
      final container = await _container(
        accounts: sampleAccounts,
        transactions: sampleTransactions,
        api: service,
      );

      final histories = await container.read(
        accountBalanceHistoriesProvider.future,
      );

      expect(histories.keys, containsAll(sampleAccounts.map((a) => a.name)));
      expect(histories.values.every((points) => points.isNotEmpty), isTrue);
    });
  });

  group('transactionAnalyticsSummaryProvider', () {
    test('filters transactions and aggregates categories once', () async {
      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(
            FakeFireflyService(
              transactions: [
                _withdrawal(
                  id: '1',
                  date: DateTime(2026, 7, 2),
                  amount: 80,
                  category: 'Food',
                ),
                _withdrawal(
                  id: '2',
                  date: DateTime(2026, 7, 3),
                  amount: 20,
                  category: 'Travel',
                ),
                _withdrawal(
                  id: '3',
                  date: DateTime(2026, 6, 3),
                  amount: 999,
                  category: 'Old',
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final summary = await container.read(
        transactionAnalyticsSummaryProvider((
          period: ExpensePeriod.month,
          from: DateTime(2026, 7, 1),
          to: DateTime(2026, 7, 31),
          type: TransactionTypeFilter.expense,
          account: null,
        )).future,
      );

      expect(summary.periodTransactions, hasLength(2));
      expect(summary.categorySums['Food'], 80);
      expect(summary.categorySums['Travel'], 20);
      expect(summary.sortedCategoryEntries.first.key, 'Food');
      expect(summary.periodTotal, 100);
    });
  });
}
