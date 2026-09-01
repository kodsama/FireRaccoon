import 'package:fireraccoon_engine/fireraccoon_engine.dart';

class FakeFireflyService implements FireflyService {
  FakeFireflyService({
    FireflyCurrency? primaryCurrency,
    this.currentUser = const FireflyUser(id: '1', email: 'admin@local.test'),
    this.accounts = const [],
    this.transactions = const [],
    this.budgets = const [],
    this.bills = const [],
    this.recurrences = const [],
    this.piggyBanks = const [],
    this.currencies = const [],
    this.categories = const [],
    this.tags = const [],
    this.transactionPages = const {},
    this.accountTransactionPages = const {},
    this.budgetTransactions = const {},
    this.balancesByDate = const {},
  }) : _primaryCurrency =
           primaryCurrency ??
           const FireflyCurrency(
             id: '1',
             code: 'EUR',
             name: 'Euro',
             symbol: '€',
           );

  FireflyCurrency _primaryCurrency;
  final FireflyUser currentUser;
  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<Budget> budgets;
  final List<Bill> bills;
  final List<Recurrence> recurrences;
  final List<PiggyBank> piggyBanks;
  final List<FireflyCurrency> currencies;
  final Map<int, TransactionPageResult> transactionPages;
  final Map<String, Map<int, TransactionPageResult>> accountTransactionPages;
  final Map<String, List<Transaction>> budgetTransactions;

  /// Balance per account per `yyyy-MM-dd`, for the dated reads. Firefly
  /// answers those from the ledger, so a fake that ignored the date could
  /// not tell a chosen day from today.
  final Map<String, Map<String, double>> balancesByDate;

  Exception? throwOn;
  Exception? createTransactionError;
  Exception? accountBalanceHistoriesError;
  Duration? responseDelay;

  /// Windows [getAccountTransactionsPage] was asked for.
  ///
  /// Firefly returns nothing for a range with only one bound, which a fake that
  /// treats a missing bound as unbounded will happily hide.
  final List<({DateTime? start, DateTime? end})> accountPageWindows = [];
  final List<Transaction> updatedTransactions = [];

  Future<void> _maybeDelay() async {
    final delay = responseDelay;
    if (delay != null) await Future<void>.delayed(delay);
  }

  @override
  Future<FireflyCurrency> getPrimaryCurrency() async {
    _maybeThrow();
    return _primaryCurrency;
  }

  @override
  Future<void> setPrimaryCurrency(String code) async {
    _maybeThrow();
    final match = currencies.where((c) => c.code == code).firstOrNull;
    _primaryCurrency =
        match ??
        FireflyCurrency(
          id: 'primary-$code',
          code: code,
          name: code,
          symbol: code,
        );
  }

  @override
  Future<FireflyUser> getCurrentUser() async {
    _maybeThrow();
    return currentUser;
  }

  @override
  Future<List<Account>> getAccounts({
    List<String> types = const ['asset', 'liability'],
  }) async {
    _maybeThrow();
    return accounts.where((a) => types.contains(a.type)).toList();
  }

  @override
  Future<Account> getAccount(String accountId, {DateTime? date}) async {
    _maybeThrow();
    return accounts.firstWhere(
      (account) => account.id == accountId,
      orElse: () => throw Exception('Account not found: $accountId'),
    );
  }

  @override
  Future<double> getAccountBalanceAtDate(
    String accountId,
    DateTime date,
  ) async {
    final key =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final forAccount = balancesByDate[accountId];
    // '*' answers for any date, for tests whose chosen day is today and so
    // cannot be written as a literal.
    final dated = forAccount?[key] ?? forAccount?['*'];
    if (dated != null) {
      await _maybeDelay();
      return dated;
    }
    return (await getAccount(accountId, date: date)).currentBalance;
  }

  @override
  Future<Map<String, List<double>>> getAccountBalanceHistories({
    required List<Account> accounts,
    required DateTime start,
    required DateTime end,
    String period = '1M',
  }) async {
    final historyError = accountBalanceHistoriesError;
    if (historyError != null) throw historyError;
    _maybeThrow();
    return {
      for (final account in accounts)
        account.name: [account.currentBalance * 0.9, account.currentBalance],
    };
  }

  @override
  Future<List<Transaction>> getTransactions({
    DateTime? start,
    DateTime? end,
    String? type,
    void Function(List<Transaction> firstPage)? onFirstPage,
  }) async {
    _maybeThrow();
    final typed = type == null || type.isEmpty
        ? transactions
        : transactions.where((t) => t.type == type).toList();
    final result = start == null && end == null
        ? typed
        : typed
              .where(
                (t) => DateRangeBounds(start: start, end: end).contains(t.date),
              )
              .toList();
    onFirstPage?.call(result);
    return result;
  }

  @override
  Future<TransactionPageResult> getTransactionsPage({
    required int page,
    required int limit,
    DateTime? start,
    DateTime? end,
  }) async {
    _maybeThrow();
    await _maybeDelay();
    return transactionPages[page] ??
        TransactionPageResult(
          transactions: transactions,
          currentPage: page,
          totalPages: 1,
          total: transactions.length,
        );
  }

  @override
  Future<TransactionPageResult> searchTransactionsPage(
    String query, {
    required int page,
    required int limit,
  }) async {
    _maybeThrow();
    final matches = transactions
        .where((t) => t.description.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return TransactionPageResult(
      transactions: matches,
      currentPage: page,
      totalPages: 1,
      total: matches.length,
    );
  }

  @override
  Future<List<Transaction>> getAccountTransactions(
    String accountId, {
    DateTime? start,
    DateTime? end,
  }) async {
    _maybeThrow();
    return accountTransactionPages[accountId]?.values
            .expand((p) => p.transactions)
            .toList() ??
        transactions;
  }

  @override
  Future<TransactionPageResult> getBillTransactionsPage(
    String billId, {
    required int page,
    required int limit,
  }) async {
    _maybeThrow();
    final matches = transactions.where((t) => t.billId == billId).toList();
    return TransactionPageResult(
      transactions: matches.take(limit).toList(),
      currentPage: page,
      totalPages: 1,
      total: matches.length,
    );
  }

  @override
  Future<TransactionPageResult> getRecurrenceTransactionsPage(
    String recurrenceId, {
    required int page,
    required int limit,
  }) async {
    _maybeThrow();
    return TransactionPageResult(
      transactions: transactions.take(limit).toList(),
      currentPage: page,
      totalPages: 1,
      total: transactions.length,
    );
  }

  @override
  Future<TransactionPageResult> getAccountTransactionsPage(
    String accountId, {
    required int page,
    required int limit,
    DateTime? start,
    DateTime? end,
  }) async {
    _maybeThrow();
    await _maybeDelay();
    accountPageWindows.add((start: start, end: end));
    final result = accountTransactionPages[accountId]?[page];
    if (result == null) {
      return TransactionPageResult(
        transactions: const [],
        currentPage: page,
        totalPages: 1,
        total: 0,
      );
    }
    if (start == null && end == null) return result;
    // The server splits by date, so a caller asking for one side of today must
    // not be handed both. Without this a test could not tell the two apart.
    final windowed = result.transactions
        .where(
          (t) =>
              (start == null || !t.date.isBefore(start)) &&
              (end == null || t.date.isBefore(end)),
        )
        .toList();
    return TransactionPageResult(
      transactions: windowed,
      currentPage: page,
      totalPages: result.totalPages,
      total: windowed.length,
    );
  }

  @override
  Future<List<Budget>> getBudgets({DateTime? start, DateTime? end}) async {
    _maybeThrow();
    return budgets;
  }

  @override
  Future<Transaction> getTransaction(String transactionId) async {
    _maybeThrow();
    return transactions.firstWhere(
      (transaction) => transaction.id == transactionId,
      orElse: () => throw Exception('Transaction not found: $transactionId'),
    );
  }

  @override
  Future<List<Transaction>> getBudgetTransactions(
    String budgetId, {
    DateTime? start,
    DateTime? end,
  }) async {
    _maybeThrow();
    return budgetTransactions[budgetId] ?? const [];
  }

  @override
  Future<void> deleteBudget(String budgetId) async {
    _maybeThrow();
  }

  @override
  Future<void> updateAccount(
    String accountId, {
    String? name,
    String? type,
    String? iban,
    String? bic,
    String? accountNumber,
    String? notes,
    bool? active,
    String? role,
    String? currencyCode,
    String? liabilityType,
    String? liabilityDirection,
    bool? includeNetWorth,
    double? openingBalance,
    DateTime? openingBalanceDate,
    double? virtualBalance,
    double? interest,
    String? interestPeriod,
  }) async {
    _maybeThrow();
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    _maybeThrow();
  }

  @override
  Future<Account> createAccount({
    required String name,
    required String type,
    required String currencyCode,
    String? role,
  }) async {
    _maybeThrow();
    return Account(
      id: 'new-${accounts.length + 1}',
      name: name,
      type: type,
      role: type == 'liability' ? 'ccAsset' : 'defaultAsset',
      currentBalance: 0,
      currencySymbol: _primaryCurrency.symbol,
      currencyCode: currencyCode,
    );
  }

  @override
  Future<Account> createLiability(LiabilityInput input) async {
    _maybeThrow();
    return Account(
      id: 'new-${accounts.length + 1}',
      name: input.name,
      type: 'liability',
      role: 'ccAsset',
      currentBalance: input.amountOwed ?? 0,
      currencySymbol: _primaryCurrency.symbol,
      currencyCode: input.currencyCode,
    );
  }

  @override
  Future<Budget> createBudget(BudgetInput input) async {
    _maybeThrow();
    return Budget(
      id: 'new-${budgets.length + 1}',
      name: input.name,
      active: input.active,
      notes: input.notes,
      spent: 0,
      autoBudgetAmount: input.autoBudgetAmount ?? 0,
      autoBudgetType: input.autoBudgetType,
      autoBudgetPeriod: input.autoBudgetPeriod,
      currencySymbol: _primaryCurrency.symbol,
      currencyCode: input.currencyCode,
    );
  }

  @override
  Future<void> updateBudget(String budgetId, BudgetInput input) async {
    _maybeThrow();
  }

  @override
  Future<List<BudgetLimit>> getBudgetLimits(
    String budgetId, {
    DateTime? start,
    DateTime? end,
  }) async {
    _maybeThrow();
    return const [];
  }

  @override
  Future<BudgetLimit> createBudgetLimit(
    String budgetId,
    BudgetLimitInput input,
  ) async {
    _maybeThrow();
    return BudgetLimit(
      id: 'limit-1',
      budgetId: budgetId,
      start: input.start,
      end: input.end,
      amount: input.amount,
      currencyCode: input.currencyCode,
      currencySymbol: _primaryCurrency.symbol,
      notes: input.notes,
    );
  }

  @override
  Future<void> updateBudgetLimit(
    String budgetId,
    String limitId,
    BudgetLimitInput input,
  ) async {
    _maybeThrow();
  }

  final List<Category> categories;
  final List<Tag> tags;

  @override
  Future<List<Category>> getCategories() async {
    _maybeThrow();
    return categories;
  }

  @override
  Future<Category> createCategory(String name, {String? notes}) async {
    _maybeThrow();
    return Category(id: 'cat-${categories.length + 1}', name: name);
  }

  @override
  Future<Category> updateCategory(
    String categoryId,
    String name, {
    String? notes,
  }) async {
    _maybeThrow();
    return Category(id: categoryId, name: name);
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    _maybeThrow();
  }

  @override
  Future<List<Tag>> getTags() async {
    _maybeThrow();
    return tags;
  }

  @override
  Future<Tag> createTag(String tag, {String? description}) async {
    _maybeThrow();
    return Tag(id: 'tag-${tags.length + 1}', name: tag);
  }

  @override
  Future<Tag> updateTag(String tagId, String tag, {String? description}) async {
    _maybeThrow();
    return Tag(id: tagId, name: tag);
  }

  @override
  Future<void> deleteTag(String tagId) async {
    _maybeThrow();
  }

  @override
  Future<List<Bill>> getBills() async {
    _maybeThrow();
    return bills;
  }

  @override
  Future<List<FireflyCurrency>> getCurrencies() async {
    _maybeThrow();
    return currencies.isEmpty ? [_primaryCurrency] : currencies;
  }

  @override
  Future<Bill> createBill(BillInput input) async {
    _maybeThrow();
    return Bill(
      id: 'new-${bills.length + 1}',
      name: input.name,
      amountMin: input.amountMin,
      amountMax: input.amountMax,
      amountAvg: (input.amountMin + input.amountMax) / 2,
      currencyCode: input.currencyCode,
      currencySymbol: _primaryCurrency.symbol,
      date: input.date,
      endDate: input.endDate,
      extensionDate: input.extensionDate,
      repeatFrequency: input.repeatFrequency,
      skip: input.skip,
      active: input.active,
      notes: input.notes,
      objectGroupTitle: input.objectGroupTitle,
    );
  }

  @override
  Future<Bill> updateBill(String billId, BillInput input) async {
    _maybeThrow();
    final existing = bills.where((b) => b.id == billId).firstOrNull;
    return Bill(
      id: billId,
      name: input.name,
      amountMin: input.amountMin,
      amountMax: input.amountMax,
      amountAvg: (input.amountMin + input.amountMax) / 2,
      currencyCode: input.currencyCode,
      currencySymbol: existing?.currencySymbol ?? _primaryCurrency.symbol,
      date: input.date,
      endDate: input.endDate,
      extensionDate: input.extensionDate,
      repeatFrequency: input.repeatFrequency,
      skip: input.skip,
      active: input.active,
      notes: input.notes,
      objectGroupTitle: input.objectGroupTitle,
    );
  }

  @override
  Future<void> deleteBill(String billId) async {
    _maybeThrow();
  }

  @override
  Future<List<Recurrence>> getRecurrences() async {
    _maybeThrow();
    return recurrences;
  }

  @override
  Future<Recurrence> createRecurrence(RecurrenceInput input) async {
    _maybeThrow();
    final tx = input.transactions.isEmpty ? null : input.transactions.first;
    return Recurrence(
      id: 'new-${recurrences.length + 1}',
      type: input.type,
      title: input.title,
      description: input.description,
      firstDate: input.firstDate,
      repeatUntil: input.repeatUntil,
      nrOfRepetitions: input.nrOfRepetitions,
      applyRules: input.applyRules,
      active: input.active,
      notes: input.notes,
      repetitions: input.repetitions
          .map(
            (r) => RecurrenceRepetition(
              type: r.type,
              moment: r.moment,
              skip: r.skip,
              weekend: r.weekend,
            ),
          )
          .toList(),
      transactions: tx == null
          ? const []
          : [
              RecurrenceTransactionLine(
                description: tx.description,
                amount: tx.amount,
                currencyCode: tx.currencyCode,
                currencySymbol: _primaryCurrency.symbol,
                sourceId: tx.sourceId,
                destinationId: tx.destinationId,
                budgetId: tx.budgetId,
                categoryId: tx.categoryId,
                billId: tx.billId,
                tags: tx.tags,
              ),
            ],
    );
  }

  @override
  Future<Recurrence> updateRecurrence(
    String recurrenceId,
    RecurrenceInput input, {
    Recurrence? current,
  }) async {
    _maybeThrow();
    final created = await createRecurrence(input);
    return Recurrence(
      id: recurrenceId,
      type: created.type,
      title: created.title,
      description: created.description,
      firstDate: created.firstDate,
      repeatUntil: created.repeatUntil,
      nrOfRepetitions: created.nrOfRepetitions,
      applyRules: created.applyRules,
      active: created.active,
      notes: created.notes,
      repetitions: created.repetitions,
      transactions: created.transactions,
    );
  }

  @override
  Future<void> deleteRecurrence(String recurrenceId) async {
    _maybeThrow();
  }

  @override
  Future<List<PiggyBank>> getPiggyBanks() async {
    _maybeThrow();
    return piggyBanks;
  }

  @override
  Future<PiggyBank> createPiggyBank(PiggyBankInput input) async {
    _maybeThrow();
    return PiggyBank(
      id: 'new-${piggyBanks.length + 1}',
      name: input.name,
      targetAmount: input.targetAmount,
      currentAmount: 0,
      currencyCode: input.currencyCode,
      currencySymbol: _primaryCurrency.symbol,
      startDate: input.startDate,
      targetDate: input.targetDate,
      notes: input.notes,
      objectGroupTitle: input.objectGroupTitle,
      accounts: input.accountIds
          .map(
            (id) => PiggyBankAccountLink(
              accountId: id,
              name: 'Account $id',
              currentAmount: 0,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<PiggyBank> updatePiggyBank(
    String piggyBankId,
    PiggyBankInput input,
  ) async {
    _maybeThrow();
    final existing = piggyBanks.where((p) => p.id == piggyBankId).firstOrNull;
    return PiggyBank(
      id: piggyBankId,
      name: input.name,
      targetAmount: input.targetAmount,
      currentAmount: existing?.currentAmount ?? 0,
      currencyCode: existing?.currencyCode ?? input.currencyCode,
      currencySymbol: existing?.currencySymbol ?? _primaryCurrency.symbol,
      startDate: input.startDate,
      targetDate: input.targetDate,
      notes: input.notes,
      objectGroupTitle: input.objectGroupTitle,
      accounts: input.accountIds
          .map(
            (id) => PiggyBankAccountLink(
              accountId: id,
              name: 'Account $id',
              currentAmount: 0,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<void> deletePiggyBank(String piggyBankId) async {
    _maybeThrow();
  }

  @override
  Future<Transaction> createTransaction(Transaction transaction) async {
    final error = createTransactionError;
    if (error != null) throw error;
    _maybeThrow();
    final created = transaction.copyWith(id: 'new-${transactions.length + 1}');
    // Keep list/page fixtures in sync so post-create refreshes see the row.
    // Fixture maps/lists may be const; ignore when they cannot grow.
    try {
      transactions.add(created);
    } on UnsupportedError {
      // Immutable fixture list.
    }
    try {
      final pageOne = transactionPages[1];
      if (pageOne != null) {
        transactionPages[1] = TransactionPageResult(
          transactions: [...pageOne.transactions, created],
          currentPage: pageOne.currentPage,
          totalPages: pageOne.totalPages,
          total: pageOne.total + 1,
        );
      }
    } on UnsupportedError {
      // Immutable fixture map.
    }
    for (final accountId in {
      if (created.sourceId != null && created.sourceId!.isNotEmpty)
        created.sourceId!,
      if (created.destinationId != null && created.destinationId!.isNotEmpty)
        created.destinationId!,
    }) {
      try {
        final pages = accountTransactionPages.putIfAbsent(accountId, () => {});
        final accountPageOne = pages[1];
        if (accountPageOne == null) {
          pages[1] = TransactionPageResult(
            transactions: [created],
            currentPage: 1,
            totalPages: 1,
            total: 1,
          );
        } else {
          pages[1] = TransactionPageResult(
            transactions: [...accountPageOne.transactions, created],
            currentPage: accountPageOne.currentPage,
            totalPages: accountPageOne.totalPages,
            total: accountPageOne.total + 1,
          );
        }
      } on UnsupportedError {
        // Immutable fixture map.
      }
    }
    return created;
  }

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    _maybeThrow();
    updatedTransactions.add(transaction);
    return transaction;
  }

  final Map<String, dynamic> preferences = {};

  @override
  Future<void> deleteTransaction(String transactionId) async {
    _maybeThrow();
  }

  @override
  Future<dynamic> getPreference(String name) async {
    _maybeThrow();
    return preferences[name];
  }

  @override
  Future<void> setPreference(String name, dynamic data) async {
    _maybeThrow();
    preferences[name] = data;
  }

  /// CSV keyed by data set, plus the windows each export was asked for.
  final Map<FireflyCsvDataset, String> csvExports = {};
  final List<({FireflyCsvDataset dataset, DateTime? start, DateTime? end})>
  csvExportCalls = [];

  @override
  Future<String> exportCsv(
    FireflyCsvDataset dataset, {
    DateTime? start,
    DateTime? end,
  }) async {
    _maybeThrow();
    csvExportCalls.add((dataset: dataset, start: start, end: end));
    return csvExports[dataset] ?? 'id,name\n';
  }

  void _maybeThrow() {
    if (throwOn != null) throw throwOn!;
  }
}
