import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:test/test.dart';

void main() {
  const snapshot = PrognosisBalanceSnapshot(
    expected: 1000,
    pessimistic: 900,
    optimistic: 1100,
  );

  group('PrognosisBalanceSnapshot', () {
    test('min and max alias pessimistic and optimistic', () {
      expect(snapshot.min, 900);
      expect(snapshot.max, 1100);
    });
  });

  group('PrognosisBalancePoint', () {
    test('min and max alias pessimistic and optimistic', () {
      final point = PrognosisBalancePoint(
        date: DateTime(2026, 7, 31),
        expected: 1000,
        pessimistic: 900,
        optimistic: 1100,
      );

      expect(point.min, 900);
      expect(point.max, 1100);
    });
  });

  group('PrognosisEvent', () {
    test('deltaForScenario picks the matching band', () {
      final event = PrognosisEvent(
        date: DateTime(2026, 7, 15),
        accountId: '1',
        expectedDelta: -100,
        pessimisticDelta: -120,
        optimisticDelta: -80,
        description: 'Rent',
        source: PrognosisEventSource.recurrence,
      );

      expect(event.deltaForScenario(PrognosisScenario.expected), -100);
      expect(event.deltaForScenario(PrognosisScenario.min), -120);
      expect(event.deltaForScenario(PrognosisScenario.max), -80);
    });
  });

  group('PrognosisMilestoneX', () {
    test('monthsAhead and display order', () {
      expect(PrognosisMilestone.endOfMonth.monthsAhead, 0);
      expect(PrognosisMilestone.endOfNextMonth.monthsAhead, 1);
      expect(PrognosisMilestone.threeMonths.monthsAhead, 3);
      expect(PrognosisMilestone.sixMonths.monthsAhead, 6);
      expect(PrognosisMilestone.oneYear.monthsAhead, 12);
      expect(prognosisDisplayMilestones, PrognosisMilestoneX.displayOrder);
    });
  });

  group('PrognosisHorizonX', () {
    test('monthsAhead covers every horizon', () {
      expect(PrognosisHorizon.endOfMonth.monthsAhead, 0);
      expect(PrognosisHorizon.endOfNextMonth.monthsAhead, 1);
      expect(PrognosisHorizon.twoMonths.monthsAhead, 2);
      expect(PrognosisHorizon.threeMonths.monthsAhead, 3);
      expect(PrognosisHorizon.sixMonths.monthsAhead, 6);
      expect(PrognosisHorizon.oneYear.monthsAhead, 12);
      expect(PrognosisHorizon.threeYears.monthsAhead, 36);
      expect(PrognosisHorizon.fiveYears.monthsAhead, 60);
      expect(PrognosisHorizon.tenYears.monthsAhead, 120);
    });
  });

  group('prognosisHorizonEnd', () {
    test('returns last day of target month', () {
      final end = prognosisHorizonEnd(
        DateTime(2026, 7, 7),
        PrognosisHorizon.endOfMonth,
      );
      expect(end, DateTime(2026, 7, 31));

      final next = prognosisHorizonEnd(
        DateTime(2026, 7, 7),
        PrognosisHorizon.endOfNextMonth,
      );
      expect(next, DateTime(2026, 8, 31));
    });
  });

  group('prognosisMilestoneDate', () {
    test('maps milestones to horizon end dates', () {
      final threeMonths = prognosisMilestoneDate(
        DateTime(2026, 7, 7),
        PrognosisMilestone.threeMonths,
      );
      expect(threeMonths, DateTime(2026, 10, 31));
    });
  });

  group('AccountPrognosis', () {
    test('milestone falls back to endOfMonth', () {
      const prognosis = AccountPrognosis(
        accountId: '1',
        accountName: 'Checking',
        accountType: 'asset',
        currencySymbol: '€',
        currentBalance: 1000,
        endOfMonth: snapshot,
        endOfNextMonth: snapshot,
        milestones: {},
        showWarning: false,
        events: [],
        timeline: [],
      );

      expect(prognosis.milestone(PrognosisMilestone.sixMonths), snapshot);
      expect(prognosis.hasNegativeRisk, isFalse);
      expect(prognosis.projectedEndOfMonth, 1000);
      expect(prognosis.delta, 0);
      expect(prognosis.forwardSparkline, isEmpty);
    });

    test('tracks negative risk and sparkline', () {
      final prognosis = AccountPrognosis(
        accountId: '1',
        accountName: 'Checking',
        accountType: 'asset',
        currencySymbol: '€',
        currentBalance: 1000,
        endOfMonth: snapshot,
        endOfNextMonth: snapshot,
        milestones: {PrognosisMilestone.oneYear: snapshot},
        showWarning: true,
        firstNegativeDate: DateTime(2026, 7, 20),
        events: [],
        timeline: [
          PrognosisBalancePoint(
            date: DateTime(2026, 7, 20),
            expected: 900,
            pessimistic: 800,
            optimistic: 950,
          ),
        ],
      );

      expect(prognosis.hasNegativeRisk, isTrue);
      expect(prognosis.milestone(PrognosisMilestone.oneYear), snapshot);
      expect(prognosis.forwardSparkline, [900]);
    });
  });

  group('PrognosisInclusionOptions', () {
    test('copyWith toggles inclusion flags', () {
      const base = PrognosisInclusionOptions();
      final updated = base.copyWith(
        includeScheduledTransactions: false,
        includeRecurringTransactions: false,
        includeBills: false,
        includeIncome: false,
        includeExpenses: false,
        includeTransfers: false,
        includeCreditCards: false,
        includeLiabilities: false,
      );

      expect(updated.includeScheduledTransactions, isFalse);
      expect(updated.includeRecurringTransactions, isFalse);
      expect(updated.includeBills, isFalse);
      expect(updated.includeIncome, isFalse);
      expect(updated.includeExpenses, isFalse);
      expect(updated.includeTransfers, isFalse);
      expect(updated.includeCreditCards, isFalse);
      expect(updated.includeLiabilities, isFalse);
    });

    test('copyWith without args preserves defaults', () {
      const base = PrognosisInclusionOptions(includeBills: false);
      final clone = base.copyWith();
      expect(clone.includeBills, isFalse);
      expect(clone.includeIncome, isTrue);
    });
  });

  group('PrognosisOptions', () {
    test('deprecated includeCreditCardPayments mirrors inclusion flag', () {
      const on = PrognosisOptions(
        inclusion: PrognosisInclusionOptions(includeCreditCards: true),
      );
      const off = PrognosisOptions(
        inclusion: PrognosisInclusionOptions(includeCreditCards: false),
      );

      expect(on.includeCreditCardPayments, isTrue);
      expect(off.includeCreditCardPayments, isFalse);
    });
  });

  group('AccountPrognosisResult', () {
    test('forAccount finds prognosis and deprecated monthEnd alias', () {
      const prognosis = AccountPrognosis(
        accountId: '1',
        accountName: 'Checking',
        accountType: 'asset',
        currencySymbol: '€',
        currentBalance: 1000,
        endOfMonth: snapshot,
        endOfNextMonth: snapshot,
        milestones: {},
        showWarning: false,
        events: [],
        timeline: [],
      );
      final result = AccountPrognosisResult(
        reference: DateTime(2026, 7, 7),
        endOfThisMonth: DateTime(2026, 7, 31),
        endOfNextMonth: DateTime(2026, 8, 31),
        horizonEnd: DateTime(2026, 8, 31),
        mode: PrognosisViewMode.expected,
        horizon: PrognosisHorizon.endOfNextMonth,
        accounts: [prognosis],
      );

      expect(result.forAccount('1'), prognosis);
      expect(result.forAccount('missing'), isNull);
      expect(result.monthEnd, result.endOfThisMonth);
    });
  });
}
