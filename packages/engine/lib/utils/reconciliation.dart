import '../models/transaction.dart';
import 'transaction_filters.dart';
import 'transaction_grouping.dart';
import 'transaction_splits.dart';

export 'transaction_grouping.dart';
export 'transaction_splits.dart';

bool isDateOnOrAfter(DateTime date, DateTime boundary) {
  final day = DateTime(date.year, date.month, date.day);
  final bound = DateTime(boundary.year, boundary.month, boundary.day);
  return !day.isBefore(bound);
}

bool isDateOnOrBefore(DateTime date, DateTime boundary) {
  final day = DateTime(date.year, date.month, date.day);
  final bound = DateTime(boundary.year, boundary.month, boundary.day);
  return !day.isAfter(bound);
}

bool isDateInInclusiveRange(DateTime date, DateTime start, DateTime end) {
  return isDateOnOrAfter(date, start) && isDateOnOrBefore(date, end);
}

bool isReconciliationPeriodTransaction(
  DateTime date,
  DateTime startDate,
  DateTime endDate,
) {
  return isDateInInclusiveRange(date, startDate, endDate);
}

bool isFutureReconciliationTransaction(DateTime date, DateTime endDate) {
  return !isDateOnOrBefore(date, endDate);
}

bool isUnoccurredReconciliationTransaction(
  DateTime date, {
  DateTime? reference,
}) {
  return isFutureTransaction(date, reference: reference);
}

bool isReconciliationToggleableTransaction(
  DateTime date,
  DateTime startDate,
  DateTime endDate, {
  DateTime? reference,
}) {
  return isReconciliationPeriodTransaction(date, startDate, endDate) &&
      !isUnoccurredReconciliationTransaction(date, reference: reference);
}

/// Journal IDs selected by default: every transaction in the period, excluding
/// future-dated entries after [endDate].
Iterable<String> defaultReconciliationSelection({
  required Iterable<Transaction> transactions,
  required DateTime startDate,
  required DateTime endDate,
  DateTime? reference,
}) {
  return transactions
      .where(
        (transaction) => isReconciliationToggleableTransaction(
          transaction.date,
          startDate,
          endDate,
          reference: reference,
        ),
      )
      .map((transaction) => transaction.id);
}

typedef ReconciliationSelectionState = SelectionState;
typedef ReconciliationPeriodGroup = TransactionMonthGroup;

Set<String> reconciledJournalIds(Iterable<Transaction> transactions) {
  return transactions
      .where((transaction) => transaction.isReconciled)
      .map((transaction) => transaction.id)
      .toSet();
}

SelectionState reconciledSelectionState(Transaction transaction) {
  if (transaction.isPartiallyReconciled) return SelectionState.partial;
  if (transaction.isReconciled) return SelectionState.all;
  return SelectionState.none;
}

List<Transaction> reconciledTransactionsInPeriod({
  required Iterable<Transaction> transactions,
  required DateTime startDate,
  required DateTime endDate,
  DateTime? reference,
}) {
  return transactions
      .where(
        (transaction) =>
            transaction.isReconciled &&
            isReconciliationToggleableTransaction(
              transaction.date,
              startDate,
              endDate,
              reference: reference,
            ),
      )
      .toList();
}

List<Transaction> reconciliationToggleableTransactions({
  required Iterable<Transaction> transactions,
  required DateTime startDate,
  required DateTime endDate,
  DateTime? reference,
}) {
  return transactions
      .where(
        (transaction) => isReconciliationToggleableTransaction(
          transaction.date,
          startDate,
          endDate,
          reference: reference,
        ),
      )
      .toList();
}

ReconciliationSelectionState reconciliationSelectionState({
  required Iterable<Transaction> transactions,
  required Set<String> selectedIds,
  required DateTime startDate,
  required DateTime endDate,
  DateTime? reference,
}) {
  return selectionStateForIds(
    transactions: transactions,
    selectedIds: selectedIds,
    isToggleable: (transaction) => isReconciliationToggleableTransaction(
      transaction.date,
      startDate,
      endDate,
      reference: reference,
    ),
  );
}

bool shouldSelectAllReconciliationTransactions({
  required Iterable<Transaction> transactions,
  required Set<String> selectedIds,
  required DateTime startDate,
  required DateTime endDate,
  DateTime? reference,
}) {
  return shouldSelectAllForIds(
    transactions: transactions,
    selectedIds: selectedIds,
    isToggleable: (transaction) => isReconciliationToggleableTransaction(
      transaction.date,
      startDate,
      endDate,
      reference: reference,
    ),
  );
}

List<ReconciliationPeriodGroup> groupReconciliationTransactionsByMonth(
  List<Transaction> transactions,
) => groupTransactionsByMonth(transactions);

/// Transactions visible in the reconcile view: in-range plus [bufferDays] padding.
List<Transaction> transactionsForReconciliationView({
  required List<Transaction> transactions,
  required String accountName,
  required DateTime startDate,
  required DateTime endDate,
  int bufferDays = 7,
}) {
  final bufferedStart = startDate.subtract(Duration(days: bufferDays));
  final bufferedEnd = endDate.add(Duration(days: bufferDays));
  final visible = transactions
      .where(
        (transaction) => transactionAffectsAccount(transaction, accountName),
      )
      .where(
        (transaction) => isDateInInclusiveRange(
          transaction.date,
          bufferedStart,
          bufferedEnd,
        ),
      )
      .toList();
  visible.sort((a, b) => b.date.compareTo(a.date));
  return visible;
}

/// Difference between the statement closing balance and the ledger total for
/// checked transactions in the period. Zero means the statement matches.
double computeReconciliationGap({
  required double startBalance,
  required double endBalance,
  required Iterable<Transaction> selectedTransactions,
  required String accountName,
  required DateTime startDate,
  required DateTime endDate,
  DateTime? reference,
}) {
  var net = 0.0;
  for (final transaction in selectedTransactions) {
    if (!isReconciliationToggleableTransaction(
      transaction.date,
      startDate,
      endDate,
      reference: reference,
    )) {
      continue;
    }
    net += signedAmountForAccount(transaction, accountName);
  }
  return endBalance - (startBalance + net);
}

/// Builds a reconciliation correction transaction for [gap] on [endDate].
///
/// Only the reconciled account is named. Firefly puts the other side against
/// its own `<account> reconciliation (<currency>)` account, finds it or makes
/// it on the spot, and a side left carrying neither a name nor an id is how
/// its interface asks for exactly that. Given a name it searches for an
/// account that already exists and refuses the write when it finds none, and
/// the name guessed here left the currency out, so the correction was refused
/// on every account that had ever been reconciled and refused again on every
/// account that had not.
Transaction buildReconciliationCorrection({
  required String accountId,
  required String accountName,
  required String currencyCode,
  required String currencySymbol,
  required double gap,
  required DateTime endDate,
}) {
  // A gap above zero is a statement holding more than the ledger does, so the
  // money arrives: the account is the destination, and the side Firefly fills
  // in is the source.
  final isShort = gap > 0;

  return Transaction(
    id: '',
    type: 'reconciliation',
    date: endDate,
    amount: gap.abs(),
    description: 'Reconciliation of $accountName',
    sourceName: isShort ? '' : accountName,
    destinationName: isShort ? accountName : '',
    categoryName: '',
    currencySymbol: currencySymbol,
    currencyCode: currencyCode,
    sourceId: isShort ? null : accountId,
    destinationId: isShort ? accountId : null,
  );
}

class ReconciliationStoreResult {
  const ReconciliationStoreResult({
    required this.reconciled,
    this.correction,
    this.payback,
    this.correctionError,
  });

  final List<Transaction> reconciled;
  final Transaction? correction;

  /// Multi-split credit-card payback transfer, when created.
  final Transaction? payback;

  /// Why the correction was not written, null when there was nothing to
  /// correct or the correction went in.
  ///
  /// The journals are marked before the correction, and that half stands
  /// whatever happens to this one. Reporting the whole call as failed would
  /// hide a reconciliation that did happen and invite a caller to run it
  /// again.
  final String? correctionError;
}
