import 'package:fireracoon/providers/budget_period_providers.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
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
}
