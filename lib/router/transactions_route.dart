import 'package:go_router/go_router.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../providers/data_providers.dart';
import '../utils/locale_formatting.dart';
import '../utils/period_defaults.dart';
import 'route_query.dart';
import 'transaction_analytics_route.dart';

class TransactionsRouteFilters {
  final String? category;
  final ExpensePeriod period;
  final TransactionTypeFilter type;
  final String? account;
  final List<String> accounts;
  final DateTime? from;
  final DateTime? to;
  final TransactionGroupType group;
  final DashboardPeriod defaultDashboardPeriod;
  final bool reconcile;
  final ReconciledFilter reconciledFilter;

  /// Bookkeeping gaps the list is narrowed to, empty for no narrowing.
  final Set<TransactionField> missingFields;

  const TransactionsRouteFilters({
    this.category,
    this.period = ExpensePeriod.month,
    this.type = TransactionTypeFilter.all,
    this.account,
    this.accounts = const [],
    this.from,
    this.to,
    this.group = TransactionGroupType.date,
    this.defaultDashboardPeriod = kDefaultDashboardPeriod,
    this.reconcile = false,
    this.reconciledFilter = ReconciledFilter.all,
    this.missingFields = const {},
  });

  bool get hasCustomDateRange => from != null || to != null;

  ExpensePeriodParams get _defaultPeriodParams =>
      expenseParamsFromDashboardPeriod(defaultDashboardPeriod);

  bool get hasScopedFilters {
    if (category != null || type != TransactionTypeFilter.all) return true;
    if (period == ExpensePeriod.all && !hasCustomDateRange) return false;
    return !expenseFiltersMatchParams(period, from, to, _defaultPeriodParams);
  }

  String localizedSummary(
    AppLocalizations l10n,
    LocaleFormatting format, {
    bool isRacoon = false,
  }) {
    final parts = <String>[
      if (category != null && category!.isNotEmpty) category!,
      if (hasCustomDateRange)
        format.formatDateRange(
          from,
          to,
          ellipsis: l10n.dateEllipsis,
          separator: l10n.dateRangeSeparator,
        )
      else if (!expenseFiltersMatchParams(
        period,
        null,
        null,
        _defaultPeriodParams,
      ))
        period.localizedLabel(l10n),
      if (type != TransactionTypeFilter.all)
        type.localizedLabel(l10n, isRacoon: isRacoon),
      ?account,
    ];
    return parts.join(' · ');
  }
}

class TransactionsRoute {
  static const path = '/transactions';
  static const _accountsSeparator = ',';

  static String location({
    String? account,
    List<String>? accounts,
    TransactionGroupType group = TransactionGroupType.date,
    String? category,
    ExpensePeriod? period,
    TransactionTypeFilter type = TransactionTypeFilter.all,
    String? from,
    String? to,
    bool reconcile = false,
    ReconciledFilter reconciledFilter = ReconciledFilter.all,
    Set<TransactionField> missingFields = const {},
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) {
    final defaultParams = expenseParamsFromDashboardPeriod(
      defaultDashboardPeriod,
    );
    final hasSpecificEntityFilter =
        account != null ||
        (accounts != null && accounts.isNotEmpty) ||
        category != null;
    final resolvedPeriod =
        period ??
        (hasSpecificEntityFilter ? ExpensePeriod.all : defaultParams.period);
    final isAllPeriod = resolvedPeriod == ExpensePeriod.all;
    final resolvedFrom =
        from ??
        (period == null && isAllPeriod
            ? null
            : (period == null && defaultParams.from != null
                  ? ExpenseRouteFilters.formatDate(defaultParams.from!)
                  : null));
    final resolvedTo =
        to ??
        (period == null && isAllPeriod
            ? null
            : (period == null && defaultParams.to != null
                  ? ExpenseRouteFilters.formatDate(defaultParams.to!)
                  : null));
    final normalizedAccounts = (accounts ?? const <String>[])
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    return RouteQuery.build(path, {
      'account': account,
      'accounts': normalizedAccounts.isEmpty
          ? null
          : normalizedAccounts.join(_accountsSeparator),
      'group': group != TransactionGroupType.date ? group.name : null,
      'category': category,
      'period': encodeExpensePeriodParam(
        resolvedPeriod: resolvedPeriod,
        defaultParams: defaultParams,
        from: resolvedFrom,
        to: resolvedTo,
        periodWasExplicit: period != null || hasSpecificEntityFilter,
      ),
      'type': type != TransactionTypeFilter.all ? type.name : null,
      'from': resolvedFrom,
      'to': resolvedTo,
      'reconcile': reconcile ? '1' : null,
      'reconciled_filter': reconciledFilter != ReconciledFilter.all
          ? reconciledFilter.name
          : null,
      // Stable order so the same selection always makes the same link.
      'missing': missingFields.isEmpty
          ? null
          : (TransactionField.values
                    .where(missingFields.contains)
                    .map((field) => field.name)
                    .toList())
                .join(','),
    });
  }

  static TransactionsRouteFilters filtersFrom(
    GoRouterState state, {
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) =>
      filtersFromUri(state.uri, defaultDashboardPeriod: defaultDashboardPeriod);

  static TransactionsRouteFilters filtersFromUri(
    Uri uri, {
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) {
    final defaultParams = expenseParamsFromDashboardPeriod(
      defaultDashboardPeriod,
    );
    final from = _parseDate(RouteQuery.param(uri, 'from'));
    final to = _parseDate(RouteQuery.param(uri, 'to'));
    final hasPeriodParam = uri.queryParameters.containsKey('period');
    final hasCustomDates =
        uri.queryParameters.containsKey('from') ||
        uri.queryParameters.containsKey('to');

    final reconciledFilter = RouteQuery.enumFrom(
      uri,
      'reconciled_filter',
      ReconciledFilter.values,
      ReconciledFilter.all,
    );
    final missingFields = missingFieldsFromUri(uri);

    if (!hasPeriodParam && !hasCustomDates) {
      return TransactionsRouteFilters(
        category: RouteQuery.param(uri, 'category'),
        period: defaultParams.period,
        type: RouteQuery.enumFrom(
          uri,
          'type',
          TransactionTypeFilter.values,
          TransactionTypeFilter.all,
        ),
        account: RouteQuery.param(uri, 'account'),
        accounts: accountsFromUri(uri),
        from: defaultParams.from,
        to: defaultParams.to,
        group: groupFromUri(uri),
        defaultDashboardPeriod: defaultDashboardPeriod,
        reconcile: RouteQuery.param(uri, 'reconcile') == '1',
        reconciledFilter: reconciledFilter,
        missingFields: missingFields,
      );
    }

    return TransactionsRouteFilters(
      category: RouteQuery.param(uri, 'category'),
      period: RouteQuery.enumFrom(
        uri,
        'period',
        ExpensePeriod.values,
        defaultParams.period,
      ),
      type: RouteQuery.enumFrom(
        uri,
        'type',
        TransactionTypeFilter.values,
        TransactionTypeFilter.all,
      ),
      account: RouteQuery.param(uri, 'account'),
      accounts: accountsFromUri(uri),
      from: from,
      to: to,
      group: groupFromUri(uri),
      defaultDashboardPeriod: defaultDashboardPeriod,
      reconcile: RouteQuery.param(uri, 'reconcile') == '1',
      reconciledFilter: reconciledFilter,
      missingFields: missingFields,
    );
  }

  static String? accountFrom(GoRouterState state) =>
      RouteQuery.param(state.uri, 'account');

  static String? accountFromUri(Uri uri) => RouteQuery.param(uri, 'account');

  static List<String> accountsFrom(GoRouterState state) =>
      accountsFromUri(state.uri);

  /// Bookkeeping gaps named in `missing`, ignoring anything unrecognised.
  ///
  /// A stale link naming a field that no longer exists narrows the list less
  /// than asked rather than failing to open at all.
  static Set<TransactionField> missingFieldsFromUri(Uri uri) {
    final raw = RouteQuery.param(uri, 'missing');
    if (raw == null || raw.trim().isEmpty) return const {};
    final byName = {
      for (final field in TransactionField.values) field.name: field,
    };
    return {for (final name in raw.split(',')) ?byName[name.trim()]};
  }

  static List<String> accountsFromUri(Uri uri) {
    final raw = RouteQuery.param(uri, 'accounts');
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(_accountsSeparator)
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  static TransactionGroupType groupFrom(GoRouterState state) =>
      groupFromUri(state.uri);

  static TransactionGroupType groupFromUri(Uri uri) {
    return RouteQuery.enumFrom(
      uri,
      'group',
      TransactionGroupType.values,
      TransactionGroupType.date,
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  static String locationPreservingScope(
    TransactionsRouteFilters base, {
    String? account,
    List<String>? accounts,
    TransactionGroupType? group,
  }) {
    return location(
      account: account ?? base.account,
      accounts: accounts ?? base.accounts,
      group: group ?? base.group,
      category: base.category,
      period: base.period,
      type: base.type,
      from: base.from != null
          ? ExpenseRouteFilters.formatDate(base.from!)
          : null,
      to: base.to != null ? ExpenseRouteFilters.formatDate(base.to!) : null,
    );
  }
}
