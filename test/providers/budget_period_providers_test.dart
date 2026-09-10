import 'package:fireraccoon/providers/budget_period_providers.dart';
import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/test_data.dart';

void main() {
  test('budgetFiltersFromKey maps every tuple field', () {
    final from = DateTime(2026, 7, 1);
    final to = DateTime(2026, 7, 31);

    final filters = budgetFiltersFromKey((ExpensePeriod.month, from, to));

    expect(filters.period, ExpensePeriod.month);
    expect(filters.from, from);
    expect(filters.to, to);
  });

  test(
    'metrics use cached budgets when no explicit range is selected',
    () async {
      final service = FakeFireflyService(budgets: sampleBudgets);
      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(service),
          budgetsProvider.overrideWith((ref) async => sampleBudgets),
        ],
      );
      addTearDown(container.dispose);

      final metrics = await container.read(
        budgetPeriodMetricsProvider((ExpensePeriod.all, null, null)).future,
      );

      expect(metrics['1']?.spent, 120);
      expect(metrics['1']?.periodLimit, isNotNull);
    },
  );

  test('metrics fetch bounded budgets for an explicit range', () async {
    final service = FakeFireflyService(budgets: sampleBudgets);
    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final metrics = await container.read(
      budgetPeriodMetricsProvider((
        ExpensePeriod.month,
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 31),
      )).future,
    );

    expect(metrics['1']?.spent, 120);
  });

  test('a yearly budget viewed over a month reports its year', () async {
    // Firefly scopes spent to the window it is given, so asking about
    // September for a budget kept by the year answered with September: a
    // budget of 220,000 a year read as nothing spent of nothing to spend.
    final service = _WindowedBudgets(
      yearly: Budget(
        id: 'h',
        name: 'Holidays',
        active: true,
        spent: 0,
        autoBudgetAmount: 220000,
        autoBudgetType: AutoBudgetType.reset,
        autoBudgetPeriod: AutoBudgetPeriod.yearly,
      ),
      spentInTheYear: 180000,
    );
    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final metrics = await container.read(
      budgetPeriodMetricsProvider((
        ExpensePeriod.month,
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
      )).future,
    );

    expect(metrics['h']?.spent, 180000);
    // One whole period, so the limit is the budget's own amount rather than a
    // twelfth of it or twelve times it.
    expect(metrics['h']?.periodLimit, 220000);

    // Asked twice: the viewed window, then the budget's own year.
    expect(service.windows, hasLength(2));
    expect(service.windows.last, (DateTime(2026, 1, 1), DateTime(2027, 1, 1)));
  });

  test('a monthly budget is not asked about twice', () async {
    final service = _WindowedBudgets(
      yearly: Budget(
        id: 'f',
        name: 'Food',
        active: true,
        spent: 199,
        autoBudgetAmount: 5000,
        autoBudgetType: AutoBudgetType.reset,
        autoBudgetPeriod: AutoBudgetPeriod.monthly,
      ),
      spentInTheYear: 60000,
    );
    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final metrics = await container.read(
      budgetPeriodMetricsProvider((
        ExpensePeriod.month,
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
      )).future,
    );

    expect(metrics['f']?.spent, 199);
    expect(service.windows, hasLength(1));
  });
}

/// Answers a different figure for the wider window, and records what it was
/// asked for, which is the whole point of the widening.
class _WindowedBudgets extends FakeFireflyService {
  _WindowedBudgets({required this.yearly, required this.spentInTheYear})
    : super(budgets: [yearly]);

  final Budget yearly;
  final double spentInTheYear;
  final windows = <(DateTime?, DateTime?)>[];

  @override
  Future<List<Budget>> getBudgets({DateTime? start, DateTime? end}) async {
    windows.add((start, end));
    final wholeYear =
        start == DateTime(2026, 1, 1) && end == DateTime(2027, 1, 1);
    return [
      if (wholeYear)
        Budget(
          id: yearly.id,
          name: yearly.name,
          active: yearly.active,
          spent: spentInTheYear,
          autoBudgetAmount: yearly.autoBudgetAmount,
          autoBudgetType: yearly.autoBudgetType,
          autoBudgetPeriod: yearly.autoBudgetPeriod,
        )
      else
        yearly,
    ];
  }
}
