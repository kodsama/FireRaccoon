import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/router/stats_route.dart';
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
    expect(totals.groupSums, {'Food': 30});
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

    expect(breakdown.totalsFor(TransactionTypeFilter.expense)!.groupSums, {
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

    expect(breakdown.totalsFor(TransactionTypeFilter.expense)!.groupSums, {
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

  test('sortedGroups puts the largest first', () {
    const totals = StatsTypeTotals(
      type: TransactionTypeFilter.expense,
      groupSums: {'Food': 20, 'Rent': 900},
    );
    expect(totals.sortedGroups.first.key, 'Rent');
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

  group('series over time', () {
    Transaction on(
      DateTime date,
      String id, {
      String type = 'withdrawal',
      double amount = 10,
      String category = 'Food',
    }) => _row(
      id,
      type: type,
      amount: amount,
      category: category,
    ).copyWith(date: date);

    final july = DateRangeBounds(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 10, 1),
    );

    test('sums each type per bucket and keeps the empty ones', () {
      final breakdown = buildStatsBreakdown(
        [
          on(DateTime(2026, 7, 3), 'rent', amount: 900),
          on(DateTime(2026, 7, 25), 'pay', type: 'deposit', amount: 3000),
          on(DateTime(2026, 9, 2), 'food', amount: 40),
        ],
        types: [TransactionTypeFilter.expense, TransactionTypeFilter.income],
        interval: StatsInterval.month,
        range: july,
        today: DateTime(2026, 9, 30),
      );

      final series = breakdown.series;
      expect(series.map((b) => b.start.month), [7, 8, 9]);
      expect(series[0].totalFor(TransactionTypeFilter.expense), 900);
      expect(series[0].totalFor(TransactionTypeFilter.income), 3000);
      expect(series[0].net, 2100);
      expect(series[1].totals, isEmpty);
      expect(series[2].totalFor(TransactionTypeFilter.expense), 40);
    });

    test('a category filter narrows the series too', () {
      final breakdown = buildStatsBreakdown(
        [
          on(DateTime(2026, 7, 3), 'rent', amount: 900, category: 'Housing'),
          on(DateTime(2026, 7, 4), 'food', amount: 40),
        ],
        types: _expense,
        categories: {'Food'},
        interval: StatsInterval.month,
        range: july,
        today: DateTime(2026, 9, 30),
      );
      expect(
        breakdown.series.first.totalFor(TransactionTypeFilter.expense),
        40,
      );
    });

    test('a period reaching past today stops at today or the last row', () {
      final year = DateRangeBounds(
        start: DateTime(2026, 1, 1),
        end: DateTime(2027, 1, 1),
      );
      List<int> months(List<Transaction> rows) => buildStatsBreakdown(
        rows,
        types: _expense,
        interval: StatsInterval.month,
        range: year,
        today: DateTime(2026, 9, 28),
      ).series.map((b) => b.start.month).toList();

      expect(months([on(DateTime(2026, 2, 1), 'feb')]), hasLength(9));
      expect(
        months([on(DateTime(2026, 11, 3), 'scheduled')]).last,
        11,
        reason: 'a row already dated ahead is still shown',
      );
    });

    test('all time runs from the first row counted to the last', () {
      final breakdown = buildStatsBreakdown(
        [on(DateTime(2024, 5, 1), 'old'), on(DateTime(2026, 2, 1), 'new')],
        types: _expense,
        interval: StatsInterval.year,
      );
      expect(breakdown.series.map((b) => b.start.year), [2024, 2025, 2026]);
    });

    test('no interval, or nothing counted in an open period, gives none', () {
      expect(
        buildStatsBreakdown([
          on(DateTime(2026, 7, 3), 'x'),
        ], types: _expense).series,
        isEmpty,
      );
      expect(
        buildStatsBreakdown(
          const [],
          types: _expense,
          interval: StatsInterval.month,
        ).series,
        isEmpty,
      );
    });
  });

  group('groupings', () {
    test(
      'by tag, a leg with two tags gives each half, untagged its own row',
      () {
        final breakdown = buildStatsBreakdown(
          [
            _row('trip', amount: 100, tags: ['Holiday', 'Work']),
            _row('lunch', amount: 20),
          ],
          types: _expense,
          grouping: StatsGrouping.tag,
        );
        final totals = breakdown.totalsFor(TransactionTypeFilter.expense)!;
        expect(totals.groupSums, {'Holiday': 50, 'Work': 50, '': 20});
        expect(totals.total, 120);
      },
    );

    test('the filter on the grouping keeps the other rows listed', () {
      final rows = [
        _row('trip', amount: 100, tags: ['Holiday']),
        _row('laptop', amount: 900, tags: ['Work'], category: 'Tech'),
      ];
      final byTag = buildStatsBreakdown(
        rows,
        types: _expense,
        grouping: StatsGrouping.tag,
        tags: {'Holiday'},
      );
      expect(
        byTag.totalsFor(TransactionTypeFilter.expense)!.groupSums.keys,
        unorderedEquals(['Holiday', 'Work']),
      );
      expect(byTag.transactions.single.id, 'trip');

      // Any other filter narrows the rows as well.
      final narrowed = buildStatsBreakdown(
        rows,
        types: _expense,
        grouping: StatsGrouping.tag,
        categories: {'Tech'},
      );
      expect(narrowed.totalsFor(TransactionTypeFilter.expense)!.groupSums, {
        'Work': 900,
      });
    });

    test('by budget, account and payee key each leg by its side', () {
      final rows = [
        _row('rent', amount: 900, budget: 'Home'),
        _row(
          'salary',
          type: 'deposit',
          amount: 3000,
        ).copyWith(sourceName: 'Employer', destinationName: 'Checking'),
      ];
      final types = [
        TransactionTypeFilter.expense,
        TransactionTypeFilter.income,
      ];
      Map<String, double> sums(
        StatsGrouping grouping,
        TransactionTypeFilter t,
      ) => buildStatsBreakdown(
        rows,
        types: types,
        grouping: grouping,
      ).totalsFor(t)!.groupSums;

      expect(sums(StatsGrouping.budget, TransactionTypeFilter.expense), {
        'Home': 900,
      });
      expect(sums(StatsGrouping.budget, TransactionTypeFilter.income), {
        '': 3000,
      });
      expect(sums(StatsGrouping.account, TransactionTypeFilter.expense), {
        'Checking': 900,
      });
      expect(sums(StatsGrouping.account, TransactionTypeFilter.income), {
        'Checking': 3000,
      });
      expect(sums(StatsGrouping.payee, TransactionTypeFilter.expense), {
        'Shop': 900,
      });
      expect(sums(StatsGrouping.payee, TransactionTypeFilter.income), {
        'Employer': 3000,
      });
    });

    test('by account, the account filter leaves every account listed', () {
      final breakdown = buildStatsBreakdown(
        [
          _row('card', amount: 10),
          _row('cash', amount: 5).copyWith(sourceName: 'Wallet'),
        ],
        types: _expense,
        grouping: StatsGrouping.account,
        accounts: {'Wallet'},
      );
      expect(breakdown.totalsFor(TransactionTypeFilter.expense)!.groupSums, {
        'Checking': 10,
        'Wallet': 5,
      });
      expect(breakdown.transactions.single.id, 'cash');
    });
  });

  group('stacked parts', () {
    final july = DateRangeBounds(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 8, 1),
    );

    test('each bucket is cut by the split, the smallest folded into Other', () {
      final rows = [
        for (var i = 0; i < 8; i++)
          _row(
            'c$i',
            amount: 100.0 - i,
            category: 'Cat $i',
          ).copyWith(date: DateTime(2026, 7, 2)),
      ];
      final breakdown = buildStatsBreakdown(
        rows,
        types: _expense,
        interval: StatsInterval.month,
        partsBy: StatsGrouping.category,
        range: july,
        today: DateTime(2026, 7, 31),
      );

      expect(breakdown.splitKeys, [
        for (var i = 0; i < 6; i++) 'Cat $i',
        kStatsOtherSplit,
      ]);
      final bucket = breakdown.series.single;
      expect(bucket.partFor(TransactionTypeFilter.expense, 'Cat 0'), 100);
      expect(
        bucket.partFor(TransactionTypeFilter.expense, kStatsOtherSplit),
        93 + 94,
      );
      final parts = breakdown.splitKeys.fold<double>(
        0,
        (sum, key) => sum + bucket.partFor(TransactionTypeFilter.expense, key),
      );
      expect(parts, bucket.totalFor(TransactionTypeFilter.expense));
    });

    test('no split asked for, no parts and no keys', () {
      final breakdown = buildStatsBreakdown(
        [_row('x').copyWith(date: DateTime(2026, 7, 2))],
        types: _expense,
        interval: StatsInterval.month,
        range: july,
        today: DateTime(2026, 7, 31),
      );
      expect(breakdown.splitKeys, isEmpty);
      expect(breakdown.series.single.parts, isEmpty);
    });
  });
}
