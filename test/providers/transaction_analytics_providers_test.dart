import 'package:fireraccoon/models/people_models.dart';
import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/providers/people_providers.dart';
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
      tags: {'Holiday'},
      accounts: {'Checking'},
    );
    const b = StatsRouteFilters(
      types: {TransactionTypeFilter.expense, TransactionTypeFilter.income},
      budgets: {'Fun'},
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
        peopleSettingsProvider.overrideWithValue(
          const AccountOwnershipConfig(),
        ),
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
      filteredTransactionListProvider(
        TransactionListFilterKey(
          scope: (
            period: ExpensePeriod.all,
            from: null,
            to: null,
            type: TransactionTypeFilter.all,
            account: null,
          ),
        ),
      ).future,
    );
    final food = await container.read(
      filteredTransactionListProvider(
        TransactionListFilterKey(
          scope: (
            period: ExpensePeriod.all,
            from: null,
            to: null,
            type: TransactionTypeFilter.all,
            account: null,
          ),
          categories: {'Food'},
        ),
      ).future,
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
          filteredTransactionListProvider(
            TransactionListFilterKey(
              scope: (
                period: ExpensePeriod.all,
                from: null,
                to: null,
                type: TransactionTypeFilter.all,
                account: null,
              ),
              tags: {?tag},
              budgets: {?budget},
            ),
          ).future,
        )).map((t) => t.id).toList();

    expect(await ids(tag: 'Holiday'), ['tagged']);
    expect(await ids(budget: 'Fun'), ['budgeted']);
    // Sets compare by what they hold, so an equal key reuses the entry.
    expect(
      TransactionListFilterKey(
        scope: (
          period: ExpensePeriod.all,
          from: null,
          to: null,
          type: TransactionTypeFilter.all,
          account: null,
        ),
        tags: {'a', 'b'},
      ),
      TransactionListFilterKey(
        scope: (
          period: ExpensePeriod.all,
          from: null,
          to: null,
          type: TransactionTypeFilter.all,
          account: null,
        ),
        tags: {'b', 'a'},
      ),
    );
  });

  test('stats follow the selected person without fetching again', () async {
    Transaction row(String id, String accountId) => Transaction(
      id: id,
      type: 'withdrawal',
      date: DateTime(2026, 7, 2),
      amount: 10,
      description: id,
      sourceId: accountId,
      sourceName: accountId,
      // The shop's expense account has an id like any other, and no owners;
      // an account without owners counts for everyone, so it must not be
      // what places the row with a person.
      destinationId: 'shop',
      destinationName: 'Shop',
      categoryName: 'Food',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );
    Account card(String id) => Account(
      id: id,
      name: id,
      type: 'asset',
      role: 'defaultAsset',
      currentBalance: 0,
      currencySymbol: '€',
      currencyCode: 'EUR',
    );
    final fake = FakeFireflyService(
      accounts: [card('olivier-card'), card('alex-card')],
      transactions: [row('hers', 'olivier-card'), row('his', 'alex-card')],
    );
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(fake),
        peopleSettingsProvider.overrideWithValue(
          const AccountOwnershipConfig(
            accountOwnerships: {
              'olivier-card': AccountOwnership(
                accountId: 'olivier-card',
                personShares: {'olivier': 1},
              ),
              'alex-card': AccountOwnership(
                accountId: 'alex-card',
                personShares: {'alex': 1},
              ),
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final scope = StatsScope(
      period: ExpensePeriod.month,
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 7, 31),
      types: const {TransactionTypeFilter.expense},
    );
    final sub = container.listen(statsTransactionsProvider(scope), (_, _) {});
    addTearDown(sub.close);
    await container.read(accountsProvider.future);

    Future<List<String>> ids() async =>
        (await container.read(statsTransactionsProvider(scope).future))
            .map((t) => t.id)
            .toList();

    expect(await ids(), unorderedEquals(['hers', 'his']));
    container
        .read(activePersonFilterProvider.notifier)
        .setPersonFilter('olivier');
    expect(await ids(), ['hers']);
    container.read(activePersonFilterProvider.notifier).setPersonFilter('alex');
    expect(await ids(), ['his']);
    expect(fake.getTransactionsCalls, 1);
  });
}
