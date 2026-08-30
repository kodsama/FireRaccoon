import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/providers/suggestion_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixed_accounts_notifier.dart';
import '../helpers/fixed_transactions_notifier.dart';
import '../helpers/test_data.dart';
import '../helpers/ui_test_data.dart';

void main() {
  test('suggestion providers derive corpora from cached entities', () async {
    final container = ProviderContainer(
      overrides: [
        accountsProvider.overrideWith(
          () => FixedAccountsNotifier(sampleAccounts),
        ),
        transactionsProvider.overrideWith(
          () => FixedTransactionsNotifier(sampleTransactions),
        ),
        budgetsProvider.overrideWith((ref) async => sampleBudgets),
        categoriesProvider.overrideWith((ref) async => dialogCategories),
        tagsProvider.overrideWith((ref) async => dialogTags),
        billsProvider.overrideWith((ref) async => sampleBills),
        piggyBanksProvider.overrideWith((ref) async => [samplePiggyBank]),
        recurrencesProvider.overrideWith((ref) async => [sampleRecurrence]),
      ],
    );
    addTearDown(container.dispose);
    await Future.wait([
      container.read(accountsProvider.future),
      container.read(transactionsProvider.future),
      container.read(budgetsProvider.future),
      container.read(categoriesProvider.future),
      container.read(tagsProvider.future),
      container.read(billsProvider.future),
      container.read(piggyBanksProvider.future),
      container.read(recurrencesProvider.future),
    ]);

    expect(container.read(globalSearchTermsProvider), isNotEmpty);
    expect(
      container.read(contextualSearchTermsProvider('/transactions')),
      isNotEmpty,
    );
    expect(
      container.read(transactionDescriptionSuggestionsProvider),
      isNotEmpty,
    );
    expect(container.read(notesSuggestionsProvider), isA<List<String>>());
    expect(container.read(groupTitleSuggestionsProvider), isA<List<String>>());
    expect(container.read(decimalSuggestionsProvider), isNotEmpty);
  });
}
