import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

void main() {
  group('RecurrenceScheduleRule.parse', () {
    test('reads the anchor, the adjustment and the calendar', () {
      final rule = RecurrenceScheduleRule.parse(
        'anchor=day:31;adjust=previous-banking;calendar=SE',
      );

      expect(rule.anchor, const DayOfMonthAnchor(31));
      expect(rule.adjustment, RecurrenceDateAdjustment.previousBankingDay);
      expect(rule.calendar.name, 'SE');
      expect(
        rule.ruleValue,
        'anchor=day:31;adjust=previous-banking;calendar=SE',
      );
    });

    test('an omitted adjustment and calendar mean no shift at all', () {
      final rule = RecurrenceScheduleRule.parse('anchor=weekday:-1,4');

      expect(rule.anchor, const NthWeekdayAnchor(index: -1, weekday: 4));
      expect(rule.adjustment, RecurrenceDateAdjustment.none);
      expect(rule.calendar.name, 'weekend');
      expect(
        rule.ruleValue,
        'anchor=weekday:-1,4;adjust=none;calendar=weekend',
      );
    });

    test('whitespace between fields is ignored', () {
      expect(
        RecurrenceScheduleRule.parse(' anchor=day:1 ; adjust=next-banking ; '),
        RecurrenceScheduleRule.parse('anchor=day:1;adjust=next-banking'),
      );
    });

    test('refuses what it cannot read rather than defaulting', () {
      // A rule that quietly became something else would schedule the wrong day
      // for months before anybody noticed.
      void refuses(String raw) => expect(
        () => RecurrenceScheduleRule.parse(raw),
        throwsA(isA<FormatException>()),
        reason: raw,
      );

      refuses('');
      refuses('anchor');
      refuses('anchor=day');
      refuses('anchor=day:0');
      refuses('anchor=day:32');
      refuses('anchor=day:last');
      refuses('anchor=weekday:1');
      refuses('anchor=weekday:0,4');
      refuses('anchor=weekday:6,4');
      refuses('anchor=weekday:1,8');
      refuses('anchor=weekday:one,4');
      refuses('anchor=month:1');
      refuses('anchor=day:1;adjust=previous-weekday');
      refuses('anchor=day:1;calendar=NO');
      refuses('=day:1');
    });
  });

  group('the date a rule falls on', () {
    test('a day of the month clamps down in a month too short for it', () {
      const rule = RecurrenceScheduleRule(anchor: DayOfMonthAnchor(31));

      expect(rule.dateIn(2026, 1), DateTime(2026, 1, 31));
      expect(rule.dateIn(2026, 2), DateTime(2026, 2, 28));
      expect(rule.dateIn(2028, 2), DateTime(2028, 2, 29));
      expect(rule.dateIn(2026, 4), DateTime(2026, 4, 30));
    });

    test('the last banking day of the month', () {
      // The union fee in the issue: drawn on the 28th, 30th, 30th, 27th, 31st
      // over consecutive months. One rule, not ten day numbers.
      const rule = RecurrenceScheduleRule(
        anchor: DayOfMonthAnchor(31),
        adjustment: RecurrenceDateAdjustment.previousBankingDay,
        calendar: BankingCalendar.sweden,
      );

      expect(rule.dateIn(2026, 5), DateTime(2026, 5, 29)); // 31st is a Sunday
      expect(rule.dateIn(2026, 12), DateTime(2026, 12, 30)); // 31st is shut
      expect(rule.dateIn(2027, 1), DateTime(2027, 1, 29)); // 31st is a Sunday
      expect(rule.dateIn(2026, 9), DateTime(2026, 9, 30)); // a Wednesday
    });

    test('the last banking day on or before the 25th', () {
      // The ordinary Swedish salary date.
      const rule = RecurrenceScheduleRule(
        anchor: DayOfMonthAnchor(25),
        adjustment: RecurrenceDateAdjustment.previousBankingDay,
        calendar: BankingCalendar.sweden,
      );

      expect(rule.dateIn(2026, 12), DateTime(2026, 12, 23)); // Jul, then a Fri
      expect(rule.dateIn(2026, 10), DateTime(2026, 10, 23)); // 25th is a Sunday
      expect(rule.dateIn(2026, 9), DateTime(2026, 9, 25)); // a Friday
    });

    test('the first banking day on or after the 15th', () {
      const rule = RecurrenceScheduleRule(
        anchor: DayOfMonthAnchor(15),
        adjustment: RecurrenceDateAdjustment.nextBankingDay,
        calendar: BankingCalendar.sweden,
      );

      expect(rule.dateIn(2026, 8), DateTime(2026, 8, 17)); // 15th is a Saturday
      expect(rule.dateIn(2026, 9), DateTime(2026, 9, 15));
    });

    test('an adjustment can carry a date out of its own month', () {
      const firstOfMonth = RecurrenceScheduleRule(
        anchor: DayOfMonthAnchor(1),
        adjustment: RecurrenceDateAdjustment.previousBankingDay,
        calendar: BankingCalendar.sweden,
      );
      // 1 January is shut, and so is everything back to the 30th of December.
      expect(firstOfMonth.dateIn(2027, 1), DateTime(2026, 12, 30));

      const lastOfMonth = RecurrenceScheduleRule(
        anchor: DayOfMonthAnchor(31),
        adjustment: RecurrenceDateAdjustment.nextBankingDay,
        calendar: BankingCalendar.sweden,
      );
      expect(lastOfMonth.dateIn(2026, 12), DateTime(2027, 1, 4));
    });

    test('the last Thursday, which ndom cannot say', () {
      const rule = RecurrenceScheduleRule(
        anchor: NthWeekdayAnchor(index: -1, weekday: DateTime.thursday),
      );

      expect(rule.dateIn(2026, 9), DateTime(2026, 9, 24));
      expect(rule.dateIn(2026, 10), DateTime(2026, 10, 29));
      expect(rule.dateIn(2026, 11), DateTime(2026, 11, 26));
    });

    test('a forward count still goes quiet in a month that is short of it', () {
      const rule = RecurrenceScheduleRule(
        anchor: NthWeekdayAnchor(index: 5, weekday: DateTime.thursday),
      );

      expect(rule.dateIn(2026, 10), DateTime(2026, 10, 29));
      expect(rule.dateIn(2026, 11), isNull);
    });

    test('the second Wednesday, counted forward', () {
      const rule = RecurrenceScheduleRule(
        anchor: NthWeekdayAnchor(index: 2, weekday: DateTime.wednesday),
      );

      expect(rule.dateIn(2026, 9), DateTime(2026, 9, 9));
    });
  });

  group('the rule in a recurrence\'s notes', () {
    test('is read back out of whatever else is written there', () {
      const notes =
          'Renegotiated in March\n'
          'fireraccoon:schedule:anchor=day:31;adjust=previous-banking;'
          'calendar=SE\n'
          'Chased twice';

      final rule = scheduleRuleFromNotes(notes);

      expect(rule!.anchor, const DayOfMonthAnchor(31));
      expect(rule.calendar.name, 'SE');
    });

    test('the spelling from before the raccoon rename is read too', () {
      expect(
        scheduleRuleFromNotes('fireracoon:schedule:anchor=day:1'),
        const RecurrenceScheduleRule(anchor: DayOfMonthAnchor(1)),
      );
    });

    test('a rule nobody can parse reads as no rule at all', () {
      // Firefly's own repetition is the fallback, and it is the safe half.
      expect(
        scheduleRuleFromNotes('fireraccoon:schedule:anchor=day:99'),
        isNull,
      );
      expect(scheduleRuleFromNotes('bank text: ICA'), isNull);
      expect(scheduleRuleFromNotes(null), isNull);
    });

    test('writing a rule leaves the rest of the notes alone', () {
      const rule = RecurrenceScheduleRule(anchor: DayOfMonthAnchor(1));

      expect(
        notesWithScheduleRule('Renegotiated in March', rule),
        'Renegotiated in March\nfireraccoon:schedule:anchor=day:1;'
        'adjust=none;calendar=weekend',
      );
    });

    test('writing a rule replaces the one already there', () {
      final notes = notesWithScheduleRule(
        'kept\nfireraccoon:schedule:anchor=day:1',
        const RecurrenceScheduleRule(anchor: DayOfMonthAnchor(20)),
      );

      expect(scheduleRuleFromNotes(notes)!.anchor, const DayOfMonthAnchor(20));
      expect(notes, startsWith('kept\n'));
      expect('fireraccoon:schedule:'.allMatches(notes!).length, 1);
    });

    test('dropping the rule leaves notes that carried nothing else empty', () {
      expect(
        notesWithScheduleRule('fireraccoon:schedule:anchor=day:1', null),
        isNull,
      );
      expect(
        notesWithScheduleRule('kept\nfireraccoon:schedule:anchor=day:1', null),
        'kept',
      );
      expect(notesWithScheduleRule(null, null), isNull);
    });
  });

  group('anchors compare by what they say', () {
    test('so a rule can be told apart from another', () {
      expect(const DayOfMonthAnchor(1), const DayOfMonthAnchor(1));
      expect(const DayOfMonthAnchor(1), isNot(const DayOfMonthAnchor(2)));
      expect(
        const DayOfMonthAnchor(1).hashCode,
        const DayOfMonthAnchor(1).hashCode,
      );
      expect(
        const NthWeekdayAnchor(index: -1, weekday: 4),
        const NthWeekdayAnchor(index: -1, weekday: 4),
      );
      expect(
        const NthWeekdayAnchor(index: -1, weekday: 4),
        isNot(const NthWeekdayAnchor(index: 1, weekday: 4)),
      );
      expect(
        const NthWeekdayAnchor(index: -1, weekday: 4).hashCode,
        const NthWeekdayAnchor(index: -1, weekday: 4).hashCode,
      );
      expect(
        const RecurrenceScheduleRule(anchor: DayOfMonthAnchor(1)).hashCode,
        const RecurrenceScheduleRule(anchor: DayOfMonthAnchor(1)).hashCode,
      );
      expect(
        const RecurrenceScheduleRule(anchor: DayOfMonthAnchor(1)),
        isNot(
          const RecurrenceScheduleRule(
            anchor: DayOfMonthAnchor(1),
            adjustment: RecurrenceDateAdjustment.nextBankingDay,
          ),
        ),
      );
    });
  });
}
