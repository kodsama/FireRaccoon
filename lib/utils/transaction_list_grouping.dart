import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../l10n/app_localizations.dart';
import '../providers/data_providers.dart';
import '../utils/display_labels.dart';
import '../utils/locale_formatting.dart';
import '../utils/search_filter.dart';
import '../l10n/l10n_extensions.dart';

class TransactionListGroup {
  final String key;
  final List<Transaction> transactions;
  final double sum;
  final String currencySymbol;
  final DateTime? sortDate;

  const TransactionListGroup({
    required this.key,
    required this.transactions,
    required this.sum,
    required this.currencySymbol,
    this.sortDate,
  });
}

class TransactionListGroups {
  final List<Transaction> filteredTransactions;
  final List<Transaction> futureTransactions;
  final List<TransactionListGroup> groups;

  const TransactionListGroups({
    required this.filteredTransactions,
    required this.futureTransactions,
    required this.groups,
  });

  Map<String, TransactionListGroup> get groupsByKey => {
    for (final group in groups) group.key: group,
  };

  List<String> get sortedKeys => groups.map((group) => group.key).toList();
}

TransactionListGroups buildTransactionListGroups({
  required List<Transaction> transactions,
  required Set<String> activeAccountFilters,
  required String searchQuery,
  required TransactionGroupType groupType,
  required LocaleFormatting format,
  required AppLocalizations l10n,
  bool isRacoon = false,
  ReconciledFilter reconciledFilter = ReconciledFilter.all,
  DateTime? referenceDate,
  String? sumAccount,
}) {
  final filtered = <Transaction>[];
  final future = <Transaction>[];
  final map = <String, _MutableTransactionListGroup>{};

  for (final transaction in transactions) {
    if (activeAccountFilters.isNotEmpty &&
        activeAccountFilters
            .intersection(transactionAccountNames(transaction))
            .isEmpty) {
      continue;
    }
    if (!transaction.matchesSearch(searchQuery)) continue;
    if (!matchesReconciledFilter(transaction, reconciledFilter)) continue;

    filtered.add(transaction);
    if (isFutureTransaction(transaction.date, reference: referenceDate)) {
      future.add(transaction);
      continue;
    }

    final key = _groupKeyFor(
      transaction,
      groupType: groupType,
      format: format,
      l10n: l10n,
      isRacoon: isRacoon,
    );
    final signedAmount = signedListAmount(transaction, accountName: sumAccount);
    final existing = map[key];
    if (existing == null) {
      map[key] = _MutableTransactionListGroup(
        key: key,
        transactions: [transaction],
        sum: signedAmount,
        currencySymbol: transaction.currencySymbol,
        sortDate: groupType == TransactionGroupType.date
            ? DateTime(transaction.date.year, transaction.date.month)
            : null,
      );
    } else {
      existing.transactions.add(transaction);
      existing.sum += signedAmount;
    }
  }

  // Newest first, the same direction as every dated group below, so the list
  // does not reverse itself where the future block begins.
  future.sort((a, b) => b.date.compareTo(a.date));

  final groups = map.values.map((group) {
    if (groupType == TransactionGroupType.date) {
      group.transactions.sort((a, b) => b.date.compareTo(a.date));
    }
    return TransactionListGroup(
      key: group.key,
      transactions: group.transactions,
      sum: group.sum,
      currencySymbol: group.currencySymbol,
      sortDate: group.sortDate,
    );
  }).toList();

  if (groupType == TransactionGroupType.date) {
    groups.sort((a, b) => b.sortDate!.compareTo(a.sortDate!));
  } else {
    groups.sort((a, b) => a.key.compareTo(b.key));
  }

  return TransactionListGroups(
    filteredTransactions: filtered,
    futureTransactions: future,
    groups: groups,
  );
}

String _groupKeyFor(
  Transaction transaction, {
  required TransactionGroupType groupType,
  required LocaleFormatting format,
  required AppLocalizations l10n,
  required bool isRacoon,
}) {
  final key = switch (groupType) {
    TransactionGroupType.date => format.formatMonthYear(transaction.date),
    TransactionGroupType.account =>
      transaction.type == 'deposit'
          ? transaction.destinationName
          : transaction.sourceName,
    TransactionGroupType.payee =>
      transaction.type == 'deposit'
          ? transaction.sourceName
          : transaction.destinationName,
    TransactionGroupType.type => localizedTransactionType(
      transaction.type,
      l10n,
      isRacoon: isRacoon,
    ),
    TransactionGroupType.category => displayLabelOrUnknown(
      transaction.categoryName,
      l10n,
    ),
  };
  return key.isEmpty ? l10n.unknown : key;
}

class _MutableTransactionListGroup {
  final String key;
  final List<Transaction> transactions;
  double sum;
  final String currencySymbol;
  final DateTime? sortDate;

  _MutableTransactionListGroup({
    required this.key,
    required this.transactions,
    required this.sum,
    required this.currencySymbol,
    this.sortDate,
  });
}
