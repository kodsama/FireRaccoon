import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

Account _account({
  required String id,
  required String name,
  String type = 'asset',
  String role = 'defaultAsset',
  double balance = 0,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    role: role,
    currentBalance: balance,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

Transaction _tx({
  required String id,
  required String type,
  required DateTime date,
  double amount = 100,
  String sourceName = 'Checking',
  String destinationName = 'Groceries',
  String? sourceId,
  String? destinationId,
  String? billId,
}) {
  return Transaction(
    id: id,
    type: type,
    date: date,
    amount: amount,
    description: 'Test $id',
    sourceName: sourceName,
    destinationName: destinationName,
    categoryName: 'Food',
    currencySymbol: '€',
    currencyCode: 'EUR',
    sourceId: sourceId ?? (sourceName == 'Checking' ? '1' : null),
    destinationId: destinationId,
    billId: billId,
  );
}

Recurrence _monthlyRecurrence({
  required String id,
  required int day,
  required double amount,
  String sourceId = '1',
  String sourceName = 'Checking',
  String destinationName = 'Rent',
  String destinationId = '99',
  DateTime? latestDate,
}) {
  return Recurrence(
    id: id,
    type: RecurrenceTransactionType.withdrawal,
    title: 'Rent',
    firstDate: DateTime(2025, 1, day),
    latestDate: latestDate,
    active: true,
    repetitions: [
      RecurrenceRepetition(
        type: RecurrenceRepetitionType.monthly,
        moment: '$day',
      ),
    ],
    transactions: [
      RecurrenceTransactionLine(
        description: 'Rent',
        amount: amount,
        currencyCode: 'EUR',
        sourceId: sourceId,
        sourceName: sourceName,
        destinationId: destinationId,
        destinationName: destinationName,
      ),
    ],
  );
}

Bill _monthlyBill({
  required String id,
  required String name,
  required int day,
  double amount = 50,
}) {
  return Bill(
    id: id,
    name: name,
    amountMin: amount,
    amountMax: amount,
    amountAvg: amount,
    currencyCode: 'EUR',
    currencySymbol: '€',
    date: DateTime(2025, 1, day),
    repeatFrequency: BillRepeatFrequency.monthly,
    active: true,
  );
}

void main() {
  final reference = DateTime(2026, 7, 7);

  // Firefly reports balances as of today: future-dated transactions are
  // excluded server-side, so the reported balance IS the true balance.
  double fireflyReportedBalance(
    double trueBalance,
    Iterable<Transaction> transactions,
    String accountName,
  ) {
    return trueBalance;
  }

  group('RecurrenceScheduler', () {
    test('expands monthly recurrence in remaining month days', () {
      final recurrence = _monthlyRecurrence(id: 'r1', day: 15, amount: 800);
      final dates = expandRecurrenceOccurrences(
        recurrence: recurrence,
        rangeStart: DateTime(2026, 7, 8),
        rangeEnd: DateTime(2026, 8, 1),
      );

      expect(dates, [DateTime(2026, 7, 15)]);
    });

    test('skips recurrence occurrences already materialized', () {
      final recurrence = _monthlyRecurrence(
        id: 'r1',
        day: 15,
        amount: 800,
        latestDate: DateTime(2026, 7, 15),
      );
      final dates = expandRecurrenceOccurrences(
        recurrence: recurrence,
        rangeStart: DateTime(2026, 7, 8),
        rangeEnd: DateTime(2026, 8, 1),
      );

      expect(dates, isEmpty);
    });

    test('expands weekly bill occurrences', () {
      final bill = Bill(
        id: 'b1',
        name: 'Weekly',
        amountMin: 10,
        amountMax: 10,
        amountAvg: 10,
        currencyCode: 'EUR',
        currencySymbol: '€',
        date: DateTime(2026, 7, 3),
        repeatFrequency: BillRepeatFrequency.weekly,
        active: true,
      );
      final dates = expandBillOccurrences(
        bill: bill,
        rangeStart: DateTime(2026, 7, 8),
        rangeEnd: DateTime(2026, 7, 20),
      );

      expect(dates, [DateTime(2026, 7, 10), DateTime(2026, 7, 17)]);
    });
  });

  group('AccountPrognosisService', () {
    test('projects asset balance from scheduled future withdrawal', () {
      final transactions = [
        _tx(
          id: 't1',
          type: 'withdrawal',
          date: DateTime(2026, 7, 20),
          amount: 300,
          sourceId: '1',
          sourceName: 'Checking',
        ),
      ];
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(
            id: '1',
            name: 'Checking',
            balance: fireflyReportedBalance(2000, transactions, 'Checking'),
          ),
        ],
        transactions: transactions,
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(reference: reference),
      );

      final checking = result.forAccount('1');
      expect(checking, isNotNull);
      expect(checking!.currentBalance, 2000);
      expect(checking.endOfMonth.expected, 1700);
      expect(checking.delta, -300);
    });

    test('includes monthly recurrence withdrawal', () {
      final result = AccountPrognosisService.compute(
        accounts: [_account(id: '1', name: 'Checking', balance: 2000)],
        transactions: const [],
        bills: const [],
        recurrences: [_monthlyRecurrence(id: 'r1', day: 15, amount: 500)],
        options: PrognosisOptions(reference: reference),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 1500);
    });

    test('infers bill account from historical transactions', () {
      final result = AccountPrognosisService.compute(
        accounts: [_account(id: '1', name: 'Checking', balance: 1000)],
        transactions: [
          _tx(
            id: 'past',
            type: 'withdrawal',
            date: DateTime(2026, 6, 5),
            amount: 40,
            sourceId: '1',
            sourceName: 'Checking',
            billId: 'b1',
          ),
        ],
        bills: [_monthlyBill(id: 'b1', name: 'Netflix', day: 10, amount: 40)],
        recurrences: const [],
        options: PrognosisOptions(reference: reference),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 960);
    });

    test('excludes credit card payments when toggle is off', () {
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(id: '1', name: 'Checking', balance: 3000),
          _account(
            id: '2',
            name: 'Visa',
            type: 'liability',
            role: 'ccAsset',
            balance: 500,
          ),
        ],
        transactions: const [],
        bills: const [],
        recurrences: [
          Recurrence(
            id: 'cc-pay',
            type: RecurrenceTransactionType.transfer,
            title: 'CC payment',
            firstDate: DateTime(2026, 1, 25),
            active: true,
            repetitions: [
              const RecurrenceRepetition(
                type: RecurrenceRepetitionType.monthly,
                moment: '25',
              ),
            ],
            transactions: [
              const RecurrenceTransactionLine(
                description: 'CC payment',
                amount: 500,
                currencyCode: 'EUR',
                sourceId: '1',
                sourceName: 'Checking',
                destinationId: '2',
                destinationName: 'Visa',
              ),
            ],
          ),
        ],
        options: PrognosisOptions(
          reference: reference,
          inclusion: const PrognosisInclusionOptions(includeCreditCards: false),
        ),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 3000);
      expect(result.forAccount('2')!.endOfMonth.expected, 500);
    });

    test('includes credit card payments when toggle is on', () {
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(id: '1', name: 'Checking', balance: 3000),
          _account(
            id: '2',
            name: 'Visa',
            type: 'liability',
            role: 'ccAsset',
            balance: 500,
          ),
        ],
        transactions: const [],
        bills: const [],
        recurrences: [
          Recurrence(
            id: 'cc-pay',
            type: RecurrenceTransactionType.transfer,
            title: 'CC payment',
            firstDate: DateTime(2026, 1, 25),
            active: true,
            repetitions: [
              const RecurrenceRepetition(
                type: RecurrenceRepetitionType.monthly,
                moment: '25',
              ),
            ],
            transactions: [
              const RecurrenceTransactionLine(
                description: 'CC payment',
                amount: 500,
                currencyCode: 'EUR',
                sourceId: '1',
                sourceName: 'Checking',
                destinationId: '2',
                destinationName: 'Visa',
              ),
            ],
          ),
        ],
        options: PrognosisOptions(
          reference: reference,
          inclusion: const PrognosisInclusionOptions(includeCreditCards: true),
        ),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 2500);
      expect(result.forAccount('2')!.endOfMonth.expected, 0);
    });

    test('dedupes recurrence when matching scheduled transaction exists', () {
      final transactions = [
        _tx(
          id: 'scheduled',
          type: 'withdrawal',
          date: DateTime(2026, 7, 15),
          amount: 500,
          sourceId: '1',
          sourceName: 'Checking',
        ),
      ];
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(
            id: '1',
            name: 'Checking',
            balance: fireflyReportedBalance(2000, transactions, 'Checking'),
          ),
        ],
        transactions: transactions,
        bills: const [],
        recurrences: [_monthlyRecurrence(id: 'r1', day: 15, amount: 500)],
        options: PrognosisOptions(reference: reference),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 1500);
      expect(
        result.forAccount('1')!.events.where((event) => event.date.month == 7),
        hasLength(1),
      );
    });

    test('flags warning when asset projected below zero', () {
      final transactions = [
        _tx(
          id: 't1',
          type: 'withdrawal',
          date: DateTime(2026, 7, 25),
          amount: 500,
          sourceId: '1',
          sourceName: 'Checking',
        ),
      ];
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(
            id: '1',
            name: 'Checking',
            balance: fireflyReportedBalance(200, transactions, 'Checking'),
          ),
        ],
        transactions: transactions,
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(reference: reference),
      );

      final checking = result.forAccount('1');
      expect(checking!.showWarning, isTrue);
      expect(checking.endOfMonth.expected, -300);
      expect(checking.firstNegativeDate, isNotNull);
      expect(
        checking.endOfMonth.pessimistic,
        lessThan(checking.endOfMonth.expected),
      );
    });

    test(
      'records first negative date when balance crosses zero mid-horizon',
      () {
        final transactions = [
          _tx(
            id: 't1',
            type: 'withdrawal',
            date: DateTime(2026, 7, 10),
            amount: 500,
            sourceId: '1',
            sourceName: 'Checking',
          ),
        ];
        final result = AccountPrognosisService.compute(
          accounts: [
            _account(
              id: '1',
              name: 'Checking',
              balance: fireflyReportedBalance(400, transactions, 'Checking'),
            ),
          ],
          transactions: transactions,
          bills: const [],
          recurrences: const [],
          options: PrognosisOptions(
            reference: reference,
            horizon: PrognosisHorizon.endOfNextMonth,
          ),
        );

        final checking = result.forAccount('1')!;
        expect(checking.firstNegativeDate, DateTime(2026, 7, 10));
        expect(
          checking.milestones[PrognosisMilestone.endOfMonth]!.expected,
          -100,
        );
      },
    );

    test('projected mode compounds balance from historical net flow', () {
      final result = AccountPrognosisService.compute(
        accounts: [_account(id: '1', name: 'Checking', balance: 1000)],
        transactions: [
          _tx(
            id: 'income',
            type: 'deposit',
            date: DateTime(2026, 6, 1),
            amount: 300,
            destinationId: '1',
            destinationName: 'Checking',
          ),
          _tx(
            id: 'expense',
            type: 'withdrawal',
            date: DateTime(2026, 6, 15),
            amount: 100,
            sourceId: '1',
            sourceName: 'Checking',
          ),
        ],
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(
          reference: reference,
          mode: PrognosisViewMode.projected,
          horizon: PrognosisHorizon.threeMonths,
        ),
      );

      final checking = result.forAccount('1')!;
      expect(
        checking.endOfMonth.expected,
        greaterThan(checking.currentBalance),
      );
      expect(
        checking.milestones[PrognosisMilestone.threeMonths]!.expected,
        greaterThan(checking.endOfMonth.expected),
      );
    });

    test('excludes income when toggle is off', () {
      final transactions = [
        _tx(
          id: 't1',
          type: 'deposit',
          date: DateTime(2026, 7, 20),
          amount: 400,
          sourceName: 'Employer',
          destinationName: 'Checking',
          destinationId: '1',
        ),
      ];
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(
            id: '1',
            name: 'Checking',
            balance: fireflyReportedBalance(1000, transactions, 'Checking'),
          ),
        ],
        transactions: transactions,
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(
          reference: reference,
          inclusion: const PrognosisInclusionOptions(includeIncome: false),
        ),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 1000);
    });

    test('widens pessimistic band with higher margin', () {
      final lowMargin = AccountPrognosisService.compute(
        accounts: [_account(id: '1', name: 'Checking', balance: 2000)],
        transactions: [
          _tx(
            id: 't1',
            type: 'withdrawal',
            date: DateTime(2026, 7, 20),
            amount: 200,
            sourceId: '1',
            sourceName: 'Checking',
          ),
        ],
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(reference: reference, marginPercent: 5),
      );
      final highMargin = AccountPrognosisService.compute(
        accounts: [_account(id: '1', name: 'Checking', balance: 2000)],
        transactions: [
          _tx(
            id: 't1',
            type: 'withdrawal',
            date: DateTime(2026, 7, 20),
            amount: 200,
            sourceId: '1',
            sourceName: 'Checking',
          ),
        ],
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(reference: reference, marginPercent: 30),
      );

      final low = lowMargin.forAccount('1')!;
      final high = highMargin.forAccount('1')!;
      expect(high.endOfMonth.pessimistic, lessThan(low.endOfMonth.pessimistic));
    });

    test('prognosisEndOfNextMonth returns first day of month after next', () {
      expect(
        prognosisEndOfNextMonth(DateTime(2026, 7, 7)),
        DateTime(2026, 9, 1),
      );
    });

    test('forwardAccountBalanceSparkline exposes timeline expected values', () {
      final result = AccountPrognosisService.compute(
        accounts: [_account(id: '1', name: 'Checking', balance: 1000)],
        transactions: [
          _tx(
            id: 't1',
            type: 'withdrawal',
            date: DateTime(2026, 7, 20),
            amount: 100,
            sourceId: '1',
            sourceName: 'Checking',
          ),
        ],
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(reference: reference),
      );

      final checking = result.forAccount('1')!;
      expect(
        forwardAccountBalanceSparkline(checking),
        checking.forwardSparkline,
      );
      expect(forwardAccountBalanceSparkline(checking), isNotEmpty);
    });

    test('includes scheduled deposit income', () {
      final result = AccountPrognosisService.compute(
        accounts: [_account(id: '1', name: 'Checking', balance: 1000)],
        transactions: [
          _tx(
            id: 'pay',
            type: 'deposit',
            date: DateTime(2026, 7, 20),
            amount: 500,
            sourceName: 'Employer',
            destinationName: 'Checking',
            destinationId: '1',
          ),
        ],
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(reference: reference),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 1500);
    });

    test('excludes non-credit-card transfers when toggle is off', () {
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(id: '1', name: 'Checking', balance: 3000),
          _account(id: '2', name: 'Savings', role: 'savingAsset', balance: 0),
        ],
        transactions: [
          _tx(
            id: 'xfer',
            type: 'transfer',
            date: DateTime(2026, 7, 20),
            amount: 400,
            sourceName: 'Checking',
            destinationName: 'Savings',
            sourceId: '1',
            destinationId: '2',
          ),
        ],
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(
          reference: reference,
          inclusion: const PrognosisInclusionOptions(includeTransfers: false),
        ),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 3000);
      expect(result.forAccount('2')!.endOfMonth.expected, 0);
    });

    test('excludes scheduled transactions when toggle is off', () {
      final result = AccountPrognosisService.compute(
        accounts: [_account(id: '1', name: 'Checking', balance: 1000)],
        transactions: [
          _tx(
            id: 't1',
            type: 'withdrawal',
            date: DateTime(2026, 7, 20),
            amount: 200,
            sourceId: '1',
            sourceName: 'Checking',
          ),
        ],
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(
          reference: reference,
          inclusion: const PrognosisInclusionOptions(
            includeScheduledTransactions: false,
          ),
        ),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 1000);
    });

    test('excludes bills and recurring flows when toggles are off', () {
      final result = AccountPrognosisService.compute(
        accounts: [_account(id: '1', name: 'Checking', balance: 1000)],
        transactions: const [],
        bills: [_monthlyBill(id: 'b1', name: 'Netflix', day: 10, amount: 40)],
        recurrences: [_monthlyRecurrence(id: 'r1', day: 15, amount: 500)],
        options: PrognosisOptions(
          reference: reference,
          inclusion: const PrognosisInclusionOptions(
            includeBills: false,
            includeRecurringTransactions: false,
          ),
        ),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 1000);
    });

    test('infers deposit bill template from historical salary bill', () {
      final result = AccountPrognosisService.compute(
        accounts: [_account(id: '1', name: 'Checking', balance: 500)],
        transactions: [
          _tx(
            id: 'past',
            type: 'deposit',
            date: DateTime(2026, 6, 5),
            amount: 200,
            sourceName: 'Employer',
            destinationName: 'Checking',
            destinationId: '1',
            billId: 'b1',
          ),
        ],
        bills: [_monthlyBill(id: 'b1', name: 'Bonus', day: 10, amount: 200)],
        recurrences: const [],
        options: PrognosisOptions(reference: reference),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 700);
    });

    test('liability showWarning when optimistic balance worsens', () {
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(
            id: '2',
            name: 'Visa',
            type: 'liability',
            role: 'ccAsset',
            balance: 200,
          ),
        ],
        transactions: [
          _tx(
            id: 'purchase',
            type: 'withdrawal',
            date: DateTime(2026, 7, 20),
            amount: 300,
            sourceName: 'Visa',
            destinationName: 'Store',
            sourceId: '2',
          ),
        ],
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(reference: reference),
      );

      expect(result.forAccount('2')!.showWarning, isTrue);
    });

    test('projected mode computes liability prognosis timeline', () {
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(
            id: '2',
            name: 'Visa',
            type: 'liability',
            role: 'ccAsset',
            balance: 200,
          ),
        ],
        transactions: [
          _tx(
            id: 'purchase',
            type: 'withdrawal',
            date: DateTime(2026, 6, 1),
            amount: 100,
            sourceName: 'Visa',
            destinationName: 'Store',
            sourceId: '2',
          ),
        ],
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(
          reference: reference,
          mode: PrognosisViewMode.projected,
          horizon: PrognosisHorizon.threeMonths,
        ),
      );

      final visa = result.forAccount('2')!;
      expect(visa.timeline, isNotEmpty);
      expect(visa.events, isEmpty);
    });

    test('transfer history contributes to projected monthly net', () {
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(id: '1', name: 'Checking', balance: 1000),
          _account(id: '2', name: 'Savings', role: 'savingAsset', balance: 0),
        ],
        transactions: [
          _tx(
            id: 'xfer',
            type: 'transfer',
            date: DateTime(2026, 6, 1),
            amount: 300,
            sourceName: 'Checking',
            destinationName: 'Savings',
            sourceId: '1',
            destinationId: '2',
          ),
        ],
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(
          reference: reference,
          mode: PrognosisViewMode.projected,
          horizon: PrognosisHorizon.threeMonths,
        ),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, lessThan(1000));
    });

    test('infers transfer bill template from historical transactions', () {
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(id: '1', name: 'Checking', balance: 2000),
          _account(id: '2', name: 'Savings', role: 'savingAsset', balance: 0),
        ],
        transactions: [
          _tx(
            id: 'past',
            type: 'transfer',
            date: DateTime(2026, 6, 5),
            amount: 100,
            sourceName: 'Checking',
            destinationName: 'Savings',
            sourceId: '1',
            destinationId: '2',
            billId: 'b1',
          ),
        ],
        bills: [
          _monthlyBill(id: 'b1', name: 'Allowance', day: 10, amount: 100),
        ],
        recurrences: const [],
        options: PrognosisOptions(reference: reference),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 1900);
      expect(result.forAccount('2')!.endOfMonth.expected, 100);
    });

    test('ignores expense accounts in prognosis output', () {
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(id: '1', name: 'Checking', balance: 1000),
          _account(id: '9', name: 'Groceries', type: 'expense', balance: 0),
        ],
        transactions: const [],
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(reference: reference),
      );

      expect(result.accounts.map((a) => a.accountId), ['1']);
    });

    test('dedupes unusual scheduled transaction types', () {
      final result = AccountPrognosisService.compute(
        accounts: [_account(id: '1', name: 'Checking', balance: 1000)],
        transactions: [
          Transaction(
            id: 'adj',
            type: 'reconciliation',
            date: DateTime(2026, 7, 20),
            amount: 50,
            description: 'Adjustment',
            sourceName: 'Checking',
            destinationName: 'Reconciliation',
            categoryName: '',
            currencySymbol: '€',
            currencyCode: 'EUR',
            sourceId: '1',
          ),
        ],
        bills: const [],
        recurrences: const [],
        options: PrognosisOptions(reference: reference),
      );

      expect(result.forAccount('1'), isNotNull);
    });

    test('matches credit card destination by account name', () {
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(id: '1', name: 'Checking', balance: 3000),
          _account(
            id: '2',
            name: 'Visa',
            type: 'liability',
            role: 'ccAsset',
            balance: 500,
          ),
        ],
        transactions: const [],
        bills: const [],
        recurrences: [
          Recurrence(
            id: 'cc-pay',
            type: RecurrenceTransactionType.transfer,
            title: 'CC payment',
            firstDate: DateTime(2026, 1, 25),
            active: true,
            repetitions: [
              const RecurrenceRepetition(
                type: RecurrenceRepetitionType.monthly,
                moment: '25',
              ),
            ],
            transactions: [
              RecurrenceTransactionLine(
                description: 'CC payment',
                amount: 500,
                currencyCode: 'EUR',
                sourceId: '1',
                sourceName: 'Checking',
                destinationName: 'Visa',
              ),
            ],
          ),
        ],
        options: PrognosisOptions(
          reference: reference,
          inclusion: const PrognosisInclusionOptions(includeCreditCards: true),
        ),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, 2500);
    });

    test('infers bill templates from name-only historical transactions', () {
      final result = AccountPrognosisService.compute(
        accounts: [
          _account(id: '1', name: 'Checking', balance: 1000),
          _account(id: '2', name: 'Savings', role: 'savingAsset', balance: 0),
        ],
        transactions: [
          Transaction(
            id: 'past',
            type: 'transfer',
            date: DateTime(2026, 6, 5),
            amount: 75,
            description: 'Allowance',
            sourceName: 'Checking',
            destinationName: 'Savings',
            categoryName: '',
            currencySymbol: '€',
            currencyCode: 'EUR',
            billId: 'b1',
          ),
          Transaction(
            id: 'salary',
            type: 'deposit',
            date: DateTime(2026, 6, 1),
            amount: 200,
            description: 'Bonus bill',
            sourceName: 'Employer',
            destinationName: 'Checking',
            categoryName: '',
            currencySymbol: '€',
            currencyCode: 'EUR',
            billId: 'b2',
          ),
          Transaction(
            id: 'bill-withdrawal',
            type: 'withdrawal',
            date: DateTime(2026, 6, 2),
            amount: 40,
            description: 'Streaming',
            sourceName: 'Checking',
            destinationName: 'Netflix',
            categoryName: '',
            currencySymbol: '€',
            currencyCode: 'EUR',
            billId: 'b3',
          ),
        ],
        bills: [
          _monthlyBill(id: 'b1', name: 'Allowance', day: 10, amount: 75),
          _monthlyBill(id: 'b2', name: 'Bonus', day: 5, amount: 200),
          _monthlyBill(id: 'b3', name: 'Streaming', day: 12, amount: 40),
        ],
        recurrences: const [],
        options: PrognosisOptions(reference: reference),
      );

      expect(result.forAccount('1')!.endOfMonth.expected, lessThan(1000));
      expect(result.forAccount('2')!.endOfMonth.expected, greaterThan(0));
    });
  });
}
