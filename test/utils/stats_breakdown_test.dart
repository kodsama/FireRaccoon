import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/utils/stats_breakdown.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

Transaction _row(
  String id, {
  String type = 'withdrawal',
  double amount = 10,
  String description = '',
  String category = 'Food',
  String? budget,
  List<String> tags = const [],
  String? notes,
  List<Transaction> splits = const [],
  String? groupTitle,
}) => Transaction(
  id: id,
  type: type,
  date: DateTime(2026, 7, 1),
  amount: amount,
  description: description.isEmpty ? id : description,
  sourceName: 'Checking',
  destinationName: 'Shop',
  categoryName: category,
  budgetName: budget,
  tags: tags,
  notes: notes,
  splits: splits,
  groupTitle: groupTitle,
  currencySymbol: '€',
  currencyCode: 'EUR',
);

const _expense = [TransactionTypeFilter.expense];

void main() {
  test('sums each selected type apart and leaves the others out', () {
    final breakdown = buildStatsBreakdown(
      [
        _row('rent', amount: 900, category: 'Housing'),
        _row('salary', type: 'deposit', amount: 3000, category: 'Salary'),
        _row('savings', type: 'transfer', amount: 500, category: ''),
      ],
      types: [TransactionTypeFilter.expense, TransactionTypeFilter.income],
    );

    expect(breakdown.types.map((t) => t.type), [
      TransactionTypeFilter.expense,
      TransactionTypeFilter.income,
    ]);
    expect(breakdown.totalsFor(TransactionTypeFilter.expense)!.total, 900);
    expect(breakdown.totalsFor(TransactionTypeFilter.income)!.total, 3000);
    expect(breakdown.totalsFor(TransactionTypeFilter.transfer), isNull);
    expect(breakdown.net, 2100);
    expect(breakdown.transactions.map((t) => t.id), ['rent', 'salary']);
  });

  test('net needs both income and expenses shown', () {
    final breakdown = buildStatsBreakdown(
      [_row('rent')],
      types: [TransactionTypeFilter.expense, TransactionTypeFilter.transfer],
    );
    expect(breakdown.net, isNull);
  });

  test('a tag counts only the legs that carry it', () {
    final receipt = _row(
      'receipt',
      splits: [
        _row('plov', amount: 30, category: 'Food', tags: ['5-stan trip 2026']),
        _row('soap', amount: 5, category: 'Household'),
      ],
    );

    final breakdown = buildStatsBreakdown(
      [receipt, _row('lunch', amount: 12)],
      types: _expense,
      tags: {'5-stan trip 2026'},
    );

    final totals = breakdown.totalsFor(TransactionTypeFilter.expense)!;
    expect(totals.categorySums, {'Food': 30});
    expect(breakdown.transactions.map((t) => t.id), ['receipt']);
  });

  test('a budget counts only the legs booked to it', () {
    final breakdown = buildStatsBreakdown(
      [
        _row('groceries', amount: 40, budget: 'Household'),
        _row('cinema', amount: 15, budget: 'Fun', category: 'Leisure'),
        _row('unbudgeted', amount: 7),
      ],
      types: _expense,
      budgets: {'Fun'},
    );

    expect(breakdown.totalsFor(TransactionTypeFilter.expense)!.categorySums, {
      'Leisure': 15,
    });
    expect(breakdown.transactions.single.id, 'cinema');
  });

  test('every word has to appear, each in any field of the leg', () {
    final rows = [
      _row('a', description: 'Coffee', notes: 'Oslo airport'),
      _row('b', description: 'Coffee at home'),
      _row('c', description: 'Train', tags: ['Oslo']),
    ];

    List<String> ids(String words) => buildStatsBreakdown(
      rows,
      types: _expense,
      words: words,
    ).transactions.map((t) => t.id).toList();

    expect(ids('coffee oslo'), ['a']);
    expect(ids('oslo'), ['a', 'c']);
    expect(ids('  '), ['a', 'b', 'c']);
  });

  test('words also match the group title a leg belongs to', () {
    final trip = _row(
      'trip',
      groupTitle: 'Samarkand weekend',
      splits: [_row('hotel', amount: 80), _row('taxi', amount: 8)],
    );
    final breakdown = buildStatsBreakdown(
      [trip],
      types: _expense,
      words: 'samarkand',
    );
    expect(breakdown.totalsFor(TransactionTypeFilter.expense)!.total, 88);
  });

  test('a category narrows the list but keeps every category summed', () {
    final breakdown = buildStatsBreakdown(
      [_row('bread', amount: 4), _row('bus', amount: 3, category: 'Transport')],
      types: _expense,
      categories: {'Transport'},
    );

    expect(breakdown.totalsFor(TransactionTypeFilter.expense)!.categorySums, {
      'Food': 4,
      'Transport': 3,
    });
    expect(breakdown.transactions.single.id, 'bus');
  });

  test('pickers offer the whole period, before any filter narrows it', () {
    final breakdown = buildStatsBreakdown(
      [
        _row('a', tags: ['work'], budget: 'Travel', category: 'Transport'),
        _row('b', tags: ['Holiday'], budget: ' '),
        _row('c', type: 'deposit', tags: ['bonus'], category: 'Salary'),
      ],
      types: _expense,
      tags: {'work'},
    );

    expect(breakdown.categories, ['Food', 'Transport']);
    expect(breakdown.tags, ['Holiday', 'work']);
    expect(breakdown.budgets, ['Travel']);
  });

  test('sortedCategories puts the largest first', () {
    const totals = StatsTypeTotals(
      type: TransactionTypeFilter.expense,
      categorySums: {'Food': 20, 'Rent': 900},
    );
    expect(totals.sortedCategories.first.key, 'Rent');
  });

  test('several names in one filter keep legs matching any of them', () {
    final breakdown = buildStatsBreakdown(
      [
        _row('hotel', amount: 80, tags: ['Holiday']),
        _row('laptop', amount: 900, tags: ['Work']),
        _row('bread', amount: 4),
      ],
      types: _expense,
      tags: {'Holiday', 'Work'},
    );
    expect(breakdown.totalsFor(TransactionTypeFilter.expense)!.total, 980);
    expect(breakdown.transactions.map((t) => t.id), ['hotel', 'laptop']);
  });

  test('accounts keep groups that touch any of them', () {
    final breakdown = buildStatsBreakdown(
      [
        _row('card', amount: 10),
        _row('cash', amount: 5).copyWith(sourceName: 'Wallet'),
        _row('savings', amount: 7).copyWith(sourceName: 'Savings'),
      ],
      types: _expense,
      accounts: {'Checking', 'Wallet'},
    );
    expect(breakdown.transactions.map((t) => t.id), ['card', 'cash']);
    expect(breakdown.totalsFor(TransactionTypeFilter.expense)!.total, 15);
  });
}
