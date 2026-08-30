import 'package:fireraccoon/utils/autocomplete_suggestions.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutocompleteSuggestions', () {
    test('filterContains is case-insensitive', () {
      expect(
        AutocompleteSuggestions.filterContains('gro', ['Groceries', 'Rent']),
        ['Groceries'],
      );
    });

    test('filterContains returns all options in caller order when query is '
        'empty', () {
      // Corpora are pre-deduped and deliberately ordered by their builders
      // (e.g. numeric amount suggestions); filterContains preserves that.
      expect(AutocompleteSuggestions.filterContains('', ['B', 'A']), [
        'B',
        'A',
      ]);
    });

    test('tagSuggestions ignores already selected tags', () {
      expect(
        AutocompleteSuggestions.tagSuggestions('food, tra', ['food', 'travel']),
        ['travel'],
      );
    });

    test('applyTagSuggestion appends selected tag with trailing comma', () {
      expect(
        AutocompleteSuggestions.applyTagSuggestion(
          currentValue: 'food, tra',
          selectedTag: 'travel',
        ),
        'food, travel, ',
      );
    });

    test('groupTitles merges titles from multiple sources', () {
      expect(
        AutocompleteSuggestions.groupTitles(
          transactions: const [],
          bills: const [],
          piggyBanks: const [],
        ),
        isEmpty,
      );
    });

    test('liabilityIbans reads banking fields from liability accounts', () {
      final accounts = [
        Account(
          id: '1',
          name: 'Loan',
          type: 'liability',
          role: 'defaultAsset',
          currentBalance: -1000,
          currencySymbol: '€',
          currencyCode: 'EUR',
          iban: 'GB82WEST12345698765432',
        ),
      ];

      expect(AutocompleteSuggestions.liabilityIbans(accounts), [
        'GB82WEST12345698765432',
      ]);
    });

    test('globalSearchTerms includes account and transaction fields', () {
      final terms = AutocompleteSuggestions.globalSearchTerms(
        accounts: [
          Account(
            id: '1',
            name: 'Checking',
            type: 'asset',
            role: 'defaultAsset',
            currentBalance: 100,
            currencySymbol: '€',
            currencyCode: 'EUR',
          ),
        ],
        transactions: [
          Transaction(
            id: '1',
            type: 'withdrawal',
            date: DateTime(2026, 1, 1),
            amount: 10,
            description: 'Coffee',
            sourceName: 'Checking',
            destinationName: 'Cafe',
            categoryName: 'Food',
            currencySymbol: '€',
            currencyCode: 'EUR',
          ),
        ],
      );

      expect(terms, containsAll(['Checking', 'Coffee', 'Food', 'Cafe']));
    });

    test('normalization helpers deduplicate, trim and sort', () {
      expect(
        AutocompleteSuggestions.distinctNonEmpty([' B ', null, '', 'A', 'B']),
        ['A', 'B'],
      );
      expect(
        AutocompleteSuggestions.accountNames([
          Account(
            id: '1',
            name: '  Savings ',
            type: 'asset',
            role: 'defaultAsset',
            currentBalance: 0,
            currencySymbol: '€',
            currencyCode: 'EUR',
          ),
        ]),
        ['Savings'],
      );
    });

    test('name filters exclude provided values case-insensitively', () {
      final budgets = [
        Budget(
          id: '1',
          name: 'Food',
          active: true,
          spent: 0,
          autoBudgetAmount: 100,
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
      ];
      final bills = [
        Bill(
          id: '1',
          name: 'Rent',
          amountMin: 100,
          amountMax: 100,
          amountAvg: 100,
          currencyCode: 'EUR',
          currencySymbol: '€',
          date: DateTime(2026, 1, 1),
          repeatFrequency: BillRepeatFrequency.monthly,
        ),
      ];
      final piggies = [
        PiggyBank(
          id: '1',
          name: 'Trip',
          targetAmount: 300,
          currentAmount: 10,
          currencyCode: 'EUR',
          currencySymbol: '€',
          startDate: DateTime(2026, 1, 1),
        ),
      ];
      final recurrences = [
        Recurrence(
          id: '1',
          type: RecurrenceTransactionType.withdrawal,
          title: 'Gym',
          firstDate: DateTime(2026, 1, 1),
        ),
      ];

      expect(
        AutocompleteSuggestions.budgetNames(budgets, excludeName: ' food '),
        isEmpty,
      );
      expect(
        AutocompleteSuggestions.billNames(bills, excludeName: 'RENT'),
        isEmpty,
      );
      expect(
        AutocompleteSuggestions.piggyBankNames(piggies, excludeName: 'trip'),
        isEmpty,
      );
      expect(
        AutocompleteSuggestions.recurrenceTitles(
          recurrences,
          excludeTitle: 'GYM',
        ),
        isEmpty,
      );
    });

    test('numeric suggestion helpers serialize and sort values', () {
      expect(AutocompleteSuggestions.decimalAmounts([10, 0, 2.5, 10]), [
        '2.50',
        '10.00',
      ]);
      expect(AutocompleteSuggestions.integerValues([3, 1, 3]), ['1', '3']);
      expect(
        AutocompleteSuggestions.serverUrls('https://self-hosted.example'),
        containsAll(['https://self-hosted.example', 'http://localhost:8080']),
      );
    });

    test('contextual search selects the corpus for each route family', () {
      expect(
        AutocompleteSuggestions.contextualSearchTerms(
          location: '/transactions',
        ),
        isEmpty,
      );
      expect(
        AutocompleteSuggestions.contextualSearchTerms(location: '/budgets'),
        isEmpty,
      );
      expect(
        AutocompleteSuggestions.contextualSearchTerms(
          location: '/subscriptions',
        ),
        isEmpty,
      );
      expect(
        AutocompleteSuggestions.contextualSearchTerms(location: '/piggy-banks'),
        isEmpty,
      );
    });

    test('liability and amount helper suggestions aggregate values', () {
      final liability = Account(
        id: '2',
        name: 'Credit Card',
        type: 'liability',
        role: 'ccAsset',
        currentBalance: -1200.5,
        currencySymbol: '€',
        currencyCode: 'EUR',
        bic: 'ABCDEFGH',
        accountNumber: '123456',
      );
      final tx = Transaction(
        id: '1',
        type: 'withdrawal',
        date: DateTime(2026, 1, 1),
        amount: 42.5,
        description: 'Coffee',
        sourceName: 'Checking',
        destinationName: 'Cafe',
        categoryName: 'Food',
        currencySymbol: '€',
        currencyCode: 'EUR',
      );
      final budgets = [
        Budget(
          id: '1',
          name: 'Food',
          active: true,
          spent: 0,
          autoBudgetAmount: 300,
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
      ];
      final bills = [
        Bill(
          id: '1',
          name: 'Rent',
          amountMin: 900,
          amountMax: 950,
          amountAvg: 925,
          currencyCode: 'EUR',
          currencySymbol: '€',
          date: DateTime(2026, 1, 1),
          repeatFrequency: BillRepeatFrequency.monthly,
          skip: 2,
        ),
      ];
      final piggies = [
        PiggyBank(
          id: '1',
          name: 'Trip',
          targetAmount: 1500,
          currentAmount: 50,
          currencyCode: 'EUR',
          currencySymbol: '€',
          startDate: DateTime(2026, 1, 1),
        ),
      ];
      final recurrences = [
        Recurrence(
          id: '1',
          type: RecurrenceTransactionType.withdrawal,
          title: 'Gym',
          firstDate: DateTime(2026, 1, 1),
          nrOfRepetitions: 6,
          repetitions: const [
            RecurrenceRepetition(
              type: RecurrenceRepetitionType.monthly,
              moment: '1',
              skip: 1,
            ),
          ],
        ),
      ];

      expect(AutocompleteSuggestions.liabilityBics([liability]), ['ABCDEFGH']);
      expect(AutocompleteSuggestions.liabilityAccountNumbers([liability]), [
        '123456',
      ]);
      expect(AutocompleteSuggestions.transactionAmounts([tx]), ['42.50']);
      expect(AutocompleteSuggestions.budgetAmounts(budgets), ['300.00']);
      expect(AutocompleteSuggestions.billAmounts(bills), ['900.00', '950.00']);
      expect(AutocompleteSuggestions.piggyBankTargetAmounts(piggies), [
        '1500.00',
      ]);
      expect(AutocompleteSuggestions.billSkipValues(bills), ['2']);
      expect(AutocompleteSuggestions.recurrenceSkipValues(recurrences), ['1']);
      expect(AutocompleteSuggestions.recurrenceRepetitionCounts(recurrences), [
        '6',
      ]);

      final combinedDecimals =
          AutocompleteSuggestions.combinedDecimalSuggestions(
            transactions: [
              tx.copyWith(foreignAmount: 10, foreignCurrencyCode: 'USD'),
            ],
            budgets: budgets,
            bills: bills,
            piggyBanks: piggies,
            accounts: [liability],
          );
      expect(
        combinedDecimals,
        containsAll([
          '10.00',
          '42.50',
          '300.00',
          '900.00',
          '950.00',
          '1200.50',
          '1500.00',
        ]),
      );

      final combinedIntegers =
          AutocompleteSuggestions.combinedIntegerSuggestions(
            bills: bills,
            recurrences: recurrences,
          );
      expect(combinedIntegers, ['1', '2', '6']);
    });
  });
}
