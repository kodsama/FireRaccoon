import '../models/account.dart';
import '../models/transaction.dart';
import 'reconciliation.dart';
import 'transaction_filters.dart';

/// Ledger balance as of [reference].
///
/// Firefly's `current_balance` is already computed as of "today" and
/// EXCLUDES future-dated transactions (verified against Firefly III v6:
/// `GET /api/v1/accounts/{id}?date=` returns the balance through that date).
/// The reported balance therefore needs no adjustment for future activity.
double accountBalanceExcludingFuture({
  required double reportedBalance,
  required String accountName,
  required Iterable<Transaction> transactions,
  DateTime? reference,
}) {
  return reportedBalance;
}

/// Ledger balance for the selected set of transactions.
///
/// [reportedBalance] reflects every posted (non-future) transaction, so the
/// signed effect of posted-but-unselected rows is removed. Future-dated rows
/// are absent from the reported balance; when they are selected (for example
/// reconciled card repayments planned after today) their signed effect is
/// added so the result matches the reconciled amounts being checked.
double balanceFromSelectedTransactions({
  required double reportedBalance,
  required String accountName,
  required Iterable<Transaction> transactions,
  required Set<String> selectedIds,
  DateTime? reference,
}) {
  var unselectedEffect = 0.0;
  var selectedFutureEffect = 0.0;
  for (final transaction in transactions) {
    final selected = selectedIds.contains(transaction.id);
    if (isFutureTransaction(transaction.date, reference: reference)) {
      if (selected) {
        selectedFutureEffect += signedAmountForAccount(
          transaction,
          accountName,
        );
      }
      continue;
    }
    if (selected) continue;
    unselectedEffect += signedAmountForAccount(transaction, accountName);
  }
  return reportedBalance - unselectedEffect + selectedFutureEffect;
}

/// Resolves [account]'s balance as of [reference].
///
/// Firefly reports balances as of today already; see
/// [accountBalanceExcludingFuture].
double resolvedAccountBalance(
  Account account,
  Iterable<Transaction> transactions, {
  DateTime? reference,
}) {
  return account.currentBalance;
}

/// Batched [resolvedAccountBalance] for many accounts.
Map<String, double> resolvedAccountBalances(
  List<Account> accounts,
  Iterable<Transaction> transactions, {
  DateTime? reference,
}) {
  return {for (final account in accounts) account.id: account.currentBalance};
}
