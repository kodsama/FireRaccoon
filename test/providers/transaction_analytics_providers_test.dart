import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon/providers/transaction_analytics_providers.dart';
import 'package:fireracoon/router/transaction_analytics_route.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/test_data.dart';

void main() {
  test('analyticsKey preserves expense route filters', () {
    final filters = ExpenseRouteFilters(
      period: ExpensePeriod.year,
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 12, 31),
      type: TransactionTypeFilter.expense,
      account: 'Checking',
    );

    expect(filters.analyticsKey, (
      period: ExpensePeriod.year,
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 12, 31),
      type: TransactionTypeFilter.expense,
      account: 'Checking',
    ));
  });

  test('summary exposes sorted category names and period total', () {
    final summary = TransactionAnalyticsSummary(
      dateRange: resolveExpenseDateRange(period: ExpensePeriod.all),
      periodTransactions: sampleTransactions,
      categorySums: const {'Travel': 20, 'Food': 45},
    );

    expect(summary.categoryNames, ['Food', 'Travel']);
    expect(summary.sortedCategoryEntries.first.key, 'Food');
    expect(summary.periodTotal, 1245);
  });

  test('filtered list scopes transactions by category', () async {
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(
          FakeFireflyService(transactions: sampleTransactions),
        ),
      ],
    );
    addTearDown(container.dispose);
    final all = await container.read(
      filteredTransactionListProvider((
        period: ExpensePeriod.all,
        from: null,
        to: null,
        type: TransactionTypeFilter.all,
        account: null,
        category: null,
      )).future,
    );
    final food = await container.read(
      filteredTransactionListProvider((
        period: ExpensePeriod.all,
        from: null,
        to: null,
        type: TransactionTypeFilter.all,
        account: null,
        category: 'Food',
      )).future,
    );

    expect(all, isNotEmpty);
    expect(
      food.every((transaction) => transaction.categoryName == 'Food'),
      isTrue,
    );
  });
}
