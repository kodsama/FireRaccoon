import 'recurrence_scheduler.dart';

/// Easter Sunday in the Gregorian calendar, by the anonymous computus.
///
/// Four of Sweden's bank holidays move with it, so the table cannot be a list
/// of fixed dates.
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final offset = h + l - 7 * m + 114;
  return DateTime(year, offset ~/ 31, (offset % 31) + 1);
}

/// Midsummer Eve: the Friday falling between 19 and 25 June.
DateTime _midsummerEve(int year) {
  var day = DateTime(year, 6, 19);
  while (day.weekday != DateTime.friday) {
    day = day.add(const Duration(days: 1));
  }
  return day;
}

/// The days Swedish banks are shut beyond Saturday and Sunday.
///
/// The three eves are in because Swedish banks settle nothing on them, which
/// is what "banking day" has to mean for a salary or a direct debit.
///
/// <https://www.financesweden.se/en/bank-customers/general-questions/bank-holidays-2026/>
List<DateTime> swedishBankHolidays(int year) {
  final easter = easterSunday(year);
  return [
    DateTime(year, 1, 1), // Nyårsdagen
    DateTime(year, 1, 6), // Trettondedag jul
    easter.subtract(const Duration(days: 2)), // Långfredagen
    easter.add(const Duration(days: 1)), // Annandag påsk
    DateTime(year, 5, 1), // Första maj
    easter.add(const Duration(days: 39)), // Kristi himmelsfärdsdag
    DateTime(year, 6, 6), // Sveriges nationaldag
    _midsummerEve(year), // Midsommarafton
    DateTime(year, 12, 24), // Julafton
    DateTime(year, 12, 25), // Juldagen
    DateTime(year, 12, 26), // Annandag jul
    DateTime(year, 12, 31), // Nyårsafton
  ];
}

/// Which days a bank settles on.
///
/// Weekends are universal; the rest is a per-country table, which is enough
/// because these dates are known years ahead.
class BankingCalendar {
  const BankingCalendar(this.name, this._holidaysOf);

  /// What a stored rule names this calendar by.
  final String name;

  final List<DateTime> Function(int year) _holidaysOf;

  /// Saturday and Sunday only. What [RecurrenceWeekendMode] already assumed,
  /// and what it is wrong about several times a year in any one country.
  static const weekendOnly = BankingCalendar('weekend', _noHolidays);

  static const sweden = BankingCalendar('SE', swedishBankHolidays);

  static const all = [weekendOnly, sweden];

  static List<String> get names => [for (final c in all) c.name];

  /// The calendar [name] names, or null when nothing does.
  static BankingCalendar? byName(String? name) {
    for (final calendar in all) {
      if (calendar.name == name) return calendar;
    }
    return null;
  }

  bool isHoliday(DateTime date) {
    final day = prognosisStartOfDay(date);
    return _holidaysFor(day.year).contains(day);
  }

  bool isBankingDay(DateTime date) =>
      !prognosisIsWeekend(date) && !isHoliday(date);

  /// The latest banking day on or before [date].
  DateTime onOrBefore(DateTime date) {
    var day = prognosisStartOfDay(date);
    while (!isBankingDay(day)) {
      day = day.subtract(const Duration(days: 1));
    }
    return day;
  }

  /// The earliest banking day on or after [date].
  DateTime onOrAfter(DateTime date) {
    var day = prognosisStartOfDay(date);
    while (!isBankingDay(day)) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  /// Computing Easter and walking to Midsummer for every occurrence of every
  /// rule is wasted work in a projection that spans years, so each year is
  /// worked out once.
  Set<DateTime> _holidaysFor(int year) =>
      _cache.putIfAbsent('$name:$year', () => _holidaysOf(year).toSet());

  static final Map<String, Set<DateTime>> _cache = {};
}

List<DateTime> _noHolidays(int year) => const [];
