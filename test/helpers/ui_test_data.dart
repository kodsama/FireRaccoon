import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import 'mock_firefly_service.dart';
import 'test_data.dart';

final checkingAccount = Account(
  id: '1',
  name: 'Checking',
  type: 'asset',
  role: 'defaultAsset',
  currentBalance: 2500,
  currencySymbol: '€',
  currencyCode: 'EUR',
);

final storePayee = Account(
  id: '2',
  name: 'Store',
  type: 'expense',
  role: 'defaultAsset',
  currentBalance: 0,
  currencySymbol: '€',
  currencyCode: 'EUR',
);

final dialogAccounts = [checkingAccount, storePayee];

const dialogCategories = [
  Category(id: 'cat-1', name: 'Food'),
  Category(id: 'cat-2', name: 'Housing'),
];

const dialogTags = [
  Tag(id: 'tag-1', name: 'groceries'),
  Tag(id: 'tag-2', name: 'essential'),
];

final samplePiggyBank = PiggyBank(
  id: 'piggy-1',
  name: 'Vacation Fund',
  targetAmount: 5000,
  currentAmount: 1200,
  currencyCode: 'EUR',
  currencySymbol: '€',
  startDate: DateTime(2026, 1, 1),
  targetDate: DateTime(2026, 12, 31),
  accounts: [
    PiggyBankAccountLink(accountId: '1', name: 'Checking', currentAmount: 1200),
  ],
);

final sampleRecurrence = Recurrence(
  id: 'rec-1',
  type: RecurrenceTransactionType.withdrawal,
  title: 'Weekly groceries',
  firstDate: DateTime(2026, 8, 1),
  repetitions: const [
    RecurrenceRepetition(
      type: RecurrenceRepetitionType.weekly,
      moment: '1',
      skip: 0,
      weekend: RecurrenceWeekendMode.createAnyway,
    ),
  ],
  transactions: const [
    RecurrenceTransactionLine(
      id: 'tx-line-1',
      description: 'Groceries run',
      amount: 45,
      currencyCode: 'EUR',
      sourceId: '1',
      sourceName: 'Checking',
      destinationId: '2',
      destinationName: 'Store',
    ),
  ],
);

FakeFireflyService buildDialogFireflyService({
  List<Account>? accounts,
  List<Transaction>? transactions,
  List<Recurrence>? recurrences,
  List<PiggyBank>? piggyBanks,
}) {
  return FakeFireflyService(
    accounts: accounts ?? dialogAccounts,
    transactions: transactions ?? sampleTransactions,
    budgets: sampleBudgets,
    bills: sampleBills,
    recurrences: recurrences ?? const [],
    piggyBanks: piggyBanks ?? const [],
    categories: dialogCategories,
    tags: dialogTags,
    currencies: const [sampleCurrency],
    primaryCurrency: sampleCurrency,
    currentUser: sampleUser,
  );
}
