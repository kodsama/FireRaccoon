import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

void main() {
  group('easterSunday', () {
    test('lands where the calendar says it does', () {
      // A moving feast four of Sweden's bank holidays hang off, so a year that
      // computes wrong moves Good Friday, Easter Monday and Ascension with it.
      expect(easterSunday(2024), DateTime(2024, 3, 31));
      expect(easterSunday(2025), DateTime(2025, 4, 20));
      expect(easterSunday(2026), DateTime(2026, 4, 5));
      expect(easterSunday(2027), DateTime(2027, 3, 28));
      expect(easterSunday(2038), DateTime(2038, 4, 25));
    });
  });

  group('BankingCalendar.sweden', () {
    final sweden = BankingCalendar.sweden;

    test('shuts on the fixed days', () {
      expect(sweden.isBankingDay(DateTime(2026, 1, 1)), isFalse);
      expect(sweden.isBankingDay(DateTime(2026, 1, 6)), isFalse);
      expect(sweden.isBankingDay(DateTime(2026, 5, 1)), isFalse);
      expect(sweden.isBankingDay(DateTime(2027, 6, 6)), isFalse);
      expect(sweden.isBankingDay(DateTime(2026, 12, 25)), isFalse);
      expect(sweden.isBankingDay(DateTime(2026, 12, 28)), isTrue);
    });

    test('shuts on the days that move with Easter', () {
      expect(sweden.isBankingDay(DateTime(2026, 4, 3)), isFalse); // Långfredag
      expect(sweden.isBankingDay(DateTime(2026, 4, 6)), isFalse); // Annandag
      expect(sweden.isBankingDay(DateTime(2026, 5, 14)), isFalse); // Kristi
      expect(sweden.isBankingDay(DateTime(2026, 4, 7)), isTrue);
    });

    test('shuts on the three eves, which are not public holidays', () {
      // A rule that says "banking day" and means "not Saturday or Sunday" is
      // wrong here, and wrong in the months where a salary actually moves.
      expect(sweden.isBankingDay(DateTime(2026, 6, 19)), isFalse); // Midsommar
      expect(sweden.isBankingDay(DateTime(2026, 12, 24)), isFalse); // Jul
      expect(sweden.isBankingDay(DateTime(2026, 12, 31)), isFalse); // Nyår
    });

    test('midsummer eve is the Friday between the 19th and the 25th', () {
      expect(sweden.isBankingDay(DateTime(2027, 6, 25)), isFalse);
      expect(sweden.isBankingDay(DateTime(2027, 6, 18)), isTrue);
    });

    test('walks back to the day before a run of closures', () {
      // Boxing Day 2026 is a Saturday, so the 25th, 26th and 27th are all
      // shut and the last banking day before the 28th is Christmas Eve's own
      // predecessor.
      expect(sweden.onOrBefore(DateTime(2026, 12, 26)), DateTime(2026, 12, 23));
      expect(sweden.onOrAfter(DateTime(2026, 12, 24)), DateTime(2026, 12, 28));
    });

    test('a banking day is its own answer both ways', () {
      expect(sweden.onOrBefore(DateTime(2026, 9, 17)), DateTime(2026, 9, 17));
      expect(sweden.onOrAfter(DateTime(2026, 9, 17)), DateTime(2026, 9, 17));
    });

    test('a holiday is a holiday whatever time of day it is asked about', () {
      expect(sweden.isHoliday(DateTime(2026, 12, 24, 16, 30)), isTrue);
    });
  });

  group('BankingCalendar.weekendOnly', () {
    test('knows Saturday and Sunday and nothing else', () {
      const weekend = BankingCalendar.weekendOnly;

      expect(weekend.isBankingDay(DateTime(2026, 12, 25)), isTrue);
      expect(weekend.isBankingDay(DateTime(2026, 12, 26)), isFalse);
      expect(
        weekend.onOrBefore(DateTime(2026, 12, 26)),
        DateTime(2026, 12, 25),
      );
      expect(weekend.onOrAfter(DateTime(2026, 12, 26)), DateTime(2026, 12, 28));
    });
  });

  group('BankingCalendar.byName', () {
    test('names the calendars a rule may ask for', () {
      expect(BankingCalendar.byName('SE'), same(BankingCalendar.sweden));
      expect(
        BankingCalendar.byName('weekend'),
        same(BankingCalendar.weekendOnly),
      );
      expect(BankingCalendar.byName('NO'), isNull);
      expect(BankingCalendar.byName(null), isNull);
      expect(BankingCalendar.names, ['weekend', 'SE']);
    });
  });
}
