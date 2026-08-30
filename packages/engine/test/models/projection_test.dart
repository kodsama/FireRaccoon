import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectionType', () {
    test('labels and descriptions cover every variant', () {
      expect(ProjectionType.savings.label, 'Savings rate');
      expect(ProjectionType.compound.label, 'Compound growth');
      expect(ProjectionType.portfolio.label, 'Portfolio (volatile)');
      expect(ProjectionType.cashflow.label, 'Cash flow');

      for (final type in ProjectionType.values) {
        expect(type.description, isNotEmpty);
      }
    });
  });

  group('ProjectionChartStyle', () {
    test('labels cover every variant', () {
      expect(ProjectionChartStyle.fan.label, 'Fan chart');
      expect(ProjectionChartStyle.lines.label, 'Three lines');
      expect(ProjectionChartStyle.scenarios.label, 'Scenario cards');
    });
  });

  group('ProjectionParams', () {
    test('copyWith replaces selected fields', () {
      const base = ProjectionParams(
        type: ProjectionType.savings,
        months: 6,
        whatIfPercent: 10,
        annualReturnPercent: 5,
        volatilityPercent: 8,
        chartStyle: ProjectionChartStyle.fan,
      );

      final updated = base.copyWith(
        type: ProjectionType.portfolio,
        months: 12,
        whatIfPercent: 20,
        annualReturnPercent: 9,
        volatilityPercent: 15,
        chartStyle: ProjectionChartStyle.lines,
      );

      expect(updated.type, ProjectionType.portfolio);
      expect(updated.months, 12);
      expect(updated.whatIfPercent, 20);
      expect(updated.annualReturnPercent, 9);
      expect(updated.volatilityPercent, 15);
      expect(updated.chartStyle, ProjectionChartStyle.lines);
    });

    test('copyWith keeps unspecified fields', () {
      const base = ProjectionParams(months: 6, whatIfPercent: 5);
      final updated = base.copyWith(months: 12);

      expect(updated.months, 12);
      expect(updated.whatIfPercent, 5);
      expect(updated.type, ProjectionType.savings);
      expect(updated.annualReturnPercent, 7.0);
      expect(updated.volatilityPercent, 12.0);
      expect(updated.chartStyle, ProjectionChartStyle.fan);

      final untouched = base.copyWith(whatIfPercent: 10);
      expect(untouched.months, 6);
    });
  });

  group('ProjectionResult', () {
    test('end getters fall back when series are empty', () {
      const empty = ProjectionResult(
        historical: [],
        expected: [],
        worst: [],
        best: [],
        historyCount: 0,
      );

      expect(empty.startBalance, 0);
      expect(empty.endExpected, 0);
      expect(empty.endWorst, 0);
      expect(empty.endBest, 0);
      expect(empty.growthPercent(0), 0);
    });

    test('growthPercent measures change from a base', () {
      const result = ProjectionResult(
        historical: [1000],
        expected: [1000, 1200],
        worst: [1000, 900],
        best: [1000, 1300],
        historyCount: 1,
      );

      expect(result.startBalance, 1000);
      expect(result.endExpected, 1200);
      expect(result.endWorst, 900);
      expect(result.endBest, 1300);
      expect(result.growthPercent(1000), closeTo(20, 0.01));
      expect(result.growthPercent(0), 0);
    });
  });

  group('AccountProjection', () {
    test('change is predicted minus current', () {
      const projection = AccountProjection(
        name: 'Checking',
        icon: 'wallet',
        current: 1000,
        predicted: 1150,
      );

      expect(projection.change, 150);
      expect(projection.isLiability, isFalse);
    });
  });

  group('ProjectionAlert', () {
    test('carries liability details for risk alerts', () {
      const alert = ProjectionAlert(
        kind: ProjectionAlertKind.liabilityRisk,
        liabilityName: 'Visa',
        liabilityBalance: -500,
      );

      expect(alert.kind, ProjectionAlertKind.liabilityRisk);
      expect(alert.liabilityName, 'Visa');
      expect(alert.liabilityBalance, -500);
    });
  });
}
