import 'package:fireraccoon_engine/fireraccoon_engine.dart';

/// Pure helpers for building autocomplete suggestion lists from Firefly data.
abstract final class AutocompleteSuggestions {
  /// Filters [options] to entries containing [query], preserving order.
  ///
  /// Callers pass corpora that are already deduped and deliberately ordered
  /// (distinctNonEmpty or numeric suggestion helpers), so no per-keystroke
  /// dedupe/sort is performed here.
  static List<String> filterContains(String query, Iterable<String> options) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return List.of(options);
    return [
      for (final option in options)
        if (option.toLowerCase().contains(normalized)) option,
    ];
  }

  static List<String> distinctNonEmpty(Iterable<String?> values) {
    return values
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  static List<String> accountNames(List<Account> accounts) {
    return distinctNonEmpty(accounts.map((account) => account.name));
  }

  static List<String> budgetNames(List<Budget> budgets, {String? excludeName}) {
    final exclude = excludeName?.trim().toLowerCase();
    return distinctNonEmpty(budgets.map((budget) => budget.name))
        .where((name) => exclude == null || name.toLowerCase() != exclude)
        .toList();
  }

  static List<String> categoryNames(List<Category> categories) {
    return distinctNonEmpty(categories.map((category) => category.name));
  }

  static List<String> tagNames(List<Tag> tags) {
    return distinctNonEmpty(tags.map((tag) => tag.name));
  }

  static List<String> billNames(List<Bill> bills, {String? excludeName}) {
    final exclude = excludeName?.trim().toLowerCase();
    return distinctNonEmpty(bills.map((bill) => bill.name))
        .where((name) => exclude == null || name.toLowerCase() != exclude)
        .toList();
  }

  static List<String> piggyBankNames(
    List<PiggyBank> piggyBanks, {
    String? excludeName,
  }) {
    final exclude = excludeName?.trim().toLowerCase();
    return distinctNonEmpty(piggyBanks.map((piggy) => piggy.name))
        .where((name) => exclude == null || name.toLowerCase() != exclude)
        .toList();
  }

  static List<String> recurrenceTitles(
    List<Recurrence> recurrences, {
    String? excludeTitle,
  }) {
    final exclude = excludeTitle?.trim().toLowerCase();
    return distinctNonEmpty(recurrences.map((recurrence) => recurrence.title))
        .where((title) => exclude == null || title.toLowerCase() != exclude)
        .toList();
  }

  static List<String> transactionDescriptions(List<Transaction> transactions) {
    return distinctNonEmpty(
      transactions.map((transaction) => transaction.description),
    );
  }

  static List<String> transactionNotes(List<Transaction> transactions) {
    return distinctNonEmpty(
      transactions.map((transaction) => transaction.notes),
    );
  }

  static List<String> groupTitles({
    List<Transaction> transactions = const [],
    List<Bill> bills = const [],
    List<PiggyBank> piggyBanks = const [],
  }) {
    return distinctNonEmpty([
      ...transactions.map((transaction) => transaction.groupTitle),
      ...bills.map((bill) => bill.objectGroupTitle),
      ...piggyBanks.map((piggy) => piggy.objectGroupTitle),
    ]);
  }

  static List<String> notes({
    List<Transaction> transactions = const [],
    List<Bill> bills = const [],
    List<PiggyBank> piggyBanks = const [],
    List<Recurrence> recurrences = const [],
  }) {
    return distinctNonEmpty([
      ...transactionNotes(transactions),
      ...bills.map((bill) => bill.notes),
      ...piggyBanks.map((piggy) => piggy.notes),
      ...recurrences.map((recurrence) => recurrence.notes),
      ...recurrences.map((recurrence) => recurrence.description),
    ]);
  }

  static List<String> tagSuggestions(
    String rawValue,
    List<String> availableTags,
  ) {
    final parts = rawValue.split(',');
    final currentPart = parts.last.trim().toLowerCase();
    final selectedTags = parts
        .take(parts.length - 1)
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet();

    final base =
        availableTags
            .where((tag) => !selectedTags.contains(tag.toLowerCase()))
            .toList()
          ..sort();

    if (currentPart.isEmpty) return base;
    return base
        .where((tag) => tag.toLowerCase().contains(currentPart))
        .toList();
  }

  static String applyTagSuggestion({
    required String currentValue,
    required String selectedTag,
  }) {
    final parts = currentValue.split(',');
    final prefix = parts
        .take(parts.length - 1)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    final merged = [...prefix, selectedTag];
    return '${merged.join(', ')}, ';
  }

  static List<String> liabilityIbans(List<Account> accounts) {
    return distinctNonEmpty(
      accounts
          .where((account) => account.isLiability)
          .map((account) => account.iban),
    );
  }

  static List<String> liabilityBics(List<Account> accounts) {
    return distinctNonEmpty(
      accounts
          .where((account) => account.isLiability)
          .map((account) => account.bic),
    );
  }

  static List<String> liabilityAccountNumbers(List<Account> accounts) {
    return distinctNonEmpty(
      accounts
          .where((account) => account.isLiability)
          .map((account) => account.accountNumber),
    );
  }

  static List<String> decimalAmounts(Iterable<double> values) {
    return values
        .where((value) => value > 0)
        .map((value) => value.toStringAsFixed(2))
        .toSet()
        .toList()
      ..sort((a, b) => double.parse(a).compareTo(double.parse(b)));
  }

  static List<String> integerValues(Iterable<int> values) {
    return values.map((value) => value.toString()).toSet().toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  }

  static List<String> transactionAmounts(List<Transaction> transactions) {
    return decimalAmounts(
      transactions.map((transaction) => transaction.amount),
    );
  }

  static List<String> budgetAmounts(List<Budget> budgets) {
    return decimalAmounts(budgets.map((budget) => budget.autoBudgetAmount));
  }

  static List<String> billAmounts(List<Bill> bills) {
    return decimalAmounts([
      ...bills.map((bill) => bill.amountMin),
      ...bills.map((bill) => bill.amountMax),
    ]);
  }

  static List<String> piggyBankTargetAmounts(List<PiggyBank> piggyBanks) {
    return decimalAmounts(
      piggyBanks.map((piggyBank) => piggyBank.targetAmount),
    );
  }

  static List<String> billSkipValues(List<Bill> bills) {
    return integerValues(bills.map((bill) => bill.skip));
  }

  static List<String> recurrenceSkipValues(List<Recurrence> recurrences) {
    return integerValues(
      recurrences
          .map((recurrence) => recurrence.primaryRepetition?.skip)
          .whereType<int>(),
    );
  }

  static List<String> recurrenceRepetitionCounts(List<Recurrence> recurrences) {
    return integerValues(
      recurrences
          .map((recurrence) => recurrence.nrOfRepetitions)
          .whereType<int>(),
    );
  }

  static List<String> combinedDecimalSuggestions({
    List<Transaction> transactions = const [],
    List<Budget> budgets = const [],
    List<Bill> bills = const [],
    List<PiggyBank> piggyBanks = const [],
    List<Account> accounts = const [],
  }) {
    return decimalAmounts([
      ...transactions.map((transaction) => transaction.amount),
      ...transactions
          .map((transaction) => transaction.foreignAmount)
          .whereType<double>(),
      ...budgets.map((budget) => budget.autoBudgetAmount),
      ...bills.map((bill) => bill.amountMin),
      ...bills.map((bill) => bill.amountMax),
      ...piggyBanks.map((piggyBank) => piggyBank.targetAmount),
      ...accounts
          .where((account) => account.isLiability)
          .map((account) => account.currentBalance.abs()),
    ]);
  }

  static List<String> combinedIntegerSuggestions({
    List<Bill> bills = const [],
    List<Recurrence> recurrences = const [],
  }) {
    return integerValues([
      ...bills.map((bill) => bill.skip),
      ...recurrences
          .map((recurrence) => recurrence.primaryRepetition?.skip)
          .whereType<int>(),
      ...recurrences
          .map((recurrence) => recurrence.nrOfRepetitions)
          .whereType<int>(),
    ]);
  }

  static List<String> serverUrls(String currentUrl) {
    return distinctNonEmpty([
      currentUrl,
      'http://localhost:8080',
      'http://localhost:8081',
      'https://demo.firefly-iii.org',
    ]);
  }

  static List<String> contextualSearchTerms({
    required String location,
    List<Account> accounts = const [],
    List<Transaction> transactions = const [],
    List<Budget> budgets = const [],
    List<Category> categories = const [],
    List<Tag> tags = const [],
    List<Bill> bills = const [],
    List<PiggyBank> piggyBanks = const [],
    List<Recurrence> recurrences = const [],
  }) {
    if (location.startsWith('/accounts') ||
        location.startsWith('/liabilities')) {
      return distinctNonEmpty([
        ...accountNames(accounts),
        ...accounts.map((a) => a.type),
        ...accounts.map((a) => a.role),
        ...accounts.map((a) => a.currencyCode),
        ...liabilityIbans(accounts),
        ...liabilityBics(accounts),
        ...liabilityAccountNumbers(accounts),
      ]);
    }
    if (location.startsWith('/transactions') ||
        location.startsWith('/expenses') ||
        location.startsWith('/income') ||
        location.startsWith('/transfers')) {
      return distinctNonEmpty([
        ...transactionDescriptions(transactions),
        ...transactions.map((t) => t.sourceName),
        ...transactions.map((t) => t.destinationName),
        ...transactions.map((t) => t.categoryName),
        ...transactions.map((t) => t.type),
        ...transactions.map((t) => t.tags).expand((tags) => tags),
        ...categoryNames(categories),
        ...tagNames(tags),
        ...accountNames(accounts),
      ]);
    }
    if (location.startsWith('/budgets')) {
      return distinctNonEmpty([
        ...budgetNames(budgets),
        ...categoryNames(categories),
      ]);
    }
    if (location.startsWith('/subscriptions')) {
      return distinctNonEmpty([
        ...billNames(bills),
        ...categoryNames(categories),
      ]);
    }
    if (location.startsWith('/piggy-banks')) {
      return distinctNonEmpty([
        ...piggyBankNames(piggyBanks),
        ...groupTitles(piggyBanks: piggyBanks),
      ]);
    }

    return globalSearchTerms(
      accounts: accounts,
      transactions: transactions,
      budgets: budgets,
      categories: categories,
      tags: tags,
      bills: bills,
      piggyBanks: piggyBanks,
      recurrences: recurrences,
    );
  }

  static List<String> globalSearchTerms({
    List<Account> accounts = const [],
    List<Transaction> transactions = const [],
    List<Budget> budgets = const [],
    List<Category> categories = const [],
    List<Tag> tags = const [],
    List<Bill> bills = const [],
    List<PiggyBank> piggyBanks = const [],
    List<Recurrence> recurrences = const [],
  }) {
    return distinctNonEmpty([
      ...accountNames(accounts),
      ...accounts.map((account) => account.type),
      ...accounts.map((account) => account.role),
      ...accounts.map((account) => account.currencyCode),
      ...transactionDescriptions(transactions),
      ...transactions.map((transaction) => transaction.sourceName),
      ...transactions.map((transaction) => transaction.destinationName),
      ...transactions.map((transaction) => transaction.categoryName),
      ...transactions.map((transaction) => transaction.type),
      ...transactions
          .map((transaction) => transaction.tags)
          .expand((tags) => tags),
      ...budgetNames(budgets),
      ...categoryNames(categories),
      ...tagNames(tags),
      ...billNames(bills),
      ...piggyBankNames(piggyBanks),
      ...recurrenceTitles(recurrences),
      ...groupTitles(
        transactions: transactions,
        bills: bills,
        piggyBanks: piggyBanks,
      ),
    ]);
  }
}
