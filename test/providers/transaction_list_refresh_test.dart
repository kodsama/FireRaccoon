import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon/providers/paginated_transactions_provider.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon/providers/transaction_list_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fixed_accounts_notifier.dart';
import '../helpers/fixed_transactions_notifier.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/static_auth_notifier.dart';
import '../helpers/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('refresh patches removals and refreshes live filtered lists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'transactionPageSize': 50});
    final prefs = await SharedPreferences.getInstance();
    final fake = FakeFireflyService(
      accounts: sampleAccounts,
      transactions: sampleTransactions,
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
          accountsProvider.overrideWith(
            () => FixedAccountsNotifier(sampleAccounts),
          ),
          transactionsProvider.overrideWith(
            () => FixedTransactionsNotifier(sampleTransactions),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, widgetRef, _) {
              ref = widgetRef;
              widgetRef.watch(paginatedTransactionsProvider(null));
              widgetRef.watch(paginatedTransactionsProvider('Checking'));
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await ref.read(accountsProvider.future);
    await ref.read(transactionsProvider.future);

    await refreshTransactionLists(
      ref,
      'Checking',
      remove: sampleTransactions.first,
    );

    expect(
      ref
          .read(transactionsProvider)
          .value!
          .map((transaction) => transaction.id),
      isNot(contains(sampleTransactions.first.id)),
    );

    await refreshTransactionLists(ref, 'Checking');
    expect(ref.read(paginatedTransactionsProvider('Checking')).error, isNull);
  });
}
