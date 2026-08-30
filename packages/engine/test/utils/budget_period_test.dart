import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

void main() {
  group('aggregateBudgetLimit', () {
    test('scales weekly budget across a month', () {
      final range = resolveExpenseDateRange(
        period: ExpensePeriod.month,
        reference: DateTime(2026, 7, 15),
      );

      final limit = aggregateBudgetLimit(
        perPeriodAmount: 1000,
        budgetPeriod: AutoBudgetPeriod.weekly,
        viewingRange: range,
      );

      expect(limit, 4000);
    });

    test('keeps amount when budget cadence is missing', () {
      final range = resolveExpenseDateRange(
        period: ExpensePeriod.month,
        reference: DateTime(2026, 7, 15),
      );

      final limit = aggregateBudgetLimit(
        perPeriodAmount: 1000,
        budgetPeriod: null,
        viewingRange: range,
      );

      expect(limit, 1000);
    });
  });

  group('sumBudgetSpentInRange', () {
    test('sums withdrawals inside the range', () {
      final range = DateRangeBounds(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      );
      final spent = sumBudgetSpentInRange([
        Transaction(
          id: '1',
          type: 'withdrawal',
          date: DateTime(2026, 7, 5),
          amount: 40,
          description: 'A',
          sourceName: 'Checking',
          destinationName: 'Store',
          categoryName: 'Food',
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
        Transaction(
          id: '2',
          type: 'deposit',
          date: DateTime(2026, 7, 6),
          amount: 10,
          description: 'B',
          sourceName: 'Employer',
          destinationName: 'Checking',
          categoryName: 'Income',
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
        Transaction(
          id: '3',
          type: 'withdrawal',
          date: DateTime(2026, 8, 1),
          amount: 99,
          description: 'C',
          sourceName: 'Checking',
          destinationName: 'Store',
          categoryName: 'Food',
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
      ], range);

      expect(spent, 40);
    });
  });

  group('Budget.fromJson', () {
    test('parses auto_budget_period', () {
      final budget = Budget.fromJson({
        'id': '3',
        'attributes': {
          'name': 'Food',
          'active': true,
          'spent': [
            {'sum': '-120.00'},
          ],
          'auto_budget_amount': '1000',
          'auto_budget_period': 'weekly',
          'auto_budget_currency_symbol': '€',
          'auto_budget_currency_code': 'EUR',
        },
      });

      expect(budget.autoBudgetPeriod, AutoBudgetPeriod.weekly);
    });
  });

  group('AutoBudgetType and AutoBudgetPeriod parse/apiValue', () {
    test('type parse and apiValue cover branches', () {
      expect(AutoBudgetType.parse(null), AutoBudgetType.none);
      expect(AutoBudgetType.parse(''), AutoBudgetType.none);
      expect(AutoBudgetType.parse('reset'), AutoBudgetType.reset);
      expect(AutoBudgetType.parse('1'), AutoBudgetType.reset);
      expect(AutoBudgetType.parse('rollover'), AutoBudgetType.rollover);
      expect(AutoBudgetType.parse('2'), AutoBudgetType.rollover);
      expect(AutoBudgetType.parse('adjusted'), AutoBudgetType.adjusted);
      expect(AutoBudgetType.parse('3'), AutoBudgetType.adjusted);
      expect(AutoBudgetType.parse('none'), AutoBudgetType.none);
      expect(AutoBudgetType.parse('0'), AutoBudgetType.none);
      expect(AutoBudgetType.parse('weird'), AutoBudgetType.none);
      for (final t in AutoBudgetType.values) {
        expect(AutoBudgetType.parse(t.apiValue), t);
      }
    });

    test('period parse and apiValue cover branches', () {
      expect(AutoBudgetPeriod.parse(null), isNull);
      expect(AutoBudgetPeriod.parse(''), isNull);
      expect(AutoBudgetPeriod.parse('nope'), isNull);
      expect(AutoBudgetPeriod.parse('daily'), AutoBudgetPeriod.daily);
      expect(AutoBudgetPeriod.parse('weekly'), AutoBudgetPeriod.weekly);
      expect(AutoBudgetPeriod.parse('monthly'), AutoBudgetPeriod.monthly);
      expect(AutoBudgetPeriod.parse('quarterly'), AutoBudgetPeriod.quarterly);
      expect(AutoBudgetPeriod.parse('half_year'), AutoBudgetPeriod.halfYear);
      expect(AutoBudgetPeriod.parse('yearly'), AutoBudgetPeriod.yearly);
      for (final p in AutoBudgetPeriod.values) {
        expect(AutoBudgetPeriod.parse(p.apiValue), p);
      }
    });
  });

  group('countBudgetPeriodsInRange and aggregateBudgetLimit', () {
    final month = DateRangeBounds(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 8, 1),
    );

    test('counts each cadence', () {
      expect(
        countBudgetPeriodsInRange(
          budgetPeriod: AutoBudgetPeriod.daily,
          viewingRange: month,
        ),
        31,
      );
      expect(
        countBudgetPeriodsInRange(
          budgetPeriod: AutoBudgetPeriod.weekly,
          viewingRange: month,
        ),
        4,
      );
      expect(
        countBudgetPeriodsInRange(
          budgetPeriod: AutoBudgetPeriod.monthly,
          viewingRange: month,
        ),
        1,
      );
      expect(
        countBudgetPeriodsInRange(
          budgetPeriod: AutoBudgetPeriod.quarterly,
          viewingRange: DateRangeBounds(
            start: DateTime(2026, 1, 1),
            end: DateTime(2026, 10, 1),
          ),
        ),
        3,
      );
      expect(
        countBudgetPeriodsInRange(
          budgetPeriod: AutoBudgetPeriod.halfYear,
          viewingRange: DateRangeBounds(
            start: DateTime(2026, 1, 1),
            end: DateTime(2027, 1, 1),
          ),
        ),
        2,
      );
      expect(
        countBudgetPeriodsInRange(
          budgetPeriod: AutoBudgetPeriod.yearly,
          viewingRange: DateRangeBounds(
            start: DateTime(2024, 1, 1),
            end: DateTime(2026, 1, 1),
          ),
        ),
        2,
      );
      expect(
        countBudgetPeriodsInRange(
          budgetPeriod: AutoBudgetPeriod.daily,
          viewingRange: const DateRangeBounds(),
        ),
        1,
      );
      expect(
        countBudgetPeriodsInRange(
          budgetPeriod: AutoBudgetPeriod.daily,
          viewingRange: DateRangeBounds(
            start: DateTime(2026, 7, 2),
            end: DateTime(2026, 7, 1),
          ),
        ),
        1,
      );
    });

    test('aggregateBudgetLimit edge cases', () {
      expect(
        aggregateBudgetLimit(
          perPeriodAmount: 0,
          budgetPeriod: AutoBudgetPeriod.weekly,
          viewingRange: month,
        ),
        0,
      );
      expect(
        aggregateBudgetLimit(
          perPeriodAmount: 50,
          budgetPeriod: AutoBudgetPeriod.monthly,
          viewingRange: const DateRangeBounds(),
        ),
        50,
      );
    });
  });

  group('resolveBudgetPeriodMetrics', () {
    test('uses live spend in range and budget.spent for all-time', () {
      final budget = Budget(
        id: 'b1',
        name: 'Food',
        active: true,
        spent: 999,
        autoBudgetAmount: 100,
        autoBudgetPeriod: AutoBudgetPeriod.monthly,
        currencySymbol: '€',
        currencyCode: 'EUR',
      );
      final range = DateRangeBounds(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      );
      final metrics = resolveBudgetPeriodMetrics(
        budget: budget,
        viewingRange: range,
        transactions: [
          Transaction(
            id: '1',
            type: 'withdrawal',
            date: DateTime(2026, 7, 5),
            amount: 40,
            description: 'A',
            sourceName: 'Checking',
            destinationName: 'Store',
            categoryName: 'Food',
            currencySymbol: '€',
            currencyCode: 'EUR',
            budgetId: 'b1',
          ),
          Transaction(
            id: '2',
            type: 'withdrawal',
            date: DateTime(2026, 7, 6),
            amount: 10,
            description: 'B',
            sourceName: 'Checking',
            destinationName: 'Store',
            categoryName: 'Food',
            currencySymbol: '€',
            currencyCode: 'EUR',
            budgetId: 'other',
          ),
        ],
      );
      expect(metrics.spent, 40);
      expect(metrics.periodLimit, 100);
      expect(metrics.remaining, 60);
      expect(metrics.isOver, isFalse);
      expect(metrics.progress, 0.4);

      final allTime = resolveBudgetPeriodMetrics(
        budget: budget,
        viewingRange: const DateRangeBounds(),
        transactions: const [],
      );
      expect(allTime.spent, 999);

      final over = BudgetPeriodMetrics(spent: 120, periodLimit: 100);
      expect(over.isOver, isTrue);
      expect(BudgetPeriodMetrics(spent: 5, periodLimit: 0).progress, 0);
    });
  });
}
