import '../models/transaction.dart';

/// Sum of every line in a journal (single amount when not split).
double transactionTotalAmount(Transaction transaction) {
  return transaction.resolvedSplits().fold(
    0.0,
    (sum, split) => sum + split.amount,
  );
}

/// Signed effect of one split line on [accountName].
double signedAmountForSplit(Transaction split, String accountName) {
  final magnitude = split.amount.abs();
  final isPositive = split.amount >= 0;
  final isDestination = split.destinationName == accountName;
  final isSource = split.sourceName == accountName;

  if (isDestination && isSource) return 0.0;
  if (isDestination) return isPositive ? magnitude : -magnitude;
  if (isSource) return isPositive ? -magnitude : magnitude;

  return switch (split.type) {
    'deposit' => isPositive ? magnitude : -magnitude,
    'withdrawal' => isPositive ? -magnitude : magnitude,
    _ => 0.0,
  };
}

/// Signed effect of a journal on [accountName], summing every split.
double signedAmountForAccount(Transaction transaction, String accountName) {
  return transaction.resolvedSplits().fold(
    0.0,
    (sum, split) => sum + signedAmountForSplit(split, accountName),
  );
}

/// Account names a transaction touches (top level plus splits).
Set<String> transactionAccountNames(Transaction transaction) {
  return {
    transaction.sourceName,
    transaction.destinationName,
    for (final split in transaction.resolvedSplits()) ...[
      split.sourceName,
      split.destinationName,
    ],
  }..removeWhere((name) => name.isEmpty);
}

bool transactionAffectsAccount(Transaction transaction, String accountName) {
  return transaction.resolvedSplits().any(
    (split) => signedAmountForSplit(split, accountName) != 0,
  );
}

/// Applies [accountName] balance delta for every split in [transaction].
void applySplitBalanceDelta({
  required Transaction transaction,
  required String accountName,
  required void Function(double delta) apply,
}) {
  for (final split in transaction.resolvedSplits()) {
    final signed = signedAmountForSplit(split, accountName);
    if (signed != 0) {
      apply(signed);
    }
  }
}

/// Reverses [accountName] balance delta for every split (history walk backward).
void reverseSplitBalanceDelta({
  required Transaction transaction,
  required String accountName,
  required void Function(double delta) apply,
}) {
  for (final split in transaction.resolvedSplits()) {
    final signed = signedAmountForSplit(split, accountName);
    if (signed != 0) {
      apply(-signed);
    }
  }
}
