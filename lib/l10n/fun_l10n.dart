import 'app_localizations.dart';

/// Playful Racoon Mode labels — menus, accounts, heists, hoards, etc.
class FunL10n {
  const FunL10n(this.l10n, {required this.isRacoon});

  final AppLocalizations l10n;
  final bool isRacoon;

  String _pick(String normal, String racoon) => isRacoon ? racoon : normal;

  // Navigation
  String get navDashboard => _pick(l10n.navDashboard, l10n.navDashboardRacoon);
  String get navDashboardShort =>
      _pick(l10n.navDashboardShort, l10n.navDashboardShortRacoon);
  String get navAccounts => _pick(l10n.navAccounts, l10n.navAccountsRacoon);
  String get navTransactions =>
      _pick(l10n.navTransactions, l10n.navTransactionsRacoon);
  String get navBudgets => _pick(l10n.navBudgets, l10n.navBudgetsRacoon);
  String get navSubscriptions =>
      _pick(l10n.navSubscriptions, l10n.navSubscriptionsRacoon);
  String get navPiggyBanks =>
      _pick(l10n.navPiggyBanks, l10n.navPiggyBanksRacoon);
  String get navExpenses => _pick(l10n.navExpenses, l10n.navExpensesRacoon);
  String get navIncome => _pick(l10n.navIncome, l10n.navIncomeRacoon);
  String get navTransfers => _pick(l10n.navTransfers, l10n.navTransfersRacoon);
  String get navLiabilities =>
      _pick(l10n.navLiabilities, l10n.navLiabilitiesRacoon);
  String get navProjection =>
      _pick(l10n.navProjection, l10n.navProjectionRacoon);
  String get navPrognosis => _pick(l10n.navPrognosis, l10n.navPrognosisRacoon);
  String get navSettings => _pick(l10n.navSettings, l10n.navSettingsRacoon);
  String get navHistory => _pick(l10n.navHistory, l10n.navHistoryRacoon);

  // Screen titles
  String get accountsTitle =>
      _pick(l10n.accountsTitle, l10n.accountsTitleRacoon);
  String get transactionsTitle =>
      _pick(l10n.transactionsTitle, l10n.transactionsTitleRacoon);
  String get budgetsTitle => _pick(l10n.budgetsTitle, l10n.budgetsTitleRacoon);
  String get subscriptionsTitle =>
      _pick(l10n.subscriptionsTitle, l10n.subscriptionsTitleRacoon);
  String get piggyBanksTitle =>
      _pick(l10n.piggyBanksTitle, l10n.piggyBanksTitleRacoon);
  String get expensesTitle =>
      _pick(l10n.expensesTitle, l10n.expensesTitleRacoon);
  String get incomeTitle => _pick(l10n.incomeTitle, l10n.incomeTitleRacoon);
  String get transfersTitle =>
      _pick(l10n.transfersTitle, l10n.transfersTitleRacoon);
  String get liabilitiesTitle =>
      _pick(l10n.liabilitiesTitle, l10n.liabilitiesTitleRacoon);
  String get projectionTitle =>
      _pick(l10n.projectionTitle, l10n.projectionTitleRacoon);
  String get settingsTitle =>
      _pick(l10n.settingsTitle, l10n.settingsTitleRacoon);

  // Dashboard tabs & KPIs
  String get tabInsights => _pick(l10n.tabInsights, l10n.tabInsightsRacoon);
  String get tabAccounts => _pick(l10n.tabAccounts, l10n.tabAccountsRacoon);
  String get tabFocus => _pick(l10n.tabFocus, l10n.tabFocusRacoon);
  String get totalBalance => _pick(l10n.totalBalance, l10n.totalBalanceRacoon);
  String get netWorth => _pick(l10n.netWorth, l10n.netWorthRacoon);
  String get search => _pick(l10n.search, l10n.searchRacoon);

  String kpiIncome(String month) =>
      isRacoon ? l10n.snatchedFunds : l10n.incomeMonth(month);
  String kpiSpending(String month) =>
      isRacoon ? l10n.burntCash : l10n.spendingMonth(month);
  String kpiSaved(String month) =>
      isRacoon ? l10n.stash : l10n.savedMonth(month);

  String incomeMonth(String month) =>
      isRacoon ? l10n.incomeMonthRacoon(month) : l10n.incomeMonth(month);
  String spendingMonth(String month) =>
      isRacoon ? l10n.spendingMonthRacoon(month) : l10n.spendingMonth(month);
  String savedMonth(String month) =>
      isRacoon ? l10n.savedMonthRacoon(month) : l10n.savedMonth(month);

  String get income => isRacoon ? l10n.snatched : l10n.income;
  String get spending => isRacoon ? l10n.burnt : l10n.spending;
  String get saved => isRacoon ? l10n.stash : l10n.saved;

  // Dashboard sections
  String get cashFlow => _pick(l10n.cashFlow, l10n.cashFlowRacoon);
  String get whereMoneyGoes =>
      _pick(l10n.whereMoneyGoes, l10n.whereMoneyGoesRacoon);
  String get recentActivity =>
      _pick(l10n.recentActivity, l10n.recentActivityRacoon);
  String get yourAccounts => _pick(l10n.yourAccounts, l10n.yourAccountsRacoon);
  String get budgetsAtGlance =>
      _pick(l10n.budgetsAtGlance, l10n.budgetsAtGlanceRacoon);
  String get viewAllAccounts =>
      _pick(l10n.viewAllAccounts, l10n.viewAllAccountsRacoon);
  String get lookingAhead => _pick(l10n.lookingAhead, l10n.lookingAheadRacoon);
  String get openProjection =>
      _pick(l10n.openProjection, l10n.openProjectionRacoon);
  String get noTransactionsYet =>
      _pick(l10n.noTransactionsYet, l10n.noTransactionsYetRacoon);

  // Accounts
  String get assetAccounts =>
      _pick(l10n.assetAccounts, l10n.assetAccountsRacoon);
  String get savingsAccounts => _pick('Savings Accounts', 'Savings Stashes');
  String get creditCardAccounts => _pick('Credit Cards', 'Credit Card Stashes');
  String get liabilityAccounts =>
      _pick(l10n.liabilityAccounts, l10n.liabilityAccountsRacoon);
  String get stocksAndFundsAccounts =>
      _pick(l10n.stocksAndFundsAccounts, l10n.stocksAndFundsAccountsRacoon);
  String get allAccounts => _pick(l10n.allAccounts, l10n.allAccountsRacoon);
  String get accounts => _pick(l10n.accounts, l10n.accountsRacoon);
  String get editAccount => _pick(l10n.editAccount, l10n.editAccountRacoon);
  String get accountName => _pick(l10n.accountName, l10n.accountNameRacoon);
  String get filterAccount =>
      _pick(l10n.filterAccount, l10n.filterAccountRacoon);
  String get sourceAccount =>
      _pick(l10n.sourceAccount, l10n.sourceAccountRacoon);
  String get destinationAccount =>
      _pick(l10n.destinationAccount, l10n.destinationAccountRacoon);

  // Transactions
  String get newTransaction =>
      _pick(l10n.newTransaction, l10n.newTransactionRacoon);
  String get editTransaction =>
      _pick(l10n.editTransaction, l10n.editTransactionRacoon);
  String transactionsCount(int count) => isRacoon
      ? l10n.transactionsCountRacoon(count)
      : l10n.transactionsCount(count);
  String get oneTransaction =>
      _pick(l10n.oneTransaction, l10n.oneTransactionRacoon);
  String get expenseLabel => _pick(l10n.expenseLabel, l10n.expenseLabelRacoon);
  String get transfers => _pick(l10n.transfers, l10n.transfersRacoon);
  String get expensesFilter =>
      _pick(l10n.expensesFilter, l10n.expensesFilterRacoon);

  String transactionType(String type) => switch (type) {
    'deposit' =>
      isRacoon
          ? l10n.transactionTypeDepositRacoon
          : l10n.transactionTypeDeposit,
    'withdrawal' =>
      isRacoon
          ? l10n.transactionTypeWithdrawalRacoon
          : l10n.transactionTypeWithdrawal,
    'transfer' =>
      isRacoon
          ? l10n.transactionTypeTransferRacoon
          : l10n.transactionTypeTransfer,
    _ => type,
  };

  String totalForFilter(String filterName) => switch (filterName) {
    'expense' => isRacoon ? l10n.totalSpentPeriodRacoon : l10n.totalSpentPeriod,
    'income' =>
      isRacoon ? l10n.totalIncomePeriodRacoon : l10n.totalIncomePeriod,
    'transfer' =>
      isRacoon
          ? l10n.totalTransferredPeriodRacoon
          : l10n.totalTransferredPeriod,
    _ => l10n.totalPeriod,
  };

  // Budgets & projection
  String get spent => _pick(l10n.spent, l10n.spentRacoon);
  String get newBudget => _pick(l10n.newBudget, l10n.newBudgetRacoon);
  String get newSubscription =>
      _pick(l10n.newSubscription, l10n.newSubscriptionRacoon);
  String get newPiggyBank => _pick(l10n.newPiggyBank, l10n.newPiggyBankRacoon);
  String get newAccount => _pick(l10n.newAccount, l10n.newAccountRacoon);
  String get newExpense => _pick(l10n.newExpense, l10n.newExpenseRacoon);
  String get newIncome => _pick(l10n.newIncome, l10n.newIncomeRacoon);
  String get newTransfer =>
      _pick(l10n.newTransferAction, l10n.newTransferActionRacoon);
  String get newLiability => _pick(l10n.newLiability, l10n.newLiabilityRacoon);
  String get projectedBalance =>
      _pick(l10n.projectedBalance, l10n.projectedBalanceRacoon);
  String get piggyBank => _pick(l10n.piggyBank, l10n.piggyBankRacoon);
}
