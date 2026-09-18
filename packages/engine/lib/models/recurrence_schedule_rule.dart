import '../services/banking_calendar.dart';
import '../services/recurrence_scheduler.dart';

/// What happens to an anchor date that is not a banking day.
enum RecurrenceDateAdjustment {
  none('none'),
  previousBankingDay('previous-banking'),
  nextBankingDay('next-banking');

  const RecurrenceDateAdjustment(this.ruleValue);

  /// How the adjustment is spelled in a stored rule.
  final String ruleValue;

  static RecurrenceDateAdjustment? byRuleValue(String value) {
    for (final adjustment in values) {
      if (adjustment.ruleValue == value) return adjustment;
    }
    return null;
  }
}

/// Where in a month a rule falls, before any adjustment.
sealed class RecurrenceAnchor {
  const RecurrenceAnchor();

  /// The anchor date in that month, or null when the month has no such day.
  DateTime? dateIn(int year, int month);

  /// How the anchor is spelled in a stored rule.
  String get ruleValue;

  /// Reads `day:<1-31>` or `weekday:<n>,<1-7>`.
  static RecurrenceAnchor parse(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) {
      throw FormatException('anchor must be day:<1-31> or weekday:<n>,<1-7>');
    }
    switch (parts.first) {
      case 'day':
        final day = int.tryParse(parts[1]);
        if (day == null || day < 1 || day > 31) {
          throw FormatException('anchor day must be 1-31, got "${parts[1]}"');
        }
        return DayOfMonthAnchor(day);
      case 'weekday':
        final fields = parts[1].split(',');
        final index = fields.length == 2 ? int.tryParse(fields.first) : null;
        final weekday = fields.length == 2 ? int.tryParse(fields[1]) : null;
        if (index == null || index == 0 || index < -5 || index > 5) {
          throw FormatException(
            'anchor weekday index must be -5 to 5 and not 0, '
            'got "${parts[1]}"',
          );
        }
        if (weekday == null || weekday < 1 || weekday > 7) {
          throw FormatException(
            'anchor weekday must be 1-7, Monday to Sunday, got "${parts[1]}"',
          );
        }
        return NthWeekdayAnchor(index: index, weekday: weekday);
      default:
        throw FormatException('unknown anchor "${parts.first}"');
    }
  }
}

/// A day of the month, falling back to the last day in a month too short for
/// it, which is what Firefly's own monthly repetition does.
class DayOfMonthAnchor extends RecurrenceAnchor {
  const DayOfMonthAnchor(this.day);

  final int day;

  @override
  DateTime dateIn(int year, int month) =>
      prognosisClampDayOfMonth(year, month, day);

  @override
  String get ruleValue => 'day:$day';

  @override
  bool operator ==(Object other) =>
      other is DayOfMonthAnchor && other.day == day;

  @override
  int get hashCode => day.hashCode;
}

/// The nth weekday of the month, counted from the end when [index] is
/// negative. `-1` with Thursday is the last Thursday, which `ndom` cannot say:
/// counting forward, `5` fires in the months with five Thursdays and goes
/// quiet in the rest.
class NthWeekdayAnchor extends RecurrenceAnchor {
  const NthWeekdayAnchor({required this.index, required this.weekday});

  final int index;
  final int weekday;

  @override
  DateTime? dateIn(int year, int month) =>
      prognosisNthWeekdayOfMonth(year, month, index, weekday);

  @override
  String get ruleValue => 'weekday:$index,$weekday';

  @override
  bool operator ==(Object other) =>
      other is NthWeekdayAnchor &&
      other.index == index &&
      other.weekday == weekday;

  @override
  int get hashCode => Object.hash(index, weekday);
}

/// A monthly schedule said as a rule rather than as a day number.
///
/// Firefly stores a day of the month and, separately, what to do about
/// weekends. "Last banking day of the month" is reachable by pairing the two,
/// but nothing in the stored data says that is what was meant: the intent lives
/// in the reader's head, the two settings can drift apart, and no validation
/// can tell a deliberate pairing from an accidental one. The rule says it once.
///
/// Firefly cannot store this, so it rides in the recurrence notes and
/// FireRaccoon's own expansion honours it. Firefly's repetition stays as the
/// fallback for anything the server generates.
class RecurrenceScheduleRule {
  const RecurrenceScheduleRule({
    required this.anchor,
    this.adjustment = RecurrenceDateAdjustment.none,
    this.calendar = BankingCalendar.weekendOnly,
  });

  final RecurrenceAnchor anchor;
  final RecurrenceDateAdjustment adjustment;
  final BankingCalendar calendar;

  /// The date this rule falls on in that month, or null when the month has no
  /// such day.
  DateTime? dateIn(int year, int month) {
    final anchored = anchor.dateIn(year, month);
    if (anchored == null) return null;
    return switch (adjustment) {
      RecurrenceDateAdjustment.none => anchored,
      RecurrenceDateAdjustment.previousBankingDay => calendar.onOrBefore(
        anchored,
      ),
      RecurrenceDateAdjustment.nextBankingDay => calendar.onOrAfter(anchored),
    };
  }

  /// `anchor=day:31;adjust=previous-banking;calendar=SE`.
  String get ruleValue =>
      'anchor=${anchor.ruleValue};'
      'adjust=${adjustment.ruleValue};'
      'calendar=${calendar.name}';

  /// Reads [ruleValue], refusing anything it does not recognise rather than
  /// falling back to a default that would schedule the wrong day in silence.
  factory RecurrenceScheduleRule.parse(String raw) {
    final fields = <String, String>{};
    for (final part in raw.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final split = trimmed.indexOf('=');
      if (split <= 0) {
        throw FormatException('"$trimmed" is not key=value');
      }
      fields[trimmed.substring(0, split)] = trimmed.substring(split + 1);
    }

    final anchor = fields['anchor'];
    if (anchor == null) throw const FormatException('anchor is required');

    final adjustmentRaw =
        fields['adjust'] ?? RecurrenceDateAdjustment.none.ruleValue;
    final adjustment = RecurrenceDateAdjustment.byRuleValue(adjustmentRaw);
    if (adjustment == null) {
      throw FormatException(
        'adjust must be one of '
        '${RecurrenceDateAdjustment.values.map((a) => a.ruleValue).join(', ')}, '
        'got "$adjustmentRaw"',
      );
    }

    final calendarRaw = fields['calendar'] ?? BankingCalendar.weekendOnly.name;
    final calendar = BankingCalendar.byName(calendarRaw);
    if (calendar == null) {
      throw FormatException(
        'calendar must be one of ${BankingCalendar.names.join(', ')}, '
        'got "$calendarRaw"',
      );
    }

    return RecurrenceScheduleRule(
      anchor: RecurrenceAnchor.parse(anchor),
      adjustment: adjustment,
      calendar: calendar,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecurrenceScheduleRule &&
      other.anchor == anchor &&
      other.adjustment == adjustment &&
      other.calendar.name == calendar.name;

  @override
  int get hashCode => Object.hash(anchor, adjustment, calendar.name);
}

/// Marker the rule rides under in a recurrence's notes.
const kScheduleRuleMarker = 'fireraccoon:schedule:';

final RegExp _scheduleRuleLine = RegExp(
  r'^\s*firerac{1,2}oon:schedule:(.*)$',
  multiLine: true,
);

/// The rule [notes] carries, or null when there is none or it cannot be read.
///
/// Unreadable reads as absent: a rule nobody can parse is Firefly's own
/// repetition, which is the safe half of the fallback. Writing one goes
/// through [RecurrenceScheduleRule.parse], which refuses instead.
RecurrenceScheduleRule? scheduleRuleFromNotes(String? notes) {
  if (notes == null) return null;
  final match = _scheduleRuleLine.firstMatch(notes);
  if (match == null) return null;
  try {
    return RecurrenceScheduleRule.parse(match.group(1)!.trim());
  } on FormatException {
    return null;
  }
}

/// [notes] with [rule] written into it, replacing any rule already there and
/// removing the line entirely when [rule] is null.
String? notesWithScheduleRule(String? notes, RecurrenceScheduleRule? rule) {
  final kept = (notes ?? '')
      .split('\n')
      .where((line) => !_scheduleRuleLine.hasMatch(line))
      .map((line) => line.trimRight())
      .toList();
  while (kept.isNotEmpty && kept.last.isEmpty) {
    kept.removeLast();
  }
  if (rule != null) {
    kept.add('$kScheduleRuleMarker${rule.ruleValue}');
  }
  return kept.isEmpty ? null : kept.join('\n');
}
