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
