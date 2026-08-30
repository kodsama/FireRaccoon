import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Account.fromJson', () {
    test('parses full account payload', () {
      final account = Account.fromJson({
        'id': '5',
        'attributes': {
          'name': 'Checking',
          'type': 'asset',
          'account_role': 'defaultAsset',
          'current_balance': '2500.50',
          'currency_symbol': '€',
          'currency_code': 'EUR',
        },
      });

      expect(account.id, '5');
      expect(account.name, 'Checking');
      expect(account.currentBalance, 2500.5);
    });

    test('normalizes Firefly liabilities type to liability', () {
      final account = Account.fromJson({
        'id': '6',
        'attributes': {
          'name': 'Car Loan',
          'type': 'liabilities',
          'current_balance': '-5000.00',
          'currency_symbol': '€',
          'currency_code': 'EUR',
        },
      });

      expect(account.type, 'liability');
    });

    test('parses optional liability banking fields', () {
      final account = Account.fromJson({
        'id': '7',
        'attributes': {
          'name': 'Mortgage',
          'type': 'liabilities',
          'iban': 'GB82WEST12345698765432',
          'bic': 'WESTGB22',
          'account_number': '12345',
          'notes': 'Skrooge share unit: Avanza Global',
        },
      });

      expect(account.iban, 'GB82WEST12345698765432');
      expect(account.bic, 'WESTGB22');
      expect(account.accountNumber, '12345');
      expect(account.notes, 'Skrooge share unit: Avanza Global');
      expect(account.isLiability, isTrue);
    });

    test('applies defaults for missing fields', () {
      final account = Account.fromJson({
        'id': '1',
        'attributes': <String, dynamic>{},
      });

      expect(account.name, 'Unknown Account');
      expect(account.type, 'asset');
      expect(account.role, 'defaultAsset');
      expect(account.currentBalance, 0);
      expect(account.currencySymbol, '€');
      expect(account.currencyCode, 'EUR');
      expect(account.active, isTrue);
    });

    test('parses active flag', () {
      final inactive = Account.fromJson({
        'id': '8',
        'attributes': {'name': 'Old Savings', 'type': 'asset', 'active': false},
      });

      expect(inactive.active, isFalse);
    });

    test('parses opening balance metadata', () {
      final account = Account.fromJson({
        'id': '9',
        'attributes': {
          'name': 'Savings',
          'opening_balance': '1500.25',
          'opening_balance_date': '2024-01-15',
          'interest_period': 'monthly',
        },
      });

      expect(account.openingBalance, 1500.25);
      expect(account.openingBalanceDate, DateTime(2024, 1, 15));
      expect(account.interestPeriod, 'monthly');
    });

    test('parses virtual balance and interest', () {
      // Both are written by updateAccount but were never read back, so a
      // value set in the app reloaded as null and the edit dialog showed
      // an empty field over a stored figure.
      final account = Account.fromJson({
        'id': '10',
        'attributes': {
          'name': 'Mortgage',
          'type': 'liabilities',
          'virtual_balance': '250.75',
          'interest': '3.5',
        },
      });

      expect(account.virtualBalance, 250.75);
      expect(account.interest, 3.5);
    });

    test('leaves virtual balance and interest null when unreadable', () {
      final missing = Account.fromJson({
        'id': '11',
        'attributes': {'name': 'Checking'},
      });
      final unreadable = Account.fromJson({
        'id': '12',
        'attributes': {
          'name': 'Checking',
          'virtual_balance': '',
          'interest': 'n/a',
        },
      });

      expect(missing.virtualBalance, isNull);
      expect(missing.interest, isNull);
      expect(unreadable.virtualBalance, isNull);
      expect(unreadable.interest, isNull);
    });

    test('copyWith replaces every field', () {
      final base = Account(
        id: '1',
        name: 'Checking',
        type: 'asset',
        role: 'defaultAsset',
        currentBalance: 1000,
        currencySymbol: '€',
        currencyCode: 'EUR',
        iban: 'IBAN',
        bic: 'BIC',
        accountNumber: '123',
        notes: 'note',
        active: true,
        includeNetWorth: true,
        openingBalance: 500,
        openingBalanceDate: DateTime(2024, 1, 1),
        virtualBalance: 100,
        interest: 2.5,
        interestPeriod: 'monthly',
      );

      final updated = base.copyWith(
        id: '2',
        name: 'Savings',
        type: 'liability',
        role: 'savingAsset',
        liabilityType: 'loan',
        liabilityDirection: 'credit',
        currentBalance: 2000,
        currencySymbol: '\$',
        currencyCode: 'USD',
        iban: 'NEW',
        bic: 'NEWBIC',
        accountNumber: '999',
        notes: 'updated',
        active: false,
        includeNetWorth: false,
        openingBalance: 800,
        openingBalanceDate: DateTime(2025, 1, 1),
        virtualBalance: 50,
        interest: 3,
        interestPeriod: 'yearly',
      );

      expect(updated.id, '2');
      expect(updated.name, 'Savings');
      expect(updated.type, 'liability');
      expect(updated.role, 'savingAsset');
      expect(updated.liabilityType, 'loan');
      expect(updated.liabilityDirection, 'credit');
      expect(updated.currentBalance, 2000);
      expect(updated.currencySymbol, '\$');
      expect(updated.currencyCode, 'USD');
      expect(updated.iban, 'NEW');
      expect(updated.bic, 'NEWBIC');
      expect(updated.accountNumber, '999');
      expect(updated.notes, 'updated');
      expect(updated.active, isFalse);
      expect(updated.includeNetWorth, isFalse);
      expect(updated.openingBalance, 800);
      expect(updated.openingBalanceDate, DateTime(2025, 1, 1));
      expect(updated.virtualBalance, 50);
      expect(updated.interest, 3);
      expect(updated.interestPeriod, 'yearly');
    });

    test('copyWith without args returns equivalent account', () {
      final base = Account(
        id: '1',
        name: 'Checking',
        type: 'asset',
        role: 'defaultAsset',
        currentBalance: 1000,
        currencySymbol: '€',
        currencyCode: 'EUR',
        liabilityType: 'loan',
        liabilityDirection: 'credit',
        iban: 'IBAN',
        virtualBalance: 10,
        interest: 1.5,
      );

      final clone = base.copyWith();
      expect(clone.id, base.id);
      expect(clone.name, base.name);
      expect(clone.liabilityType, base.liabilityType);
      expect(clone.virtualBalance, base.virtualBalance);
      expect(clone.interest, base.interest);
    });
  });

  group('Budget.fromJson', () {
    test('parses spent array as absolute value', () {
      final budget = Budget.fromJson({
        'id': '3',
        'attributes': {
          'name': 'Food',
          'active': true,
          'spent': [
            {'sum': '-120.00'},
          ],
          'auto_budget_amount': '400',
          'auto_budget_currency_symbol': '€',
          'auto_budget_currency_code': 'EUR',
        },
      });

      expect(budget.spent, 120);
      expect(budget.autoBudgetAmount, 400);
    });

    test('handles empty spent and missing fields', () {
      final budget = Budget.fromJson({
        'id': '1',
        'attributes': <String, dynamic>{},
      });

      expect(budget.name, 'Unnamed Budget');
      expect(budget.active, isFalse);
      expect(budget.spent, 0);
    });

    test('BudgetInput.toJson includes auto budget fields', () {
      final json = BudgetInput(
        name: 'Food',
        notes: '  groceries  ',
        autoBudgetType: AutoBudgetType.reset,
        autoBudgetAmount: 400,
        autoBudgetPeriod: AutoBudgetPeriod.monthly,
        currencyCode: 'EUR',
      ).toJson();

      expect(json['notes'], 'groceries');
      expect(json['auto_budget_amount'], '400.00');
      expect(json['auto_budget_period'], 'monthly');
      expect(json['auto_budget_currency_code'], 'EUR');
    });

    test('BudgetLimitInput.toJson includes optional notes', () {
      final json = BudgetLimitInput(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31),
        amount: 500,
        currencyCode: 'EUR',
        notes: '  january  ',
      ).toJson();

      expect(json['notes'], 'january');
      expect(json['start'], '2026-01-01');
    });
  });

  group('Bill.fromJson', () {
    test('parses full bill payload', () {
      final bill = Bill.fromJson({
        'id': '7',
        'attributes': {
          'name': 'Monthly Rent',
          'amount_min': '1200.00',
          'amount_max': '1200.00',
          'amount_avg': '1200.00',
          'currency_code': 'EUR',
          'currency_symbol': '€',
          'date': '2021-03-01T00:00:00+00:00',
          'repeat_freq': 'monthly',
          'skip': 1,
          'active': false,
          'notes': 'Landlord contact',
          'object_group_title': 'Housing',
        },
      });

      expect(bill.name, 'Monthly Rent');
      expect(bill.amountMin, 1200);
      expect(bill.repeatFrequency, BillRepeatFrequency.monthly);
      expect(bill.skip, 1);
      expect(bill.active, isFalse);
      expect(bill.objectGroupTitle, 'Housing');
    });

    test('BillRepeatFrequency.fromApi falls back to monthly', () {
      expect(
        BillRepeatFrequency.fromApi('unknown'),
        BillRepeatFrequency.monthly,
      );
    });

    test('BillInput.toJson includes optional trimmed fields', () {
      final json = BillInput(
        name: 'Rent',
        amountMin: 1000,
        amountMax: 1100,
        currencyCode: 'EUR',
        date: DateTime(2026, 3, 1),
        repeatFrequency: BillRepeatFrequency.monthly,
        endDate: DateTime(2027, 3, 1),
        extensionDate: DateTime(2026, 4, 1),
        notes: '  landlord  ',
        objectGroupTitle: '  housing  ',
      ).toJson();

      expect(json['notes'], 'landlord');
      expect(json['object_group_title'], 'housing');
      expect(json['end_date'], '2027-03-01');
      expect(json['extension_date'], '2026-04-01');
    });
  });

  group('PiggyBank.fromJson', () {
    test('parses full piggy bank payload', () {
      final piggy = PiggyBank.fromJson({
        'id': '1',
        'attributes': {
          'name': 'New Laptop',
          'target_amount': '2500.00',
          'current_amount': '500.00',
          'percentage': 20,
          'left_to_save': '2000.00',
          'currency_code': 'EUR',
          'currency_symbol': '€',
          'start_date': '2023-01-01T00:00:00+00:00',
          'target_date': '2024-01-01T00:00:00+00:00',
          'active': true,
          'notes': 'Save up',
          'object_group_title': 'Tech',
          'accounts': [
            {'account_id': '6', 'name': 'Savings', 'current_amount': '500.00'},
          ],
        },
      });

      expect(piggy.name, 'New Laptop');
      expect(piggy.targetAmount, 2500);
      expect(piggy.currentAmount, 500);
      expect(piggy.percentage, 20);
      expect(piggy.accounts, hasLength(1));
      expect(piggy.accounts.first.name, 'Savings');
    });

    test('PiggyBankInput serializes create and update payloads', () {
      final input = PiggyBankInput(
        name: 'Vacation',
        targetAmount: 3000,
        currencyCode: 'EUR',
        accountIds: const ['1', '2'],
        startDate: DateTime(2026, 1, 1),
        targetDate: DateTime(2026, 12, 31),
        notes: '  save up  ',
        objectGroupTitle: '  travel  ',
      );

      final create = input.toCreateJson();
      expect(create['transaction_currency_code'], 'EUR');
      expect(create['notes'], 'save up');
      expect(create['object_group_title'], 'travel');
      expect(create['target_date'], '2026-12-31');

      final update = input.toUpdateJson();
      expect(update.containsKey('transaction_currency_code'), isFalse);
    });
  });

  group('Transaction.fromJson', () {
    test('parses nested transaction attributes', () {
      final tx = Transaction.fromJson({
        'id': '9',
        'attributes': {
          'transactions': [
            {
              'type': 'deposit',
              'date': '2026-02-01',
              'amount': '1200',
              'description': 'Salary',
              'source_name': 'Employer',
              'destination_name': 'Checking',
              'category_name': 'Income',
              'currency_symbol': '€',
              'currency_code': 'EUR',
              'foreign_amount': '1300',
              'foreign_currency_symbol': '\$',
            },
          ],
        },
      });

      expect(tx.type, 'deposit');
      expect(tx.amount, 1200);
      expect(tx.foreignAmount, 1300);
      expect(tx.foreignCurrencySymbol, '\$');
    });

    test('uses defaults when transactions list is empty', () {
      final tx = Transaction.fromJson({
        'id': '1',
        'attributes': <String, dynamic>{},
      });

      expect(tx.type, 'withdrawal');
      expect(tx.description, 'No Description');
      expect(tx.sourceName, 'Unknown');
      expect(tx.foreignAmount, isNull);
    });

    test('handles invalid date gracefully', () {
      final tx = Transaction.fromJson({
        'id': '1',
        'attributes': {
          'transactions': [
            {'date': 'not-a-date'},
          ],
        },
      });

      expect(tx.date, isA<DateTime>());
    });

    test('parses split transaction groups', () {
      final tx = Transaction.fromJson({
        'id': '42',
        'attributes': {
          'group_title': 'Grocery run',
          'transactions': [
            {
              'type': 'withdrawal',
              'date': '2026-07-07',
              'amount': '10',
              'description': 'Grocery run',
              'source_name': 'Checking',
              'destination_name': 'Store',
              'currency_code': 'EUR',
            },
            {
              'type': 'withdrawal',
              'date': '2026-07-07',
              'amount': '15',
              'description': 'Grocery run',
              'source_name': 'Checking',
              'destination_name': 'Market',
              'currency_code': 'EUR',
            },
          ],
        },
      });

      expect(tx.isSplitGroup, isTrue);
      expect(tx.splits, hasLength(2));
      expect(tx.groupTitle, 'Grocery run');
    });

    test('parses a journal id per split of a group', () {
      // Every leg used to expose only the group id, so nothing downstream
      // could name one leg of a split.
      final tx = Transaction.fromJson({
        'id': '42',
        'attributes': {
          'group_title': 'Grocery run',
          'transactions': [
            {
              'transaction_journal_id': 101,
              'type': 'withdrawal',
              'date': '2026-07-07',
              'amount': '10',
              'description': 'Grocery run',
            },
            {
              'transaction_journal_id': '102',
              'type': 'withdrawal',
              'date': '2026-07-07',
              'amount': '15',
              'description': 'Grocery run',
            },
          ],
        },
      });

      expect(tx.id, '42');
      expect(tx.journalId, '101');
      expect(tx.splits.map((split) => split.journalId), ['101', '102']);
    });

    test('leaves journalId null when the payload omits it', () {
      final tx = Transaction.fromJson({
        'id': '7',
        'attributes': {
          'transactions': [
            {'type': 'withdrawal', 'date': '2026-07-07', 'amount': '10'},
          ],
        },
      });

      expect(tx.journalId, isNull);
    });

    test('copyWith replaces the journal id and keeps it otherwise', () {
      // copyWith rebuilds every field explicitly, so a field it forgets is
      // silently dropped: fromJson itself builds split groups through it.
      final leg = Transaction.fromJson({
        'id': '42',
        'attributes': {
          'transactions': [
            {
              'transaction_journal_id': '101',
              'type': 'withdrawal',
              'date': '2026-07-07',
              'amount': '10',
            },
          ],
        },
      });

      expect(leg.copyWith(journalId: '102').journalId, '102');
      expect(leg.copyWith(amount: 12).journalId, '101');
    });

    test('parses reconciled flag from split payload', () {
      final tx = Transaction.fromJson({
        'id': '11',
        'attributes': {
          'transactions': [
            {
              'type': 'withdrawal',
              'date': '2026-07-07',
              'amount': '10',
              'description': 'Coffee',
              'source_name': 'Checking',
              'destination_name': 'Cafe',
              'currency_code': 'EUR',
              'reconciled': true,
            },
          ],
        },
      });

      expect(tx.reconciled, isTrue);
      expect(tx.isReconciled, isTrue);
    });

    test('withReconciled updates every split in a group', () {
      final tx = Transaction(
        id: '42',
        type: 'withdrawal',
        date: DateTime(2026, 7, 7),
        amount: 10,
        description: 'Split shop',
        sourceName: 'Checking',
        destinationName: 'Store',
        categoryName: '',
        currencySymbol: '€',
        currencyCode: 'EUR',
        splits: [
          Transaction(
            id: '42',
            type: 'withdrawal',
            date: DateTime(2026, 7, 7),
            amount: 10,
            description: 'Split shop',
            sourceName: 'Checking',
            destinationName: 'Store',
            categoryName: '',
            currencySymbol: '€',
            currencyCode: 'EUR',
          ),
          Transaction(
            id: '42',
            type: 'withdrawal',
            date: DateTime(2026, 7, 7),
            amount: 15,
            description: 'Split shop',
            sourceName: 'Checking',
            destinationName: 'Market',
            categoryName: '',
            currencySymbol: '€',
            currencyCode: 'EUR',
            reconciled: true,
          ),
        ],
      );

      expect(tx.isPartiallyReconciled, isTrue);
      final reconciled = tx.withReconciled(true);
      expect(reconciled.isReconciled, isTrue);
      expect(reconciled.toSplitJson()['reconciled'], isTrue);
    });

    test('toApiPayload includes group title for splits', () {
      final tx = Transaction(
        id: '1',
        type: 'withdrawal',
        date: DateTime(2026, 7, 7),
        amount: 10,
        description: 'Split shop',
        sourceName: 'Checking',
        destinationName: 'Store',
        categoryName: '',
        currencySymbol: '€',
        currencyCode: 'EUR',
        splits: [
          Transaction(
            id: '1',
            type: 'withdrawal',
            date: DateTime(2026, 7, 7),
            amount: 10,
            description: 'Split shop',
            sourceName: 'Checking',
            destinationName: 'Store',
            categoryName: '',
            currencySymbol: '€',
            currencyCode: 'EUR',
          ),
          Transaction(
            id: '1',
            type: 'withdrawal',
            date: DateTime(2026, 7, 7),
            amount: 15,
            description: 'Split shop',
            sourceName: 'Checking',
            destinationName: 'Market',
            categoryName: '',
            currencySymbol: '€',
            currencyCode: 'EUR',
          ),
        ],
      );

      final payload = tx.toApiPayload();
      expect(payload['group_title'], 'Split shop');
      expect(payload['transactions'], hasLength(2));
    });

    test('parses tags, piggy bank, interest date and reconciled variants', () {
      final tx = Transaction.fromJson({
        'id': '12',
        'attributes': {
          'transactions': [
            {
              'type': 'withdrawal',
              'date': '2026-07-07T10:00:00Z',
              'amount': '10',
              'description': 'Coffee',
              'source_name': 'Checking',
              'destination_name': 'Cafe',
              'currency_code': 'EUR',
              'tags': ['food', ''],
              'piggy_bank_id': '3',
              'piggy_bank_name': 'Treats',
              'interest_date': '2026-07-08',
              'reconciled': '1',
            },
          ],
        },
      });

      expect(tx.tags, ['food']);
      expect(tx.piggyBankId, '3');
      expect(tx.piggyBankName, 'Treats');
      expect(tx.interestDate, DateTime(2026, 7, 8));
      expect(tx.reconciled, isTrue);
      expect(tx.date.isUtc, isFalse);
    });

    test('converts UTC timestamps to local time', () {
      final tx = Transaction.fromJson({
        'id': '13',
        'attributes': {
          'transactions': [
            {
              'type': 'deposit',
              'date': '2026-07-07T22:00:00.000Z',
              'amount': '10',
              'description': 'Late deposit',
              'source_name': 'Employer',
              'destination_name': 'Checking',
              'currency_code': 'EUR',
            },
          ],
        },
      });

      expect(tx.date, DateTime.parse('2026-07-07T22:00:00.000Z').toLocal());
    });

    test('copyWith clear flags drop linked metadata', () {
      final tx = Transaction(
        id: '1',
        type: 'withdrawal',
        date: DateTime(2026, 7, 7),
        amount: 10,
        description: 'Coffee',
        sourceName: 'Checking',
        destinationName: 'Cafe',
        categoryName: 'Food',
        currencySymbol: '€',
        currencyCode: 'EUR',
        foreignAmount: 11,
        foreignCurrencyCode: 'USD',
        budgetId: 'b1',
        billId: 'bill1',
        piggyBankId: 'p1',
        interestDate: DateTime(2026, 7, 8),
      );

      final cleared = tx.copyWith(
        clearForeignAmount: true,
        clearBudget: true,
        clearBill: true,
        clearPiggyBank: true,
        clearInterestDate: true,
      );

      expect(cleared.foreignAmount, isNull);
      expect(cleared.budgetId, isNull);
      expect(cleared.billId, isNull);
      expect(cleared.piggyBankId, isNull);
      expect(cleared.interestDate, isNull);
    });
  });

  group('FireflyCurrency.fromJson', () {
    test('parses currency', () {
      final currency = FireflyCurrency.fromJson({
        'id': '1',
        'attributes': {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
      });

      expect(currency.code, 'USD');
    });

    test('decodes HTML entities in name and symbol', () {
      final currency = FireflyCurrency.fromJson({
        'id': '1',
        'attributes': {'code': 'DG', 'name': 'D&amp;G', 'symbol': 'D&amp;G-G'},
      });

      expect(currency.name, 'D&G');
      expect(currency.symbol, 'D&G-G');
    });
  });

  group('FireflyUser', () {
    test('fromJson parses email', () {
      final user = FireflyUser.fromJson({
        'id': '1',
        'attributes': {'email': 'alex@example.com'},
      });

      expect(user.displayName, 'Alex');
    });

    test('displayName falls back to email when local part empty', () {
      const user = FireflyUser(id: '1', email: '@invalid');
      expect(user.displayName, '@invalid');
    });
  });

  group('TransactionPageResult', () {
    test('holds pagination metadata', () {
      const page = TransactionPageResult(
        transactions: [],
        currentPage: 2,
        totalPages: 5,
        total: 100,
      );

      expect(page.currentPage, 2);
      expect(page.total, 100);
    });
  });

  group('Recurrence.fromJson', () {
    test('parses recurrence with transaction and repetition', () {
      final recurrence = Recurrence.fromJson({
        'id': '7',
        'attributes': {
          'type': 'withdrawal',
          'title': 'Salary',
          'description': 'Monthly salary',
          'first_date': '2026-08-08',
          'active': true,
          'apply_rules': true,
          'repetitions': [
            {
              'type': 'monthly',
              'moment': '8',
              'skip': 0,
              'weekend': 1,
              'description': 'Every month on the 8th day',
            },
          ],
          'transactions': [
            {
              'id': '55',
              'description': 'Salary payment',
              'amount': '3500.00',
              'currency_code': 'EUR',
              'currency_symbol': '€',
              'source_id': '1',
              'destination_id': '2',
            },
          ],
        },
      });

      expect(recurrence.title, 'Salary');
      expect(recurrence.type, RecurrenceTransactionType.withdrawal);
      expect(
        recurrence.primaryRepetition?.type,
        RecurrenceRepetitionType.monthly,
      );
      expect(recurrence.primaryTransaction?.amount, 3500);
    });
  });

  group('RecurrenceInput', () {
    test('serializes store payload', () {
      final input = RecurrenceInput(
        type: RecurrenceTransactionType.withdrawal,
        title: 'Rent',
        firstDate: DateTime(2026, 8, 8),
        repetitions: const [
          RecurrenceRepetitionInput(
            type: RecurrenceRepetitionType.monthly,
            moment: '8',
          ),
        ],
        transactions: const [
          RecurrenceTransactionInput(
            description: 'Rent payment',
            amount: 1500,
            currencyCode: 'EUR',
            sourceId: '1',
            destinationId: '2',
          ),
        ],
      );

      final json = input.toJson(isUpdate: false);
      expect(json['type'], 'withdrawal');
      expect(json['title'], 'Rent');
      expect(json['first_date'], '2026-08-08');
      expect(json['repeat_until'], isNull);
      expect(json['repetitions'], hasLength(1));
      expect(json['transactions'], hasLength(1));
    });

    test('sends the type on an update as well as a store', () {
      // Regression: the type was omitted on update, and Firefly reads the
      // valid account types and the repetition's moment ceiling off it. A
      // transfer was validated as a withdrawal, so the asset account receiving
      // the money came back "could not find a valid destination account" and a
      // monthly rule on the 20th came back "moment may not be greater than 10".
      final input = RecurrenceInput(
        type: RecurrenceTransactionType.transfer,
        title: 'Common fees',
        firstDate: DateTime(2026, 10, 20),
        repetitions: const [
          RecurrenceRepetitionInput(
            type: RecurrenceRepetitionType.monthly,
            moment: '20',
          ),
        ],
        transactions: const [
          RecurrenceTransactionInput(
            description: 'Common fees',
            amount: 7000,
            currencyCode: 'SEK',
            sourceId: '1',
            destinationId: '2',
          ),
        ],
      );

      expect(input.toJson(isUpdate: true)['type'], 'transfer');
      expect(input.toJson(isUpdate: false)['type'], 'transfer');
    });

    test('serializes repeat_until when set', () {
      final json = RecurrenceInput(
        type: RecurrenceTransactionType.withdrawal,
        title: 'Lease',
        firstDate: DateTime(2026, 8, 8),
        repeatUntil: DateTime(2027, 8, 8),
        repetitions: const [
          RecurrenceRepetitionInput(
            type: RecurrenceRepetitionType.monthly,
            moment: '8',
          ),
        ],
        transactions: const [
          RecurrenceTransactionInput(
            description: 'Lease payment',
            amount: 1500,
            currencyCode: 'EUR',
            sourceId: '1',
            destinationId: '2',
          ),
        ],
      ).toJson(isUpdate: false);

      expect(json['repeat_until'], '2027-08-08');
    });

    test('update payload trims description and notes', () {
      final input = RecurrenceInput(
        type: RecurrenceTransactionType.deposit,
        title: 'Bonus',
        description: '  quarterly bonus  ',
        notes: '  tracked  ',
        firstDate: DateTime(2026, 8, 8),
        nrOfRepetitions: 4,
        repetitions: const [
          RecurrenceRepetitionInput(
            type: RecurrenceRepetitionType.yearly,
            moment: '2026-08-08',
          ),
        ],
        transactions: const [
          RecurrenceTransactionInput(
            description: 'Bonus',
            amount: 1000,
            currencyCode: 'EUR',
            sourceId: '1',
            destinationId: '2',
            foreignAmount: 1100,
            foreignCurrencyCode: 'USD',
            budgetId: 'b1',
            categoryId: 'c1',
            billId: 'bill1',
            tags: ['bonus'],
          ),
        ],
      );

      final json = input.toJson(isUpdate: true);
      expect(json['type'], 'deposit');
      expect(json['description'], 'quarterly bonus');
      expect(json['notes'], 'tracked');
      expect(json['nr_of_repetitions'], 4);
      final tx = (json['transactions'] as List).single as Map<String, dynamic>;
      expect(tx['foreign_amount'], '1100.00');
      expect(tx['budget_id'], 'b1');
      expect(tx['tags'], ['bonus']);
    });
  });

  group('Recurrence enums and helpers', () {
    test('fromApi fallbacks and momentForDate branches', () {
      expect(
        RecurrenceTransactionType.fromApi('unknown'),
        RecurrenceTransactionType.withdrawal,
      );
      expect(
        RecurrenceRepetitionType.fromApi(null),
        RecurrenceRepetitionType.monthly,
      );
      expect(
        RecurrenceWeekendMode.fromApi(99),
        RecurrenceWeekendMode.createAnyway,
      );

      final weeklyDate = DateTime(2026, 7, 8);
      expect(
        RecurrenceRepetitionInput.momentForDate(
          RecurrenceRepetitionType.daily,
          weeklyDate,
        ),
        '',
      );
      expect(
        RecurrenceRepetitionInput.momentForDate(
          RecurrenceRepetitionType.weekly,
          weeklyDate,
        ),
        '${weeklyDate.weekday}',
      );
      expect(
        RecurrenceRepetitionInput.momentForDate(
          RecurrenceRepetitionType.monthly,
          weeklyDate,
        ),
        '${weeklyDate.day}',
      );
      expect(
        RecurrenceRepetitionInput.momentForDate(
          RecurrenceRepetitionType.yearly,
          weeklyDate,
        ),
        '2026-07-08',
      );
      expect(
        RecurrenceRepetitionInput.momentForDate(
          RecurrenceRepetitionType.ndom,
          weeklyDate,
        ),
        contains(','),
      );
    });

    test('RecurrenceTransactionLine parses tags and foreign amount', () {
      final line = RecurrenceTransactionLine.fromJson({
        'description': 'Rent',
        'amount': '1500',
        'currency_code': 'EUR',
        'foreign_amount': '1600',
        'foreign_currency_code': 'USD',
        'tags': ['home', 'fixed'],
      });

      expect(line.foreignAmount, 1600);
      expect(line.tags, ['home', 'fixed']);
    });

    test('Recurrence.fromJson handles missing attributes', () {
      final recurrence = Recurrence.fromJson({
        'id': '1',
        'attributes': {'first_date': 'invalid'},
      });

      expect(recurrence.title, 'Unnamed');
      expect(recurrence.primaryRepetition, isNull);
      expect(recurrence.primaryTransaction, isNull);
    });
  });
}
