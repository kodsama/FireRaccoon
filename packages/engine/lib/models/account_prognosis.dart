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

/// How balances are forecast: cash-flow based vs compound projection.
enum PrognosisViewMode { expected, projected }

/// Chart / forecast horizon ending at the last day of a future month.
enum PrognosisHorizon {
  endOfMonth,
  endOfNextMonth,
  twoMonths,
  threeMonths,
  sixMonths,
  oneYear,
  threeYears,
  fiveYears,
  tenYears,
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
  int get monthsAhead => switch (this) {
    PrognosisHorizon.endOfMonth => 0,
    PrognosisHorizon.endOfNextMonth => 1,
    PrognosisHorizon.twoMonths => 2,
    PrognosisHorizon.threeMonths => 3,
    PrognosisHorizon.sixMonths => 6,
    PrognosisHorizon.oneYear => 12,
    PrognosisHorizon.threeYears => 36,
    PrognosisHorizon.fiveYears => 60,
    PrognosisHorizon.tenYears => 120,
  };
}

/// Last calendar day of the month [monthsAhead] months after [reference]'s month.
DateTime prognosisHorizonEnd(DateTime reference, PrognosisHorizon horizon) {
  final ref = DateTime(reference.year, reference.month, reference.day);
  final targetMonth = ref.month + horizon.monthsAhead;
  return DateTime(ref.year, targetMonth + 1, 0);
}

DateTime prognosisMilestoneDate(
  DateTime reference,
  PrognosisMilestone milestone,
) {
  return prognosisHorizonEnd(
    reference,
    _horizonForMonths(milestone.monthsAhead),
  );
}

PrognosisHorizon _horizonForMonths(int months) => switch (months) {
  0 => PrognosisHorizon.endOfMonth,
  1 => PrognosisHorizon.endOfNextMonth,
  2 => PrognosisHorizon.twoMonths,
  3 => PrognosisHorizon.threeMonths,
  6 => PrognosisHorizon.sixMonths,
  12 => PrognosisHorizon.oneYear,
  36 => PrognosisHorizon.threeYears,
  60 => PrognosisHorizon.fiveYears,
  120 => PrognosisHorizon.tenYears,
  _ => PrognosisHorizon.endOfMonth,
};

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
      prognosisStartOfDay(
        date,
      ).isAfter(prognosisStartOfDay(timeline.last.date));

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
  final PrognosisViewMode mode;
  final PrognosisHorizon horizon;

  const PrognosisOptions({
    this.inclusion = const PrognosisInclusionOptions(),
    this.marginPercent = 15,
    this.reference,
    this.mode = PrognosisViewMode.expected,
    this.horizon = PrognosisHorizon.endOfNextMonth,
  });

  @Deprecated('Use inclusion.includeCreditCards')
  bool get includeCreditCardPayments => inclusion.includeCreditCards;
}

class AccountPrognosisResult {
  final DateTime reference;
  final DateTime endOfThisMonth;
  final DateTime endOfNextMonth;
  final DateTime horizonEnd;
  final PrognosisViewMode mode;
  final PrognosisHorizon horizon;
  final List<AccountPrognosis> accounts;

  const AccountPrognosisResult({
    required this.reference,
    required this.endOfThisMonth,
    required this.endOfNextMonth,
    required this.horizonEnd,
    required this.mode,
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
