import 'package:fireraccoon_engine/fireraccoon_engine.dart';

// Keep sample activity inside the default "this month" window and on or before
// today so period-scoped screens and the transactions list (which splits out
// future rows) keep finding these fixtures. Distinct hours keep relative order
// when preferred days collapse to "today" early in the month.
DateTime sampleDayInCurrentMonth(int preferredDay, {int hour = 12}) {
  final now = DateTime.now();
  final day = preferredDay.clamp(1, now.day).toInt();
  return DateTime(now.year, now.month, day, hour);
}

final sampleTransactions = [
  Transaction(
    id: '1',
    type: 'deposit',
    date: sampleDayInCurrentMonth(5, hour: 14),
    amount: 1200,
    description: 'Salary',
    sourceName: 'Employer',
    destinationName: 'Checking',
    categoryName: 'Income',
    currencySymbol: '€',
    currencyCode: 'EUR',
  ),
  Transaction(
    id: '2',
    type: 'withdrawal',
    date: sampleDayInCurrentMonth(8, hour: 10),
    amount: 45,
    description: 'Groceries',
    sourceName: 'Checking',
    destinationName: 'Store',
    categoryName: 'Food',
    currencySymbol: '€',
    currencyCode: 'EUR',
  ),
];

final sampleAccounts = [
  Account(
    id: '1',
    name: 'Checking',
    type: 'asset',
    role: 'defaultAsset',
    currentBalance: 2500,
    currencySymbol: '€',
    currencyCode: 'EUR',
  ),
];

final sampleBudgets = [
  Budget(
    id: '1',
    name: 'Food',
    active: true,
    spent: 120,
    autoBudgetAmount: 400,
    currencySymbol: '€',
    currencyCode: 'EUR',
  ),
];

final sampleBills = [
  Bill(
    id: '1',
    name: 'Monthly Rent',
    amountMin: 1200,
    amountMax: 1200,
    amountAvg: 1200,
    currencyCode: 'EUR',
    currencySymbol: '€',
    date: DateTime(2021, 3, 1),
    repeatFrequency: BillRepeatFrequency.monthly,
    active: true,
  ),
];

const sampleCurrency = FireflyCurrency(
  id: '1',
  code: 'EUR',
  name: 'Euro',
  symbol: '€',
);

const sampleUser = FireflyUser(id: '1', email: 'admin@local.test');
