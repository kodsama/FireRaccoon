import '../models/transaction.dart';
import 'transaction_splits.dart';

enum SelectionState { none, partial, all }

/// Signed list-total amount for a transaction (deposits positive, others negative).
double signedTransactionAmount(Transaction transaction) {
  final total = transaction.totalAmount;
  return transaction.type == 'deposit' ? total : -total;
}

class TransactionMonthGroup {
  const TransactionMonthGroup({
    required this.year,
    required this.month,
    required this.transactions,
  });

  final int year;
  final int month;
  final List<Transaction> transactions;

  DateTime get sortDate => DateTime(year, month);
}

List<TransactionMonthGroup> groupTransactionsByMonth(
  List<Transaction> transactions,
) {
  final map = <String, List<Transaction>>{};
  for (final transaction in transactions) {
    final key = '${transaction.date.year}-${transaction.date.month}';
    map.putIfAbsent(key, () => []).add(transaction);
  }

  final groups = map.entries.map((entry) {
    final parts = entry.key.split('-');
    return TransactionMonthGroup(
      year: int.parse(parts[0]),
      month: int.parse(parts[1]),
      transactions: entry.value,
    );
  }).toList()..sort((a, b) => b.sortDate.compareTo(a.sortDate));

  for (final group in groups) {
    group.transactions.sort((a, b) => b.date.compareTo(a.date));
  }
  return groups;
}

int transactionMonthListItemCount(List<TransactionMonthGroup> groups) {
  return groups.fold<int>(
    0,
    (count, group) => count + 1 + group.transactions.length,
  );
}

double sumTransactionAmounts(
  Iterable<Transaction> transactions, {
  String? accountName,
}) {
  return transactions.fold<double>(
    0,
    (total, transaction) =>
        total + signedListAmount(transaction, accountName: accountName),
  );
}

/// Signed amount for list display: relative to [accountName] when viewing a
/// single account (transfers INTO it count positive), otherwise the generic
/// signing where only deposits are positive.
double signedListAmount(Transaction transaction, {String? accountName}) {
  if (accountName == null) return signedTransactionAmount(transaction);
  return signedAmountForAccount(transaction, accountName);
}

SelectionState selectionStateForIds({
  required Iterable<Transaction> transactions,
  required Set<String> selectedIds,
  required bool Function(Transaction transaction) isToggleable,
}) {
  final toggleable = transactions.where(isToggleable).toList();
  if (toggleable.isEmpty) return SelectionState.none;

  final selectedCount = toggleable
      .where((transaction) => selectedIds.contains(transaction.id))
      .length;
  if (selectedCount == 0) return SelectionState.none;
  if (selectedCount == toggleable.length) return SelectionState.all;
  return SelectionState.partial;
}

bool shouldSelectAllForIds({
  required Iterable<Transaction> transactions,
  required Set<String> selectedIds,
  required bool Function(Transaction transaction) isToggleable,
}) {
  return selectionStateForIds(
        transactions: transactions,
        selectedIds: selectedIds,
        isToggleable: isToggleable,
      ) !=
      SelectionState.all;
}

/// One entry per group id, with every journal that belongs to it.
///
/// Firefly paginates journals, not groups, so a group's legs can arrive split
/// across pages, and within a page it does not promise to keep them together.
/// Concatenating what came back then left a group as several entries sharing
/// one id, each carrying the total of its own fragment: an id that is no
/// longer unique, a total that is not the group's, and a six-leg bill reading
/// as two three-leg ones, which turns a check that a recurring split still has
/// all its legs into a false finding.
///
/// Keyed by id rather than merged run by run, so the order Firefly answers in
/// does not matter. Groups keep the order they were first seen in, and their
/// legs the order they arrived in.
List<Transaction> mergeTransactionGroups(List<Transaction> transactions) {
  final legsById = <String, List<Transaction>>{};
  final firstSeen = <String, Transaction>{};
  for (final transaction in transactions) {
    (legsById[transaction.id] ??= <Transaction>[]).addAll(
      transaction.resolvedSplits(),
    );
    firstSeen.putIfAbsent(transaction.id, () => transaction);
  }
  return [
    for (final entry in legsById.entries)
      if (entry.value.length == firstSeen[entry.key]!.resolvedSplits().length)
        firstSeen[entry.key]!
      else
        firstSeen[entry.key]!.copyWith(splits: entry.value),
  ];
}
