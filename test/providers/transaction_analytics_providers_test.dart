import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/providers/transaction_analytics_providers.dart';
import 'package:fireraccoon/router/stats_route.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/test_data.dart';

void main() {
  test('the scope compares types as a set and ignores narrowing filters', () {
    const a = StatsRouteFilters(
      types: {TransactionTypeFilter.income, TransactionTypeFilter.expense},
      tag: 'Holiday',
    );
    const b = StatsRouteFilters(
      types: {TransactionTypeFilter.expense, TransactionTypeFilter.income},
      budget: 'Fun',
    );
    const other = StatsRouteFilters(types: {TransactionTypeFilter.expense});

    expect(a.scope, b.scope);
    expect(a.scope.hashCode, b.scope.hashCode);
    expect(a.scope, isNot(other.scope));
    expect(
      a.scope.keyFor(TransactionTypeFilter.income).type,
      TransactionTypeFilter.income,
    );
  });

  test('stats transactions merge the selected types, newest first', () async {
    Transaction row(String id, String type, DateTime date) => Transaction(
      id: id,
      type: type,
      date: date,
      amount: 10,
      description: id,
      sourceName: 'Checking',
      destinationName: 'Shop',
      categoryName: 'Food',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(
          FakeFireflyService(
            transactions: [
              row('spent', 'withdrawal', DateTime(2026, 7, 2)),
              row('paid', 'deposit', DateTime(2026, 7, 5)),
              row('moved', 'transfer', DateTime(2026, 7, 4)),
              row('june', 'withdrawal', DateTime(2026, 6, 30)),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final rows = await container.read(
      statsTransactionsProvider(
        StatsScope(
          period: ExpensePeriod.month,
          from: DateTime(2026, 7, 1),
          to: DateTime(2026, 7, 31),
          types: {TransactionTypeFilter.expense, TransactionTypeFilter.income},
          account: null,
        ),
      ).future,
    );

    expect(rows.map((t) => t.id), ['paid', 'spent']);
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
        tag: null,
        budget: null,
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
        tag: null,
        budget: null,
      )).future,
    );

    expect(all, isNotEmpty);
    expect(
      food.every((transaction) => transaction.categoryName == 'Food'),
      isTrue,
    );
  });

  test('filtered list scopes transactions by tag and budget', () async {
    final base = sampleTransactions.last;
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(
          FakeFireflyService(
            transactions: [
              base.copyWith(id: 'tagged', tags: ['Holiday']),
              base.copyWith(id: 'budgeted', budgetName: 'Fun'),
              base.copyWith(id: 'plain'),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    Future<List<String>> ids({String? tag, String? budget}) async =>
        (await container.read(
          filteredTransactionListProvider((
            period: ExpensePeriod.all,
            from: null,
            to: null,
            type: TransactionTypeFilter.all,
            account: null,
            category: null,
            tag: tag,
            budget: budget,
          )).future,
        )).map((t) => t.id).toList();

    expect(await ids(tag: 'Holiday'), ['tagged']);
    expect(await ids(budget: 'Fun'), ['budgeted']);
  });
}
