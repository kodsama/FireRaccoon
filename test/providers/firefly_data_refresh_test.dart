import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon/providers/firefly_data_refresh.dart';
import 'package:fireracoon/providers/paginated_transactions_provider.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/static_auth_notifier.dart';
import '../helpers/test_data.dart';

class _CountingFireflyService extends FakeFireflyService {
  _CountingFireflyService({
    required super.accounts,
    required super.transactions,
  });

  int accountReads = 0;
  int transactionReads = 0;

  @override
  Future<List<Account>> getAccounts({
    List<String> types = const ['asset', 'liability'],
  }) async {
    accountReads++;
    return super.getAccounts(types: types);
  }

  @override
  Future<List<Transaction>> getTransactions({
    DateTime? start,
    DateTime? end,
    String? type,
    void Function(List<Transaction> firstPage)? onFirstPage,
  }) async {
    transactionReads++;
    return super.getTransactions(
      start: start,
      end: end,
      type: type,
      onFirstPage: onFirstPage,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('refreshFireflyData re-fetches accounts and transactions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'transactionPageSize': 50});
    final prefs = await SharedPreferences.getInstance();
    final liveAccounts = List<Account>.from(sampleAccounts);
    final liveTransactions = List<Transaction>.from(sampleTransactions);
    final fake = _CountingFireflyService(
      accounts: liveAccounts,
      transactions: liveTransactions,
    );
    late WidgetRef ref;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(
            () => StaticAuthNotifier(
              AuthSettings(
                serverUrl: 'https://firefly.test',
                apiToken: 'token',
              ),
            ),
          ),
          apiServiceProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, widgetRef, _) {
              ref = widgetRef;
              widgetRef.watch(accountsProvider);
              widgetRef.watch(transactionsProvider);
              widgetRef.watch(paginatedTransactionsProvider(null));
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await ref.read(accountsProvider.future);
    await ref.read(transactionsProvider.future);

    final accountsAfterWarm = fake.accountReads;
    final transactionsAfterWarm = fake.transactionReads;
    expect(ref.read(accountsProvider).value, hasLength(sampleAccounts.length));

    liveAccounts
      ..clear()
      ..add(
        sampleAccounts.first.copyWith(
          name: 'Refreshed Checking',
          currentBalance: 42,
        ),
      );
    liveTransactions
      ..clear()
      ..add(
        sampleTransactions.first.copyWith(description: 'Edited in Firefly'),
      );

    await refreshFireflyData(ref);
    await tester.pumpAndSettle();

    expect(fake.accountReads, greaterThan(accountsAfterWarm));
    expect(fake.transactionReads, greaterThan(transactionsAfterWarm));
    expect(ref.read(accountsProvider).value!.single.name, 'Refreshed Checking');
    expect(
      ref.read(transactionsProvider).value!.single.description,
      'Edited in Firefly',
    );
  });

  testWidgets('refreshFireflyData awaits the focused account list', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'transactionPageSize': 50});
    final prefs = await SharedPreferences.getInstance();
    final checking = sampleAccounts.first;
    final fake = FakeFireflyService(
      accounts: sampleAccounts,
      transactions: sampleTransactions,
      transactionPages: {
        1: TransactionPageResult(
          transactions: sampleTransactions,
          currentPage: 1,
          totalPages: 1,
          total: sampleTransactions.length,
        ),
      },
      accountTransactionPages: {
        checking.id: {
          1: TransactionPageResult(
            transactions: sampleTransactions,
            currentPage: 1,
            totalPages: 1,
            total: sampleTransactions.length,
          ),
        },
      },
    );
    late WidgetRef ref;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(
            () => StaticAuthNotifier(
              AuthSettings(
                serverUrl: 'https://firefly.test',
                apiToken: 'token',
              ),
            ),
          ),
          apiServiceProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, widgetRef, _) {
              ref = widgetRef;
              widgetRef.watch(paginatedTransactionsProvider(checking.name));
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await refreshFireflyData(ref, focusAccount: checking.name);
    await tester.pumpAndSettle();

    expect(
      ref.read(paginatedTransactionsProvider(checking.name)).error,
      isNull,
    );
    expect(
      ref.read(paginatedTransactionsProvider(checking.name)).transactions,
      isNotEmpty,
    );
  });
}
