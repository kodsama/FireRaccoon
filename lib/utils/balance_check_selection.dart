import 'package:fireraccoon_engine/fireraccoon_engine.dart';

/// How a row should look while picking transactions in balance-check mode.
enum BalanceCheckVisual {
  /// Already reconciled and still included in the check (green check).
  reconciledIncluded,

  /// Was reconciled, but excluded from this check (pending un-reconcile).
  reconciledExcluded,

  /// Not reconciled yet, included to be reconciled (accent check).
  pendingInclude,

  /// Not reconciled and not included (empty circle).
  unselected,
}

/// Ephemeral selection state for balance-check reconciliation on the transactions page.
///
/// Reconciled journals start included and stay included when new pages load,
/// unless the user puts them in [excludedIds]. Unreconciled journals start
/// excluded and are opted in via [includedIds].
class BalanceCheckSelection {
  const BalanceCheckSelection({
    required this.includedIds,
    required this.excludedIds,
    required this.onToggle,
  });

  /// Unreconciled journals the user has opted into the check.
  final Set<String> includedIds;

  /// Reconciled journals the user has explicitly removed from the check.
  final Set<String> excludedIds;

  final void Function(Transaction transaction) onToggle;

  bool isSelected(Transaction transaction) {
    if (transaction.isPartiallyReconciled) {
      return !excludedIds.contains(transaction.id);
    }
    if (transaction.isReconciled) {
      return !excludedIds.contains(transaction.id);
    }
    return includedIds.contains(transaction.id);
  }

  SelectionState stateFor(Transaction transaction) {
    if (transaction.isPartiallyReconciled && isSelected(transaction)) {
      return SelectionState.partial;
    }
    if (isSelected(transaction)) return SelectionState.all;
    return SelectionState.none;
  }

  /// A part-reconciled group can be toggled like any other.
  ///
  /// It used to be refused, and nothing else would finish it either: it landed
  /// in neither list [balanceCheckReconcileChanges] builds, so there was no way
  /// to reconcile the rest of it or to undo the part already done. Refusing the
  /// only control that could have fixed it left it stuck for good.
  bool canToggle(Transaction transaction) => true;

  BalanceCheckVisual visualFor(Transaction transaction) {
    final selected = isSelected(transaction);
    final reconciled = transaction.isReconciled;
    if (reconciled && selected) return BalanceCheckVisual.reconciledIncluded;
    if (reconciled && !selected) return BalanceCheckVisual.reconciledExcluded;
    if (selected) return BalanceCheckVisual.pendingInclude;
    return BalanceCheckVisual.unselected;
  }
}

/// No ephemeral picks needed at start — reconciled journals count automatically.
Set<String> defaultBalanceCheckIncludedIds(Iterable<Transaction> transactions) {
  return {};
}

Set<String> defaultBalanceCheckExcludedIds(Iterable<Transaction> transactions) {
  return {};
}

/// @Deprecated Use [defaultBalanceCheckIncludedIds] — kept as a thin alias for
/// call sites that still pass a single set during migration.
Set<String> defaultBalanceCheckSelection(Iterable<Transaction> transactions) {
  return defaultBalanceCheckIncludedIds(transactions);
}

void syncBalanceCheckSelection(
  Set<String> selectedIds,
  Iterable<Transaction> transactions,
) {
  // Intentionally a no-op with the included/excluded model.
}

/// Rows a month header's select-all acts on.
///
/// Only the ones not already counted: reconciled and part-reconciled rows stay
/// in unless opted out one at a time, so a header toggle must not sweep them.
bool _isBalanceCheckOptInToggleable(Transaction transaction) {
  return !transaction.isReconciled && !transaction.isPartiallyReconciled;
}

bool isBalanceCheckSelected(
  Transaction transaction, {
  required Set<String> includedIds,
  required Set<String> excludedIds,
}) {
  if (transaction.isReconciled || transaction.isPartiallyReconciled) {
    return !excludedIds.contains(transaction.id);
  }
  return includedIds.contains(transaction.id);
}

SelectionState balanceCheckGroupSelectionState({
  required Iterable<Transaction> transactions,
  required Set<String> includedIds,
  required Set<String> excludedIds,
}) {
  // Month header only reflects opt-in of unreconciled rows — reconciled
  // stay included unless excluded one-by-one via the row check.
  final toggleable = transactions
      .where(_isBalanceCheckOptInToggleable)
      .toList();
  if (toggleable.isEmpty) return SelectionState.none;
  final selectedCount = toggleable
      .where((transaction) => includedIds.contains(transaction.id))
      .length;
  if (selectedCount == 0) return SelectionState.none;
  if (selectedCount == toggleable.length) return SelectionState.all;
  return SelectionState.partial;
}

bool shouldSelectAllBalanceCheckTransactions({
  required Iterable<Transaction> transactions,
  required Set<String> includedIds,
  required Set<String> excludedIds,
}) {
  return balanceCheckGroupSelectionState(
        transactions: transactions,
        includedIds: includedIds,
        excludedIds: excludedIds,
      ) !=
      SelectionState.all;
}

void toggleBalanceCheckMonthGroup({
  required List<Transaction> transactions,
  required Set<String> includedIds,
  required Set<String> excludedIds,
}) {
  final selectAll = shouldSelectAllBalanceCheckTransactions(
    transactions: transactions,
    includedIds: includedIds,
    excludedIds: excludedIds,
  );
  for (final transaction in transactions) {
    if (!_isBalanceCheckOptInToggleable(transaction)) continue;
    if (selectAll) {
      includedIds.add(transaction.id);
    } else {
      includedIds.remove(transaction.id);
    }
  }
}

void toggleBalanceCheckTransaction(
  Transaction transaction, {
  required Set<String> includedIds,
  required Set<String> excludedIds,
}) {
  // Part reconciled counts as selected, like fully reconciled, so toggling it
  // means opting out. Returning early here was what made such a group inert.
  if (transaction.isReconciled || transaction.isPartiallyReconciled) {
    if (excludedIds.contains(transaction.id)) {
      excludedIds.remove(transaction.id);
    } else {
      excludedIds.add(transaction.id);
    }
    return;
  }
  if (includedIds.contains(transaction.id)) {
    includedIds.remove(transaction.id);
  } else {
    includedIds.add(transaction.id);
  }
}

/// Ids that count toward "balance from selected".
///
/// Reconciled journals are included unless excluded; unreconciled only when
/// included. Newly loaded reconciled pages stay in the total automatically.
Set<String> effectiveBalanceCheckSelectedIds({
  required Iterable<Transaction> transactions,
  required Set<String> includedIds,
  required Set<String> excludedIds,
}) {
  return {
    for (final transaction in transactions)
      if (isBalanceCheckSelected(
        transaction,
        includedIds: includedIds,
        excludedIds: excludedIds,
      ))
        transaction.id,
  };
}

/// Journals that would change reconciled state if "Reconcile selected" runs.
class BalanceCheckReconcileChanges {
  const BalanceCheckReconcileChanges({
    required this.toReconcile,
    required this.toUnreconcile,
  });

  final List<Transaction> toReconcile;
  final List<Transaction> toUnreconcile;

  bool get hasWork => toReconcile.isNotEmpty || toUnreconcile.isNotEmpty;
}

/// Diff between the current selection and Firefly reconciled flags.
BalanceCheckReconcileChanges balanceCheckReconcileChanges({
  required Iterable<Transaction> transactions,
  required Set<String> selectedIds,
}) {
  final toReconcile = <Transaction>[];
  final toUnreconcile = <Transaction>[];
  for (final transaction in transactions) {
    final selected = selectedIds.contains(transaction.id);
    // A part-reconciled group belongs in whichever list finishes the job:
    // selected means reconcile the legs that are not, unselected means undo the
    // ones that are. It used to fall into neither and could not be completed.
    if (selected && !transaction.isReconciled) {
      toReconcile.add(transaction);
    } else if (!selected &&
        (transaction.isReconciled || transaction.isPartiallyReconciled)) {
      toUnreconcile.add(transaction);
    }
  }
  return BalanceCheckReconcileChanges(
    toReconcile: toReconcile,
    toUnreconcile: toUnreconcile,
  );
}
