import '../models/account.dart';
import '../models/bill.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/currency.dart';
import '../models/piggy_bank.dart';
import '../models/recurrence.dart';
import '../models/tag.dart';
import '../models/transaction.dart';
import 'firefly_service.dart';

/// Schema version of a Firefly data export.
///
/// Owned by the export rather than by the models: a snapshot has to stay
/// readable after the models move on, so its shape is versioned separately and
/// written out here instead of borrowed from whatever a model happens to
/// serialise for the API today.
///
/// 2 carries the identifiers a restore needs where 1 carried only names: the
/// category, budget and bill a recurrence line points at.
const int kDataExportSchemaVersion = 2;

/// What a snapshot covers, and what it does not.
///
/// This is everything the Firefly API will hand over, which is not the same as
/// a backup. Firefly III has no backup endpoint, and an API client cannot reach
/// the database, the uploaded attachments or the instance's `APP_KEY`. Restoring
/// a working instance needs the volume archive that `tool/firefly_backup.sh`
/// takes; this is the portable, human-readable half.
class FireflyDataExport {
  const FireflyDataExport({
    required this.takenAt,
    required this.accounts,
    required this.transactions,
    required this.budgets,
    required this.categories,
    required this.tags,
    required this.bills,
    required this.piggyBanks,
    required this.recurrences,
    required this.currencies,
    this.transactionsFrom,
    this.transactionsTo,
  });

  final DateTime takenAt;
  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<Budget> budgets;
  final List<Category> categories;
  final List<Tag> tags;
  final List<Bill> bills;
  final List<PiggyBank> piggyBanks;
  final List<Recurrence> recurrences;
  final List<FireflyCurrency> currencies;

  /// Window the transactions were read over, null for the service default.
  final DateTime? transactionsFrom;
  final DateTime? transactionsTo;

  /// How many of each entity the snapshot holds, for a receipt a caller can
  /// check without reading the whole thing.
  Map<String, int> get counts => {
    'accounts': accounts.length,
    'transactions': transactions.length,
    'budgets': budgets.length,
    'categories': categories.length,
    'tags': tags.length,
    'bills': bills.length,
    'piggy_banks': piggyBanks.length,
    'recurrences': recurrences.length,
    'currencies': currencies.length,
  };

  Map<String, dynamic> toJson() => {
    'schema_version': kDataExportSchemaVersion,
    'taken_at': takenAt.toUtc().toIso8601String(),
    'transactions_from': _day(transactionsFrom),
    'transactions_to': _day(transactionsTo),
    'counts': counts,
    // Named so a reader can tell a partial snapshot from a whole one without
    // counting rows.
    'covers': const [
      'accounts',
      'transactions',
      'budgets',
      'categories',
      'tags',
      'bills',
      'piggy_banks',
      'recurrences',
      'currencies',
    ],
    'excludes': const [
      'attachments',
      'database',
      'app_key',
      'budget_limits',
      'rules',
      'webhooks',
    ],
    'accounts': [for (final a in accounts) _accountJson(a)],
    'transactions': [for (final t in transactions) _transactionJson(t)],
    'budgets': [for (final b in budgets) _budgetJson(b)],
    'categories': [
      for (final c in categories) {'id': c.id, 'name': c.name},
    ],
    'tags': [
      for (final t in tags) {'id': t.id, 'name': t.name},
    ],
    'bills': [for (final b in bills) _billJson(b)],
    'piggy_banks': [for (final p in piggyBanks) _piggyBankJson(p)],
    'recurrences': [for (final r in recurrences) _recurrenceJson(r)],
    'currencies': [
      for (final c in currencies)
        {
          'id': c.id,
          'code': c.code,
          'name': c.name,
          'symbol': c.symbol,
          'enabled': c.enabled,
        },
    ],
  };
}

String? _day(DateTime? date) {
  if (date == null) return null;
  final local = date.isUtc ? date.toLocal() : date;
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _accountJson(Account a) => {
  'id': a.id,
  'name': a.name,
  'type': a.type,
  'role': a.role,
  'liability_type': a.liabilityType,
  'liability_direction': a.liabilityDirection,
  'current_balance': a.currentBalance,
  'currency_code': a.currencyCode,
  'iban': a.iban,
  'bic': a.bic,
  'account_number': a.accountNumber,
  'notes': a.notes,
  'active': a.active,
  'include_net_worth': a.includeNetWorth,
  'opening_balance': a.openingBalance,
  'opening_balance_date': _day(a.openingBalanceDate),
  'virtual_balance': a.virtualBalance,
  'interest': a.interest,
  'interest_period': a.interestPeriod,
};

Map<String, dynamic> _legJson(Transaction leg) => {
  'journal_id': leg.journalId,
  'type': leg.type,
  'date': leg.date.toIso8601String(),
  'amount': leg.amount,
  'description': leg.description,
  'source_id': leg.sourceId,
  'source_name': leg.sourceName,
  'destination_id': leg.destinationId,
  'destination_name': leg.destinationName,
  'category_id': leg.categoryId,
  'category_name': leg.categoryName,
  'budget_id': leg.budgetId,
  'budget_name': leg.budgetName,
  'bill_id': leg.billId,
  'bill_name': leg.billName,
  'piggy_bank_id': leg.piggyBankId,
  'currency_code': leg.currencyCode,
  'foreign_amount': leg.foreignAmount,
  'foreign_currency_code': leg.foreignCurrencyCode,
  'tags': leg.tags,
  'notes': leg.notes,
  'reconciled': leg.reconciled,
};

/// Every leg is written out, so a split journal restores as one.
Map<String, dynamic> _transactionJson(Transaction t) => {
  'id': t.id,
  'group_title': t.groupTitle,
  'total_amount': t.totalAmount,
  'splits': [for (final leg in t.resolvedSplits()) _legJson(leg)],
};

Map<String, dynamic> _budgetJson(Budget b) => {
  'id': b.id,
  'name': b.name,
  'active': b.active,
  'notes': b.notes,
  'auto_budget_amount': b.autoBudgetAmount,
  'auto_budget_type': b.autoBudgetType.apiValue,
  'auto_budget_period': b.autoBudgetPeriod?.apiValue,
  'currency_code': b.currencyCode,
};

Map<String, dynamic> _billJson(Bill b) => {
  'id': b.id,
  'name': b.name,
  'amount_min': b.amountMin,
  'amount_max': b.amountMax,
  'currency_code': b.currencyCode,
  'date': _day(b.date),
  'end_date': _day(b.endDate),
  'extension_date': _day(b.extensionDate),
  'repeat_freq': b.repeatFrequency.apiValue,
  'skip': b.skip,
  'active': b.active,
  'notes': b.notes,
  'object_group_title': b.objectGroupTitle,
};

Map<String, dynamic> _piggyBankJson(PiggyBank p) => {
  'id': p.id,
  'name': p.name,
  'target_amount': p.targetAmount,
  'current_amount': p.currentAmount,
  'currency_code': p.currencyCode,
  'start_date': _day(p.startDate),
  'target_date': _day(p.targetDate),
  'active': p.active,
  'notes': p.notes,
  'object_group_title': p.objectGroupTitle,
  'accounts': [
    for (final link in p.accounts)
      {
        'account_id': link.accountId,
        'name': link.name,
        'current_amount': link.currentAmount,
      },
  ],
};

Map<String, dynamic> _recurrenceJson(Recurrence r) => {
  'id': r.id,
  'title': r.title,
  'type': r.type.apiValue,
  'description': r.description,
  'active': r.active,
  'apply_rules': r.applyRules,
  'notes': r.notes,
  'first_date': _day(r.firstDate),
  'repeat_until': _day(r.repeatUntil),
  'nr_of_repetitions': r.nrOfRepetitions,
  'repetitions': [
    for (final rep in r.repetitions)
      {
        'type': rep.type.apiValue,
        'moment': rep.moment,
        'skip': rep.skip,
        'weekend': rep.weekend.apiValue,
      },
  ],
  'transactions': [
    for (final line in r.transactions)
      {
        'description': line.description,
        'amount': line.amount,
        'currency_code': line.currencyCode,
        'source_id': line.sourceId,
        'source_name': line.sourceName,
        'destination_id': line.destinationId,
        'destination_name': line.destinationName,
        'category_id': line.categoryId,
        'category_name': line.categoryName,
        'budget_id': line.budgetId,
        'budget_name': line.budgetName,
        'bill_id': line.billId,
        'bill_name': line.billName,
        'tags': line.tags,
      },
  ],
};

/// Reads a snapshot of everything the Firefly API will hand over.
class DataExportService {
  const DataExportService(this._api);

  final FireflyService _api;

  /// Reads every entity, transactions over [from]..[to] when given.
  ///
  /// Entities are read one after another rather than together: a snapshot runs
  /// against someone's live instance, and a burst of parallel page walks over a
  /// large ledger is how a read turns into an outage.
  ///
  /// [onProgress] reports the read running now and how far the walk has got,
  /// counted in requests: eight single reads plus one per page of transactions.
  /// The fraction is null until the first page comes back with a page count,
  /// because a denominator nobody knows yet is worse than an honest wait.
  /// Measured on a 19,420-transaction ledger, the pages are 67 of the 78
  /// seconds this takes, which is why they are the thing counted.
  Future<FireflyDataExport> export({
    DateTime? from,
    DateTime? to,
    DateTime? takenAt,
    void Function(String stage, double? fraction)? onProgress,
  }) async {
    var totalPages = 0;
    var done = 0;
    // Eight reads that are one request each, plus however many pages the
    // transactions take.
    double? fraction() =>
        totalPages == 0 ? null : done / (8 + totalPages).toDouble();
    void report(String stage) => onProgress?.call(stage, fraction());

    report('accounts');
    final accounts = await _api.getAccounts(
      types: const ['asset', 'liability', 'expense', 'revenue'],
    );
    done++;
    report('transactions');
    final transactions = await _api.getTransactions(
      start: from,
      end: to,
      onPageProgress: (loaded, total) {
        // The first page is what makes the walk countable at all.
        totalPages = total;
        done = 1 + loaded;
        report('transactions');
      },
    );
    done = 1 + totalPages;
    report('budgets');
    final budgets = await _api.getBudgets();
    done++;
    report('categories');
    final categories = await _api.getCategories();
    done++;
    report('tags');
    final tags = await _api.getTags();
    done++;
    report('bills');
    final bills = await _api.getBills();
    done++;
    report('piggy_banks');
    final piggyBanks = await _api.getPiggyBanks();
    done++;
    report('recurrences');
    final recurrences = await _api.getRecurrences();
    done++;
    report('currencies');
    final currencies = await _api.getCurrencies();
    done++;
    report('snapshot');

    return FireflyDataExport(
      takenAt: takenAt ?? DateTime.now(),
      accounts: accounts,
      transactions: transactions,
      budgets: budgets,
      categories: categories,
      tags: tags,
      bills: bills,
      piggyBanks: piggyBanks,
      recurrences: recurrences,
      currencies: currencies,
      transactionsFrom: from,
      transactionsTo: to,
    );
  }
}
