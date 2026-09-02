/// Earliest date Firefly III accepts as a window start.
///
/// Firefly validates both ends of a window against 32-bit time and refuses
/// anything outside it: "The start must be a date after 1970-01-02" and "The end
/// must be a date before 2038-01-17". These sit just inside those edges, so a
/// read meaning "everything" is answered rather than refused with a 422.
final DateTime kFireflyLedgerStart = DateTime(1970, 1, 3);

/// Latest date Firefly III accepts as a window end. See [kFireflyLedgerStart].
final DateTime kFireflyLedgerEnd = DateTime(2038, 1, 16);

/// Inclusive start, exclusive end date range for filtering transactions.
class DateRangeBounds {
  final DateTime? start;
  final DateTime? end;

  const DateRangeBounds({this.start, this.end});

  bool contains(DateTime date) {
    if (start != null && date.isBefore(start!)) return false;
    if (end != null && !date.isBefore(end!)) return false;
    return true;
  }
}

List<T> filterByDateRange<T>(
  Iterable<T> items,
  DateRangeBounds range,
  DateTime Function(T item) readDate,
) {
  return items.where((item) => range.contains(readDate(item))).toList();
}
