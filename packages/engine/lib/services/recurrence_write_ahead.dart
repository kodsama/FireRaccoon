import '../models/recurrence.dart';
import '../models/transaction.dart';
import 'recurrence_scheduler.dart';

/// Marker stored in the notes of auto-materialized transactions so re-runs
/// and other clients can recognize them.
const kWriteAheadMarker = 'fireracoon:auto-written';

/// Key used to decide whether an occurrence already exists in the window.
String writeAheadDedupKey({
  required String description,
  required DateTime date,
  required double amount,
}) =>
    '${description.trim().toLowerCase()}|${date.year}-${date.month}-${date.day}'
    '|${amount.toStringAsFixed(2)}';

/// Plans the future transactions needed to materialize [recurrences] up to
/// [days] ahead, mirroring Skrooge's advance-write behaviour.
///
/// [existing] must hold the transactions already present in the window (from
/// any source — earlier auto-writes, Skrooge-imported schedules, manual
/// entries); occurrences matching one by description, calendar day, and
/// amount are skipped.
List<Transaction> planWriteAheadTransactions({
  required List<Recurrence> recurrences,
  required List<Transaction> existing,
  required int days,
  DateTime? reference,
}) {
  if (days <= 0) return const [];
  final now = reference ?? DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(Duration(days: days + 1));

  final taken = <String>{
    for (final transaction in existing)
      writeAheadDedupKey(
        description: transaction.description,
        date: transaction.date,
        amount: transaction.totalAmount,
      ),
  };

  final planned = <Transaction>[];
  for (final recurrence in recurrences) {
    if (!recurrence.active) continue;
    final line = recurrence.primaryTransaction;
    if (line == null || line.amount <= 0) continue;

    final occurrences = expandRecurrenceOccurrences(
      recurrence: recurrence,
      rangeStart: start,
      rangeEnd: end,
    );
    for (final date in occurrences) {
      final key = writeAheadDedupKey(
        description: line.description,
        date: date,
        amount: line.amount,
      );
      if (taken.contains(key)) continue;
      taken.add(key);
      planned.add(
        Transaction(
          id: '',
          type: recurrence.type.name,
          date: date,
          amount: line.amount,
          description: line.description,
          sourceName: line.sourceName ?? '',
          destinationName: line.destinationName ?? '',
          categoryName: line.categoryName ?? '',
          currencySymbol: line.currencySymbol ?? '',
          currencyCode: line.currencyCode,
          sourceId: line.sourceId,
          destinationId: line.destinationId,
          categoryId: line.categoryId,
          budgetId: line.budgetId,
          budgetName: line.budgetName,
          billId: line.billId,
          billName: line.billName,
          tags: line.tags,
          notes: kWriteAheadMarker,
        ),
      );
    }
  }
  return planned;
}
