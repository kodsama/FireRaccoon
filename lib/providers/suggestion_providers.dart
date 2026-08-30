import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../utils/autocomplete_suggestions.dart';
import 'data_providers.dart';

/// Memoized suggestion corpora derived from the cached entity lists.
///
/// These are Providers (not computed in widget builds) so the O(n log n)
/// dedupe/sort over the transaction list runs only when a source list
/// actually changes, not on every rebuild of the shell or an edit panel.

final globalSearchTermsProvider = Provider<List<String>>((ref) {
  return AutocompleteSuggestions.globalSearchTerms(
    accounts: ref.watch(accountsProvider).value ?? const [],
    transactions: ref.watch(transactionsProvider).value ?? const [],
    budgets: ref.watch(budgetsProvider).value ?? const [],
    categories: ref.watch(categoriesProvider).value ?? const [],
    tags: ref.watch(tagsProvider).value ?? const [],
    bills: ref.watch(billsProvider).value ?? const [],
    piggyBanks: ref.watch(piggyBanksProvider).value ?? const [],
    recurrences: ref.watch(recurrencesProvider).value ?? const [],
  );
});

final contextualSearchTermsProvider = Provider.family<List<String>, String>((
  ref,
  location,
) {
  return AutocompleteSuggestions.contextualSearchTerms(
    location: location,
    accounts: ref.watch(accountsProvider).value ?? const [],
    transactions: ref.watch(transactionsProvider).value ?? const [],
    budgets: ref.watch(budgetsProvider).value ?? const [],
    categories: ref.watch(categoriesProvider).value ?? const [],
    tags: ref.watch(tagsProvider).value ?? const [],
    bills: ref.watch(billsProvider).value ?? const [],
    piggyBanks: ref.watch(piggyBanksProvider).value ?? const [],
    recurrences: ref.watch(recurrencesProvider).value ?? const [],
  );
});

final transactionDescriptionSuggestionsProvider = Provider<List<String>>((ref) {
  return AutocompleteSuggestions.transactionDescriptions(
    ref.watch(transactionsProvider).value ?? const <Transaction>[],
  );
});

final notesSuggestionsProvider = Provider<List<String>>((ref) {
  return AutocompleteSuggestions.notes(
    transactions: ref.watch(transactionsProvider).value ?? const [],
    bills: ref.watch(billsProvider).value ?? const [],
    piggyBanks: ref.watch(piggyBanksProvider).value ?? const [],
  );
});

final groupTitleSuggestionsProvider = Provider<List<String>>((ref) {
  return AutocompleteSuggestions.groupTitles(
    transactions: ref.watch(transactionsProvider).value ?? const [],
    bills: ref.watch(billsProvider).value ?? const [],
    piggyBanks: ref.watch(piggyBanksProvider).value ?? const [],
  );
});

final decimalSuggestionsProvider = Provider<List<String>>((ref) {
  return AutocompleteSuggestions.combinedDecimalSuggestions(
    transactions: ref.watch(transactionsProvider).value ?? const [],
    budgets: ref.watch(budgetsProvider).value ?? const [],
    bills: ref.watch(billsProvider).value ?? const [],
    piggyBanks: ref.watch(piggyBanksProvider).value ?? const [],
    accounts: ref.watch(accountsProvider).value ?? const [],
  );
});
