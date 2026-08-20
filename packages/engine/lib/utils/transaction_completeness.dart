import '../models/transaction.dart';

/// A piece of bookkeeping a transaction can be missing.
///
/// Each is asked for one at a time, because "incomplete" is not a single
/// standard: a household that never uses piggy banks is not missing one on
/// every row.
enum TransactionField {
  description,
  category,
  budget,
  tags,
  payee,
  notes,
  piggyBank,
}

/// Whether [field] is something [type] can carry at all.
///
/// A budget only applies to spending, and a payee only exists where one side of
/// the transaction is outside the ledger. Reporting a deposit as missing its
/// budget would flag every income row forever with nothing to do about it,
/// which is how a maintenance list becomes noise nobody reads.
bool fieldAppliesTo(TransactionField field, String type) {
  return switch (field) {
    TransactionField.budget => type == 'withdrawal',
    TransactionField.payee => type == 'withdrawal' || type == 'deposit',
    _ => true,
  };
}

bool _blank(String? value) => value == null || value.trim().isEmpty;

/// Whether this leg lacks [field], ignoring whether it applies.
bool _legLacks(Transaction leg, TransactionField field) {
  return switch (field) {
    TransactionField.description => _blank(leg.description),
    TransactionField.category =>
      _blank(leg.categoryName) && _blank(leg.categoryId),
    TransactionField.budget => _blank(leg.budgetName) && _blank(leg.budgetId),
    TransactionField.tags => leg.tags.isEmpty,
    TransactionField.notes => _blank(leg.notes),
    TransactionField.piggyBank => _blank(leg.piggyBankId),
    // The side of the transaction that is not one of your own accounts.
    TransactionField.payee => switch (leg.type) {
      'withdrawal' => _blank(leg.destinationName),
      'deposit' => _blank(leg.sourceName),
      _ => false,
    },
  };
}

/// Which of [fields] [transaction] is missing on at least one leg.
///
/// A group is judged leg by leg: half a card bill categorised and half not is
/// exactly the case worth finding, and reading only the first leg would hide it.
/// Fields that do not apply to a leg's type are not counted against it.
Set<TransactionField> missingTransactionFields(
  Transaction transaction, {
  Set<TransactionField> fields = const {
    TransactionField.description,
    TransactionField.category,
  },
}) {
  final missing = <TransactionField>{};
  for (final leg in transaction.resolvedSplits()) {
    for (final field in fields) {
      if (!fieldAppliesTo(field, leg.type)) continue;
      if (_legLacks(leg, field)) missing.add(field);
    }
  }
  return missing;
}

/// True when [transaction] is missing at least one of [fields].
///
/// An empty [fields] matches nothing rather than everything: asking for no gaps
/// is asking for no rows.
bool hasMissingFields(
  Transaction transaction, {
  required Set<TransactionField> fields,
}) {
  if (fields.isEmpty) return false;
  return missingTransactionFields(transaction, fields: fields).isNotEmpty;
}

/// [transactions] that are missing at least one of [fields], newest first.
List<Transaction> transactionsMissingFields(
  Iterable<Transaction> transactions, {
  required Set<TransactionField> fields,
}) {
  final matched =
      transactions.where((t) => hasMissingFields(t, fields: fields)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  return matched;
}

/// How many transactions are missing each of [fields].
///
/// One transaction can count towards several, which is the point: it says where
/// the work is, not how many rows there are.
Map<TransactionField, int> countMissingByField(
  Iterable<Transaction> transactions, {
  required Set<TransactionField> fields,
}) {
  final counts = <TransactionField, int>{for (final f in fields) f: 0};
  for (final transaction in transactions) {
    for (final field in missingTransactionFields(transaction, fields: fields)) {
      counts[field] = (counts[field] ?? 0) + 1;
    }
  }
  return counts;
}
