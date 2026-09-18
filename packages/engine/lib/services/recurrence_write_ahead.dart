import '../models/recurrence.dart';
import '../models/transaction.dart';
import 'recurrence_scheduler.dart';

/// Marker stored in the notes of auto-materialized transactions so re-runs
/// and other clients can recognize them.
const kWriteAheadMarker = 'fireraccoon:auto-written';

/// The marker a row written for [recurrenceId] carries.
///
/// Firefly records nothing about which rule produced a row written ahead, so
/// the marker is the only link there is. It used to be the same constant on
/// every row, which named the population but not which rule each row belonged
/// to; the id makes the set exact.
String writeAheadMarkerFor(String recurrenceId) =>
    '$kWriteAheadMarker:$recurrenceId';

/// The marker in [notes], whichever spelling and shape wrote it.
///
/// Rows written before the raccoon rename spell it `fireracoon:` with one `c`,
/// and rows written before the id was carried end at `auto-written`. Both are
/// still on the books, so both are read.
final RegExp _writeAheadNote = RegExp(
  r'firerac{1,2}oon:auto-written(?::(\S+))?',
);

/// Whether [notes] marks a row FireRaccoon wrote ahead.
bool isWriteAheadNote(String? notes) =>
    notes != null && _writeAheadNote.hasMatch(notes);

/// The recurrence id [notes] names, or null when the marker is absent or was
/// written before ids were carried.
String? writeAheadRecurrenceId(String? notes) {
  if (notes == null) return null;
  final match = _writeAheadNote.firstMatch(notes);
  return match?.group(1);
}

/// The rows among [transactions] that [recurrence] wrote ahead.
///
/// A row naming a recurrence is taken only for that one. A row from before the
/// id was carried names no rule, so it is matched on what the rule still
/// determines: the two accounts it moves between and a date the schedule
/// actually falls on.
List<Transaction> writeAheadRowsFor({
  required Recurrence recurrence,
  required List<Transaction> transactions,
}) {
  final line = recurrence.primaryTransaction;
  final matched = <Transaction>[];
  for (final transaction in transactions) {
    if (!isWriteAheadNote(transaction.notes)) continue;
    final named = writeAheadRecurrenceId(transaction.notes);
    if (named != null) {
      if (named == recurrence.id) matched.add(transaction);
      continue;
    }
    if (line == null) continue;
    if (!_sameAccounts(transaction, line)) continue;
    final day = prognosisStartOfDay(transaction.date);
    final falls = expandRecurrenceOccurrences(
      recurrence: recurrence,
      rangeStart: day,
      rangeEnd: day.add(const Duration(days: 1)),
    );
    if (falls.isNotEmpty) matched.add(transaction);
  }
  return matched;
}

/// Where each of [rows] lands once [after]'s schedule replaces [before]'s,
/// by row id, over a window of [days] from [reference].
///
/// Empty when the schedule did not move, so a row somebody dated by hand is
/// left where they put it. Null against a row the new schedule has no
/// occurrence left for, which is the honest answer: the rule no longer says
/// when that row should happen, and deciding that for the caller would be
/// deleting their data on a guess.
///
/// Rows and occurrences pair nearest-first rather than in order. An adjustment
/// carries an occurrence out of the month it belongs to, so the first of
/// January can fall on the thirtieth of December, and pairing by position
/// would hand every row the date of its neighbour.
Map<String, DateTime?> writeAheadRowMoves({
  required List<Transaction> rows,
  required Recurrence before,
  required Recurrence after,
  required int days,
  DateTime? reference,
}) {
  if (rows.isEmpty) return const {};
  final now = reference ?? DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  // Past the window the rows themselves were read from, so a row at its far
  // edge still has occurrences either side of it to pair with.
  final end = start.add(Duration(days: days + 31));

  final was = expandRecurrenceOccurrences(
    recurrence: before,
    rangeStart: start,
    rangeEnd: end,
  );
  final willBe = expandRecurrenceOccurrences(
    recurrence: after,
    rangeStart: start,
    rangeEnd: end,
  );
  if (_sameDates(was, willBe)) return const {};

  final free = [...willBe];
  final moves = <String, DateTime?>{};
  final byDate = [...rows]..sort((a, b) => a.date.compareTo(b.date));
  for (final row in byDate) {
    if (free.isEmpty) {
      moves[row.id] = null;
      continue;
    }
    final day = prognosisStartOfDay(row.date);
    var nearest = 0;
    for (var i = 1; i < free.length; i++) {
      if (free[i].difference(day).inDays.abs() <
          free[nearest].difference(day).inDays.abs()) {
        nearest = i;
      }
    }
    moves[row.id] = free.removeAt(nearest);
  }
  return moves;
}

bool _sameDates(List<DateTime> a, List<DateTime> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!a[i].isAtSameMomentAs(b[i])) return false;
  }
  return true;
}

bool _sameAccounts(Transaction row, RecurrenceTransactionLine line) {
  final sourceMatches = line.sourceId != null
      ? row.sourceId == line.sourceId
      : row.sourceName == line.sourceName;
  final destinationMatches = line.destinationId != null
      ? row.destinationId == line.destinationId
      : row.destinationName == line.destinationName;
  return sourceMatches && destinationMatches;
}

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
          notes: writeAheadMarkerFor(recurrence.id),
        ),
      );
    }
  }
  return planned;
}
