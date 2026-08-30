import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/models/projection.dart';
import 'package:fireraccoon/services/projection_service.dart';

void main() {
  group('ProjectionService', () {
    test('savings projection produces widening worst/best band', () {
      final result = ProjectionService.project(
        currentBalance: 10000,
        transactions: [],
        params: const ProjectionParams(
          type: ProjectionType.savings,
          months: 6,
          whatIfPercent: 0,
        ),
      );

      expect(result.expected.length, 7);
      expect(result.worst.length, 7);
      expect(result.best.length, 7);
      expect(result.endExpected, greaterThan(result.startBalance));
      expect(result.endWorst, lessThan(result.endExpected));
      expect(result.endBest, greaterThan(result.endExpected));
      expect(result.best.last, greaterThan(result.worst.last));
    });

    test('what-if increases expected end balance', () {
      final base = ProjectionService.project(
        currentBalance: 5000,
        transactions: [],
        params: const ProjectionParams(type: ProjectionType.savings, months: 6),
      );
      final boosted = ProjectionService.project(
        currentBalance: 5000,
        transactions: [],
        params: const ProjectionParams(
          type: ProjectionType.savings,
          months: 6,
          whatIfPercent: 20,
        ),
      );

      expect(boosted.endExpected, greaterThan(base.endExpected));
    });

    test('compound projection grows faster than linear savings', () {
      final savings = ProjectionService.project(
        currentBalance: 10000,
        transactions: [],
        params: const ProjectionParams(
          type: ProjectionType.savings,
          months: 12,
        ),
      );
      final compound = ProjectionService.project(
        currentBalance: 10000,
        transactions: [],
        params: const ProjectionParams(
          type: ProjectionType.compound,
          months: 12,
          annualReturnPercent: 10,
        ),
      );

      expect(compound.endExpected, greaterThan(savings.endExpected));
    });

    test('portfolio band is wider than compound at same return', () {
      final compound = ProjectionService.project(
        currentBalance: 10000,
        transactions: [],
        params: const ProjectionParams(
          type: ProjectionType.compound,
          months: 12,
          annualReturnPercent: 8,
        ),
      );
      final portfolio = ProjectionService.project(
        currentBalance: 10000,
        transactions: [],
        params: const ProjectionParams(
          type: ProjectionType.portfolio,
          months: 12,
          annualReturnPercent: 8,
          volatilityPercent: 20,
        ),
      );

      final compoundSpread = compound.endBest - compound.endWorst;
      final portfolioSpread = portfolio.endBest - portfolio.endWorst;
      expect(portfolioSpread, greaterThan(compoundSpread));
    });

    test('buildHistorical reconstructs past from current balance', () {
      final hist = ProjectionService.buildHistorical(
        currentBalance: 1000,
        monthlyNet: 100,
        points: 5,
      );
      expect(hist.first, 600);
      expect(hist.last, 1000);
    });

    test('whatIfImpact scales with months and percent', () {
      final impact = ProjectionService.whatIfImpact(
        discretionary: 500,
        whatIfPercent: 10,
        months: 6,
      );
      expect(impact, 300);
    });
  });
}
