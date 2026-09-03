/// Reads a date out of a Firefly III payload.
///
/// Firefly stamps its dates with the server's offset, so a subscription due on
/// the 27th arrives as `2026-10-27T00:00:00+01:00`. What it means is the 27th,
/// not an instant: `DateTime.parse` converts that to UTC and lands on the 26th
/// for any server east of Greenwich. The day then travels, because the calendar
/// fields are what the interface shows, what a monthly repetition takes its day
/// from, and what goes back on the next save.
///
/// Dropping the offset keeps the day the server wrote. Strings without one are
/// already wall-clock and pass through.
DateTime? parseFireflyDate(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text.replaceFirst(_offsetSuffix, ''));
}

final _offsetSuffix = RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$');
