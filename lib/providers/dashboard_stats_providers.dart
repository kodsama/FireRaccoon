import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../router/dashboard_route.dart';
import 'data_providers.dart';
import 'people_providers.dart';
import 'prognosis_settings_provider.dart';

typedef DashboardPeriodKey = ({
  DashboardPeriod period,
  DateTime? from,
  DateTime? to,
});

typedef DashboardKpisKey = ({
  DashboardPeriod period,
  DateTime? from,
  DateTime? to,
  String periodLabel,
});

typedef CashFlowBucketsKey = ({
  DashboardPeriod period,
  DateTime? from,
  DateTime? to,
  String languageCode,
});

extension DashboardRouteFiltersStats on DashboardRouteFilters {
  DashboardPeriodKey get periodKey => (period: period, from: from, to: to);
}

DashboardPeriodKey _periodFromKpis(DashboardKpisKey key) =>
    (period: key.period, from: key.from, to: key.to);

DashboardPeriodKey _periodFromBuckets(CashFlowBucketsKey key) =>
    (period: key.period, from: key.from, to: key.to);

class DashboardPeriodContext {
  final DateRangeBounds range;
  final DateRangeBounds? comparison;

  const DashboardPeriodContext({required this.range, required this.comparison});
}

List<Account> _accounts(Ref ref) => ref.watch(effectiveAccountsProvider);

List<Transaction> _transactions(Ref ref) =>
    ref.watch(filteredTransactionsProvider);

/// Transactions covering [key]'s period plus its comparison range.
///
/// The shared cache only holds the default lookback window; longer periods
/// (last year and beyond, or 'all') would silently compute wrong stats from
/// truncated data. For those, fetch the actual window and fall back to the
/// cache while the fetch is in flight.
List<Transaction> _transactionsForPeriod(Ref ref, DashboardPeriodKey key) {
  final context = ref.watch(dashboardPeriodContextProvider(key));
  final rangeStart = context.range.start;
  final comparisonStart = context.comparison?.start;

  DateTime? neededStart;
  if (rangeStart == null) {
    neededStart = null; // 'all': no lower bound.
  } else if (comparisonStart != null && comparisonStart.isBefore(rangeStart)) {
    neededStart = comparisonStart;
  } else {
    neededStart = rangeStart;
  }

  final cacheWindowStart = DateTime.now().subtract(const Duration(days: 365));
  if (neededStart != null && !neededStart.isBefore(cacheWindowStart)) {
    return _transactions(ref);
  }

  final fetchStart = neededStart == null
      ? DateTime(2000, 1, 1)
      : DateTime(neededStart.year, neededStart.month, neededStart.day);
  final ranged = ref.watch(
    rangedTransactionsProvider((start: fetchStart, end: null)),
  );
  return ranged.asData?.value ?? _transactions(ref);
}

/// Cached net worth breakdown shared by sidebar, dashboard, and MCP callers.
final netWorthBreakdownProvider = Provider<NetWorthBreakdown>((ref) {
  return computeNetWorthBreakdown(_accounts(ref));
});

/// Cached asset accounts list.
final assetAccountsProvider = Provider<List<Account>>((ref) {
  return assetAccounts(_accounts(ref));
});

/// Cached date ranges for a dashboard period selection.
final dashboardPeriodContextProvider =
    Provider.family<DashboardPeriodContext, DashboardPeriodKey>((ref, key) {
      return DashboardPeriodContext(
        range: resolveDashboardDateRange(
          period: key.period,
          customFrom: key.from,
          customTo: key.to,
        ),
        comparison: previousDashboardPeriodRange(
          period: key.period,
          customFrom: key.from,
          customTo: key.to,
        ),
      );
    });

/// Cached dashboard KPIs for a period.
final dashboardKpisProvider = Provider.autoDispose
    .family<DashboardKpis, DashboardKpisKey>((ref, key) {
      final period = ref.watch(
        dashboardPeriodContextProvider(_periodFromKpis(key)),
      );
      final netWorth = ref.watch(netWorthBreakdownProvider);
      final currency = ref.watch(primaryCurrencyProvider).asData?.value.symbol;

      return computeDashboardKpis(
        accounts: _accounts(ref),
        transactions: _transactionsForPeriod(ref, _periodFromKpis(key)),
        periodRange: period.range,
        comparisonRange: period.comparison,
        primaryCurrencySymbol: currency,
        periodLabel: key.periodLabel,
        netWorth: netWorth.netWorth,
      );
    });

/// Cached cash-flow buckets for charts and sparklines.
final cashFlowBucketsProvider = Provider.autoDispose
    .family<List<CashFlowBucket>, CashFlowBucketsKey>((ref, key) {
      final period = ref.watch(
        dashboardPeriodContextProvider(_periodFromBuckets(key)),
      );
      return computeCashFlowBuckets(
        _transactionsForPeriod(ref, _periodFromBuckets(key)),
        period.range,
        languageCode: key.languageCode,
      );
    });

/// Cached category breakdown for the selected period.
final categoryBreakdownProvider = Provider.autoDispose
    .family<List<CategoryBreakdown>, DashboardPeriodKey>((ref, key) {
      final period = ref.watch(dashboardPeriodContextProvider(key));
      return computeCategoryBreakdown(
        _transactionsForPeriod(ref, key),
        period.range,
      );
    });

/// Cached net-worth sparkline composed from shared breakdown + cash-flow buckets.
final netWorthSparklineProvider = Provider.autoDispose
    .family<List<double>, CashFlowBucketsKey>((ref, key) {
      final period = ref.watch(
        dashboardPeriodContextProvider(_periodFromBuckets(key)),
      );
      final netWorth = ref.watch(netWorthBreakdownProvider).netWorth;
      final buckets = ref.watch(cashFlowBucketsProvider(key));
      return netWorthSparkline(
        accounts: _accounts(ref),
        transactions: _transactionsForPeriod(ref, _periodFromBuckets(key)),
        range: period.range,
        languageCode: key.languageCode,
        netWorth: netWorth,
        buckets: buckets,
      );
    });

/// Cached month-to-date savings outlook.
final endOfMonthOutlookProvider = Provider<EndOfMonthOutlook>((ref) {
  return computeEndOfMonthOutlook(transactions: _transactions(ref));
});

/// Cached forward-looking net-worth projection for a period.
final projectionOutlookProvider = Provider.autoDispose
    .family<List<double>, DashboardPeriodKey>((ref, key) {
      final period = ref.watch(dashboardPeriodContextProvider(key));
      final netWorth = ref.watch(netWorthBreakdownProvider).netWorth;
      return projectionOutlook(
        netWorth,
        _transactionsForPeriod(ref, key),
        period.range,
      );
    });

/// Cached account prognosis shared across dashboard, accounts, and prognosis screens.
final accountPrognosisProvider = Provider<AccountPrognosisResult>((ref) {
  final bills = ref.watch(billsProvider).asData?.value ?? const [];
  final recurrences = ref.watch(recurrencesProvider).asData?.value ?? const [];
  final options = ref.watch(prognosisSettingsProvider).toOptions();

  return AccountPrognosisService.compute(
    accounts: _accounts(ref),
    transactions: _transactions(ref),
    bills: bills,
    recurrences: recurrences,
    options: options,
  );
});

/// Server-computed balance histories for account sparklines.
final accountBalanceHistoriesProvider =
    FutureProvider<Map<String, List<double>>>((ref) async {
      final api = ref.watch(apiServiceProvider);
      if (api == null) return const {};

      final accounts = await ref.watch(accountsProvider.future);
      final relevant = accounts
          .where(
            (account) => account.type == 'asset' || account.type == 'liability',
          )
          .toList();
      if (relevant.isEmpty) return const {};

      final end = DateTime.now();
      final start = DateTime(
        end.year,
        end.month,
        end.day,
      ).subtract(const Duration(days: 180));

      try {
        return await api.getAccountBalanceHistories(
          accounts: relevant,
          start: start,
          end: end,
        );
      } catch (_) {
        final transactions = await ref.watch(transactionsProvider.future);
        final openingDate = start.subtract(const Duration(days: 1));
        final openingEntries = await Future.wait(
          relevant.map((account) async {
            try {
              final balance = await api.getAccountBalanceAtDate(
                account.id,
                openingDate,
              );
              return MapEntry(account.id, balance);
            } catch (_) {
              return MapEntry(account.id, account.currentBalance);
            }
          }),
        );
        final openings = Map.fromEntries(openingEntries);
        return {
          for (final account in relevant)
            account.name: reconstructAccountBalanceInRange(
              accountName: account.name,
              openingBalance: openings[account.id] ?? account.currentBalance,
              transactions: transactions,
              start: start,
              end: end,
            ),
        };
      }
    });
