import '../services/recurrence_scheduler.dart';

enum PrognosisEventSource { scheduledTransaction, recurrence, bill }

enum ScheduledFlowSource { transaction, recurrence, bill }

class PrognosisBalanceSnapshot {
  final double expected;
  final double pessimistic;
  final double optimistic;

  const PrognosisBalanceSnapshot({
    required this.expected,
    required this.pessimistic,
    required this.optimistic,
  });

  double get min => pessimistic;
  double get max => optimistic;
}

class PrognosisBalancePoint {
  final DateTime date;
  final double expected;
  final double pessimistic;
  final double optimistic;

  const PrognosisBalancePoint({
    required this.date,
    required this.expected,
    required this.pessimistic,
    required this.optimistic,
  });

  double get min => pessimistic;
  double get max => optimistic;
}

class PrognosisEvent {
  final DateTime date;
  final String accountId;
  final double expectedDelta;
  final double pessimisticDelta;
  final double optimisticDelta;
  final String description;
  final PrognosisEventSource source;
  final bool isCreditCardRelated;

  const PrognosisEvent({
    required this.date,
    required this.accountId,
    required this.expectedDelta,
    required this.pessimisticDelta,
    required this.optimisticDelta,
    required this.description,
    required this.source,
    this.isCreditCardRelated = false,
  });

  double deltaForScenario(PrognosisScenario scenario) => switch (scenario) {
    PrognosisScenario.expected => expectedDelta,
    PrognosisScenario.min => pessimisticDelta,
    PrognosisScenario.max => optimisticDelta,
  };
}

enum PrognosisScenario { expected, min, max }

/// How far ahead a forecast runs.
///
/// Most of these land on a month end. The short ones do not, and
/// [PrognosisHorizon.customDate] runs to whatever day was picked.
enum PrognosisHorizon {
  twoWeeks,
  endOfMonth,
  midNextMonth,
  endOfNextMonth,
  twoMonths,
  threeMonths,
  sixMonths,
  oneYear,
  threeYears,
  fiveYears,
  tenYears,
  customDate,
}

/// Key balance checkpoints shown on account cards.
enum PrognosisMilestone {
  endOfMonth,
  endOfNextMonth,
  threeMonths,
  sixMonths,
  oneYear,
}

extension PrognosisMilestoneX on PrognosisMilestone {
  static const displayOrder = [
    PrognosisMilestone.endOfMonth,
    PrognosisMilestone.endOfNextMonth,
    PrognosisMilestone.threeMonths,
    PrognosisMilestone.sixMonths,
    PrognosisMilestone.oneYear,
  ];

  /// Months ahead from the reference month (0 = current month end).
  int get monthsAhead => switch (this) {
    PrognosisMilestone.endOfMonth => 0,
    PrognosisMilestone.endOfNextMonth => 1,
    PrognosisMilestone.threeMonths => 3,
    PrognosisMilestone.sixMonths => 6,
    PrognosisMilestone.oneYear => 12,
  };
}

const prognosisDisplayMilestones = [
  PrognosisMilestone.endOfMonth,
  PrognosisMilestone.endOfNextMonth,
  PrognosisMilestone.threeMonths,
  PrognosisMilestone.sixMonths,
  PrognosisMilestone.oneYear,
];

extension PrognosisHorizonX on PrognosisHorizon {
  /// Whether the horizon means nothing until a date is chosen for it.
  bool get needsDate => this == PrognosisHorizon.customDate;
}

/// The last day a forecast on [horizon] covers, counted from [reference].
///
/// [customDate] is the day [PrognosisHorizon.customDate] runs to and is
/// ignored by the rest. One already gone by leaves nothing to forecast, so it
/// is held at [reference]: a date picked last month goes stale on its own,
/// without anybody touching it.
DateTime prognosisHorizonEnd(
  DateTime reference,
  PrognosisHorizon horizon, {
  DateTime? customDate,
}) {
  final ref = prognosisStartOfDay(reference);
  return switch (horizon) {
    PrognosisHorizon.twoWeeks => DateTime(ref.year, ref.month, ref.day + 14),
    PrognosisHorizon.midNextMonth => DateTime(ref.year, ref.month + 1, 15),
    PrognosisHorizon.customDate => _pickedHorizonEnd(ref, customDate),
    PrognosisHorizon.endOfMonth => _monthEnd(ref, 0),
    PrognosisHorizon.endOfNextMonth => _monthEnd(ref, 1),
    PrognosisHorizon.twoMonths => _monthEnd(ref, 2),
    PrognosisHorizon.threeMonths => _monthEnd(ref, 3),
    PrognosisHorizon.sixMonths => _monthEnd(ref, 6),
    PrognosisHorizon.oneYear => _monthEnd(ref, 12),
    PrognosisHorizon.threeYears => _monthEnd(ref, 36),
    PrognosisHorizon.fiveYears => _monthEnd(ref, 60),
    PrognosisHorizon.tenYears => _monthEnd(ref, 120),
  };
}

DateTime _monthEnd(DateTime reference, int monthsAhead) =>
    DateTime(reference.year, reference.month + monthsAhead + 1, 0);

DateTime _pickedHorizonEnd(DateTime reference, DateTime? picked) {
  if (picked == null) return _monthEnd(reference, 0);
  final day = prognosisStartOfDay(picked);
  return day.isBefore(reference) ? reference : day;
}

DateTime prognosisMilestoneDate(
  DateTime reference,
  PrognosisMilestone milestone,
) {
  return _monthEnd(prognosisStartOfDay(reference), milestone.monthsAhead);
}

class AccountPrognosis {
  final String accountId;
  final String accountName;
  final String accountType;
  final String currencySymbol;
  final double currentBalance;
  final PrognosisBalanceSnapshot endOfMonth;
  final PrognosisBalanceSnapshot endOfNextMonth;
  final Map<PrognosisMilestone, PrognosisBalanceSnapshot> milestones;
  final bool showWarning;
  final DateTime? firstNegativeDate;
  final List<PrognosisEvent> events;
  final List<PrognosisBalancePoint> timeline;

  const AccountPrognosis({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.currencySymbol,
    required this.currentBalance,
    required this.endOfMonth,
    required this.endOfNextMonth,
    required this.milestones,
    required this.showWarning,
    this.firstNegativeDate,
    required this.events,
    required this.timeline,
  });

  PrognosisBalanceSnapshot milestone(PrognosisMilestone key) =>
      milestones[key] ?? endOfMonth;

  /// Forecast for the end of [date].
  ///
  /// The timeline carries a point per day, so any date inside it answers
  /// exactly; the fixed milestones are only five samples of the same series.
  /// Before the timeline starts there is nothing forecast yet, so the current
  /// balance stands; after it ends the last point does, since the forecast
  /// simply does not reach further.
  PrognosisBalanceSnapshot snapshotOn(DateTime date) {
    if (timeline.isEmpty) {
      return PrognosisBalanceSnapshot(
        expected: currentBalance,
        pessimistic: currentBalance,
        optimistic: currentBalance,
      );
    }
    final target = prognosisStartOfDay(date);
    PrognosisBalancePoint? match;
    for (final point in timeline) {
      if (prognosisStartOfDay(point.date).isAfter(target)) break;
      match = point;
    }
    if (match == null) {
      return PrognosisBalanceSnapshot(
        expected: currentBalance,
        pessimistic: currentBalance,
        optimistic: currentBalance,
      );
    }
    return PrognosisBalanceSnapshot(
      expected: match.expected,
      pessimistic: match.pessimistic,
      optimistic: match.optimistic,
    );
  }

  /// True when [date] is past the end of the forecast, so [snapshotOn] is
  /// answering with its last point rather than a figure for that day.
  bool reachesBeyondForecast(DateTime date) =>
      timeline.isNotEmpty &&
      prognosisStartOfDay(date)
          .isAfter(prognosisStartOfDay(timeline.last.date));

  bool get hasNegativeRisk => firstNegativeDate != null;

  double get projectedEndOfMonth => endOfMonth.expected;

  double get delta => endOfMonth.expected - currentBalance;

  List<double> get forwardSparkline =>
      timeline.map((point) => point.expected).toList();
}

class PrognosisInclusionOptions {
  final bool includeScheduledTransactions;
  final bool includeRecurringTransactions;
  final bool includeBills;
  final bool includeIncome;
  final bool includeExpenses;
  final bool includeTransfers;
  final bool includeCreditCards;
  final bool includeLiabilities;

  const PrognosisInclusionOptions({
    this.includeScheduledTransactions = true,
    this.includeRecurringTransactions = true,
    this.includeBills = true,
    this.includeIncome = true,
    this.includeExpenses = true,
    this.includeTransfers = true,
    this.includeCreditCards = true,
    this.includeLiabilities = true,
  });

  PrognosisInclusionOptions copyWith({
    bool? includeScheduledTransactions,
    bool? includeRecurringTransactions,
    bool? includeBills,
    bool? includeIncome,
    bool? includeExpenses,
    bool? includeTransfers,
    bool? includeCreditCards,
    bool? includeLiabilities,
  }) {
    return PrognosisInclusionOptions(
      includeScheduledTransactions:
          includeScheduledTransactions ?? this.includeScheduledTransactions,
      includeRecurringTransactions:
          includeRecurringTransactions ?? this.includeRecurringTransactions,
      includeBills: includeBills ?? this.includeBills,
      includeIncome: includeIncome ?? this.includeIncome,
      includeExpenses: includeExpenses ?? this.includeExpenses,
      includeTransfers: includeTransfers ?? this.includeTransfers,
      includeCreditCards: includeCreditCards ?? this.includeCreditCards,
      includeLiabilities: includeLiabilities ?? this.includeLiabilities,
    );
  }
}

class PrognosisOptions {
  final PrognosisInclusionOptions inclusion;
  final double marginPercent;
  final DateTime? reference;
  final PrognosisHorizon horizon;

  /// The day [PrognosisHorizon.customDate] runs to; nothing to the others.
  final DateTime? customHorizonDate;

  const PrognosisOptions({
    this.inclusion = const PrognosisInclusionOptions(),
    this.marginPercent = 15,
    this.reference,
    this.horizon = PrognosisHorizon.endOfNextMonth,
    this.customHorizonDate,
  });

  @Deprecated('Use inclusion.includeCreditCards')
  bool get includeCreditCardPayments => inclusion.includeCreditCards;
}

class AccountPrognosisResult {
  final DateTime reference;
  final DateTime endOfThisMonth;
  final DateTime endOfNextMonth;
  final DateTime horizonEnd;
  final PrognosisHorizon horizon;
  final List<AccountPrognosis> accounts;

  const AccountPrognosisResult({
    required this.reference,
    required this.endOfThisMonth,
    required this.endOfNextMonth,
    required this.horizonEnd,
    required this.horizon,
    required this.accounts,
  });

  @Deprecated('Use endOfThisMonth')
  DateTime get monthEnd => endOfThisMonth;

  AccountPrognosis? forAccount(String accountId) {
    for (final prognosis in accounts) {
      if (prognosis.accountId == accountId) return prognosis;
    }
    return null;
  }
}
