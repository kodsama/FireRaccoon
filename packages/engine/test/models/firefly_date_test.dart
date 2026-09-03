import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

void main() {
  group('parseFireflyDate', () {
    test('keeps the calendar day a server east of Greenwich wrote', () {
      final date = parseFireflyDate('2026-10-27T00:00:00+01:00')!;

      expect(date.isUtc, isFalse);
      expect((date.year, date.month, date.day), (2026, 10, 27));
    });

    test('keeps the calendar day a server west of Greenwich wrote', () {
      final date = parseFireflyDate('2026-10-27T23:30:00-05:00')!;

      expect((date.year, date.month, date.day), (2026, 10, 27));
      expect((date.hour, date.minute), (23, 30));
    });

    test('reads a plain date as that day', () {
      expect(parseFireflyDate('2026-08-08'), DateTime(2026, 8, 8));
    });

    test('reads a Z stamp as the clock it shows', () {
      final date = parseFireflyDate('2026-07-07T22:00:00.000Z')!;

      expect(date.isUtc, isFalse);
      expect((date.day, date.hour), (7, 22));
    });

    test('has nothing to say about a missing or unreadable value', () {
      expect(parseFireflyDate(null), isNull);
      expect(parseFireflyDate(''), isNull);
      expect(parseFireflyDate('   '), isNull);
      expect(parseFireflyDate('invalid'), isNull);
    });
  });
}
