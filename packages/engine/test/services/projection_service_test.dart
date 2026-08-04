import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:test/test.dart';

Transaction _tx({
  required String type,
  required double amount,
  required DateTime date,
  List<Transaction>? splits,
}) {
  return Transaction(
    id: 't-$type-$amount-${date.millisecondsSinceEpoch}',
    type: type,
    date: date,
    amount: amount,
    description: type,
    sourceName: 'Src',
    destinationName: 'Dst',
    categoryName: '',
    currencySymbol: '€',
    currencyCode: 'EUR',
    splits: splits ?? const [],
  );
}

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
      expect(result.endExpected, greaterThan(result.startBalance));
      expect(result.endBest, greaterThan(result.endExpected));
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

    test('buildHistorical reconstructs past from current balance', () {
      final hist = ProjectionService.buildHistorical(
        currentBalance: 1000,
        monthlyNet: 100,
        points: 5,
      );
      expect(hist.first, 600);
      expect(hist.last, 1000);
    });

    test('cashFlowStats normalizes a multi-month window to monthly rates', () {
      final txs = [
        _tx(type: 'deposit', amount: 3000, date: DateTime(2025, 1, 1)),
        _tx(type: 'deposit', amount: 3000, date: DateTime(2025, 2, 1)),
        _tx(type: 'deposit', amount: 3000, date: DateTime(2025, 3, 1)),
        _tx(type: 'withdrawal', amount: 1500, date: DateTime(2025, 1, 15)),
        _tx(type: 'withdrawal', amount: 1500, date: DateTime(2025, 2, 15)),
        _tx(type: 'withdrawal', amount: 1500, date: DateTime(2025, 3, 1)),
      ];

      final monthly = ProjectionService.cashFlowStats(txs);
      final raw = ProjectionService.cashFlowStats(
        txs,
        normalizeToMonthly: false,
      );

      expect(raw.income, 9000);
      expect(raw.expenses, 4500);
      // ~2 months span (Jan 1 → Mar 1) → monthly ≈ half of raw totals.
      expect(monthly.income, closeTo(raw.income / 2, 500));
      expect(monthly.expenses, closeTo(raw.expenses / 2, 250));
      expect(monthly.net, lessThan(raw.net));
    });

    test('cashFlowStats sums split journal totalAmount', () {
      final splitA = _tx(
        type: 'withdrawal',
        amount: 40,
        date: DateTime(2025, 6, 1),
      );
      final splitB = _tx(
        type: 'withdrawal',
        amount: 60,
        date: DateTime(2025, 6, 1),
      );
      final journal = splitA.copyWith(splits: [splitA, splitB]);

      final stats = ProjectionService.cashFlowStats([
        journal,
      ], normalizeToMonthly: false);
      expect(stats.expenses, 100);
    });

    test('negative cashflow triggers belowZero alert', () {
      final txs = [
        _tx(type: 'withdrawal', amount: 5000, date: DateTime(2025, 1, 1)),
        _tx(type: 'withdrawal', amount: 5000, date: DateTime(2025, 2, 1)),
      ];

      final result = ProjectionService.project(
        currentBalance: 2000,
        transactions: txs,
        params: const ProjectionParams(
          type: ProjectionType.savings,
          months: 12,
          whatIfPercent: 0,
        ),
      );

      expect(result.worst.any((v) => v < 0), isTrue);
      expect(result.alert?.kind, ProjectionAlertKind.belowZero);
    });

    test('worst scenario is not clamped to zero', () {
      final txs = [
        _tx(type: 'withdrawal', amount: 8000, date: DateTime(2025, 1, 1)),
        _tx(type: 'withdrawal', amount: 8000, date: DateTime(2025, 2, 1)),
      ];

      final result = ProjectionService.project(
        currentBalance: 1000,
        transactions: txs,
        params: const ProjectionParams(
          type: ProjectionType.cashflow,
          months: 6,
        ),
      );

      expect(result.endWorst, lessThan(0));
    });

    test('compound projection grows with contributions', () {
      final result = ProjectionService.project(
        currentBalance: 10000,
        transactions: [
          _tx(type: 'deposit', amount: 500, date: DateTime(2025, 1, 1)),
        ],
        params: const ProjectionParams(
          type: ProjectionType.compound,
          months: 12,
          annualReturnPercent: 6,
          whatIfPercent: 10,
        ),
      );

      expect(result.endExpected, greaterThan(10000));
      expect(result.endBest, greaterThan(result.endExpected));
    });

    test('portfolio projection uses volatility bands', () {
      final result = ProjectionService.project(
        currentBalance: 5000,
        transactions: [
          _tx(type: 'deposit', amount: 200, date: DateTime(2025, 1, 1)),
        ],
        params: const ProjectionParams(
          type: ProjectionType.portfolio,
          months: 6,
          annualReturnPercent: 8,
          volatilityPercent: 20,
        ),
      );

      expect(result.worst.last, lessThan(result.expected.last));
      expect(result.best.last, greaterThan(result.expected.last));
    });

    test('compound with zero return stays linear', () {
      final result = ProjectionService.project(
        currentBalance: 1000,
        transactions: [
          _tx(type: 'deposit', amount: 100, date: DateTime(2025, 1, 1)),
        ],
        params: const ProjectionParams(
          type: ProjectionType.compound,
          months: 3,
          annualReturnPercent: 0,
        ),
      );

      expect(result.endExpected, greaterThan(1000));
    });

    test('cashflow projection applies discretionary cuts from what-if', () {
      final result = ProjectionService.project(
        currentBalance: 2000,
        transactions: [
          _tx(type: 'deposit', amount: 3000, date: DateTime(2025, 1, 1)),
          _tx(type: 'withdrawal', amount: 2500, date: DateTime(2025, 1, 15)),
        ],
        params: const ProjectionParams(
          type: ProjectionType.cashflow,
          months: 6,
          whatIfPercent: 50,
        ),
      );

      final baseline = ProjectionService.project(
        currentBalance: 2000,
        transactions: [
          _tx(type: 'deposit', amount: 3000, date: DateTime(2025, 1, 1)),
          _tx(type: 'withdrawal', amount: 2500, date: DateTime(2025, 1, 15)),
        ],
        params: const ProjectionParams(
          type: ProjectionType.cashflow,
          months: 6,
        ),
      );

      expect(result.endExpected, greaterThan(baseline.endExpected));
    });

    test('liability risk alert when worst dips and liability exists', () {
      final accounts = [
        Account(
          id: '1',
          name: 'Checking',
          type: 'asset',
          role: 'defaultAsset',
          currentBalance: 500,
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
        Account(
          id: '2',
          name: 'Visa',
          type: 'liability',
          role: 'ccAsset',
          currentBalance: -1200,
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
      ];

      final result = ProjectionService.project(
        currentBalance: 500,
        transactions: [
          _tx(type: 'withdrawal', amount: 2000, date: DateTime(2025, 1, 1)),
        ],
        params: const ProjectionParams(type: ProjectionType.savings, months: 6),
        accounts: accounts,
      );

      expect(result.alert?.kind, ProjectionAlertKind.liabilityRisk);
      expect(result.alert?.liabilityName, 'Visa');
    });

    test('buildHistorical returns current balance when points is zero', () {
      expect(
        ProjectionService.buildHistorical(
          currentBalance: 500,
          monthlyNet: 100,
          points: 0,
        ),
        [500],
      );
    });

    test('cashFlowStats uses fallback discretionary when no expenses', () {
      final stats = ProjectionService.cashFlowStats(
        [],
        normalizeToMonthly: false,
      );
      expect(stats.income, 0);
      expect(stats.discretionary, closeTo(525, 0.01));
    });

    test('whatIfImpact scales discretionary savings over months', () {
      expect(
        ProjectionService.whatIfImpact(
          discretionary: 100,
          whatIfPercent: 20,
          months: 6,
        ),
        120,
      );
    });
  });

  group('ProjectionService.projectAccounts', () {
    Account account({
      required String id,
      required String name,
      String type = 'asset',
      String role = 'defaultAsset',
      double balance = 1000,
    }) {
      return Account(
        id: id,
        name: name,
        type: type,
        role: role,
        currentBalance: balance,
        currencySymbol: '€',
        currencyCode: 'EUR',
      );
    }

    test('applies growth factors per projection type', () {
      final accounts = [account(id: '1', name: 'Checking', balance: 1000)];

      final savings = ProjectionService.projectAccounts(
        accounts: accounts,
        params: const ProjectionParams(
          type: ProjectionType.savings,
          months: 12,
        ),
        whatIfBoost: 0,
      );
      final compound = ProjectionService.projectAccounts(
        accounts: accounts,
        params: const ProjectionParams(
          type: ProjectionType.compound,
          months: 12,
          annualReturnPercent: 6,
        ),
        whatIfBoost: 0,
      );
      final portfolio = ProjectionService.projectAccounts(
        accounts: accounts,
        params: const ProjectionParams(
          type: ProjectionType.portfolio,
          months: 12,
          annualReturnPercent: 6,
        ),
        whatIfBoost: 0,
      );
      final cashflow = ProjectionService.projectAccounts(
        accounts: accounts,
        params: const ProjectionParams(
          type: ProjectionType.cashflow,
          months: 12,
        ),
        whatIfBoost: 0,
      );

      expect(savings.single.predicted, greaterThan(1000));
      expect(compound.single.predicted, greaterThan(savings.single.predicted));
      expect(portfolio.single.predicted, greaterThan(1000));
      expect(cashflow.single.predicted, greaterThan(1000));
    });

    test('icons and liability handling differ by account role', () {
      final projections = ProjectionService.projectAccounts(
        accounts: [
          account(id: '1', name: 'Checking', role: 'defaultAsset'),
          account(id: '2', name: 'Savings', role: 'savingAsset'),
          account(
            id: '3',
            name: 'Visa',
            type: 'liability',
            role: 'ccAsset',
            balance: -500,
          ),
        ],
        params: const ProjectionParams(type: ProjectionType.savings, months: 6),
        whatIfBoost: 200,
      );

      expect(projections[0].icon, 'wallet');
      expect(projections[0].predicted, greaterThan(1200));
      expect(projections[1].icon, 'piggy-bank');
      expect(projections[2].icon, 'credit-card');
      expect(projections[2].isLiability, isTrue);
      expect(projections[2].predicted, lessThan(-480));
    });
  });
}
