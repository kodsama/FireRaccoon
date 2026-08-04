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
