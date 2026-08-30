import 'app_localizations.dart';

/// Playful Raccoon Mode labels — menus, accounts, heists, hoards, etc.
class FunL10n {
  const FunL10n(this.l10n, {required this.isRaccoon});

  final AppLocalizations l10n;
  final bool isRaccoon;

  String _pick(String normal, String raccoon) => isRaccoon ? raccoon : normal;

  // Navigation
  String get navDashboard => _pick(l10n.navDashboard, l10n.navDashboardRaccoon);
  String get navDashboardShort =>
      _pick(l10n.navDashboardShort, l10n.navDashboardShortRaccoon);
  String get navAccounts => _pick(l10n.navAccounts, l10n.navAccountsRaccoon);
  String get navTransactions =>
      _pick(l10n.navTransactions, l10n.navTransactionsRaccoon);
  String get navBudgets => _pick(l10n.navBudgets, l10n.navBudgetsRaccoon);
  String get navSubscriptions =>
      _pick(l10n.navSubscriptions, l10n.navSubscriptionsRaccoon);
  String get navPiggyBanks =>
      _pick(l10n.navPiggyBanks, l10n.navPiggyBanksRaccoon);
  String get navExpenses => _pick(l10n.navExpenses, l10n.navExpensesRaccoon);
  String get navIncome => _pick(l10n.navIncome, l10n.navIncomeRaccoon);
  String get navTransfers => _pick(l10n.navTransfers, l10n.navTransfersRaccoon);
  String get navLiabilities =>
      _pick(l10n.navLiabilities, l10n.navLiabilitiesRaccoon);
  String get navProjection =>
      _pick(l10n.navProjection, l10n.navProjectionRaccoon);
  String get navPrognosis => _pick(l10n.navPrognosis, l10n.navPrognosisRaccoon);
  String get navSettings => _pick(l10n.navSettings, l10n.navSettingsRaccoon);
  String get navHistory => _pick(l10n.navHistory, l10n.navHistoryRaccoon);

  // Screen titles
  String get accountsTitle =>
      _pick(l10n.accountsTitle, l10n.accountsTitleRaccoon);
  String get transactionsTitle =>
      _pick(l10n.transactionsTitle, l10n.transactionsTitleRaccoon);
  String get budgetsTitle => _pick(l10n.budgetsTitle, l10n.budgetsTitleRaccoon);
  String get subscriptionsTitle =>
      _pick(l10n.subscriptionsTitle, l10n.subscriptionsTitleRaccoon);
  String get piggyBanksTitle =>
      _pick(l10n.piggyBanksTitle, l10n.piggyBanksTitleRaccoon);
  String get expensesTitle =>
      _pick(l10n.expensesTitle, l10n.expensesTitleRaccoon);
  String get incomeTitle => _pick(l10n.incomeTitle, l10n.incomeTitleRaccoon);
  String get transfersTitle =>
      _pick(l10n.transfersTitle, l10n.transfersTitleRaccoon);
  String get liabilitiesTitle =>
      _pick(l10n.liabilitiesTitle, l10n.liabilitiesTitleRaccoon);
  String get projectionTitle =>
      _pick(l10n.projectionTitle, l10n.projectionTitleRaccoon);
  String get settingsTitle =>
      _pick(l10n.settingsTitle, l10n.settingsTitleRaccoon);

  // Dashboard tabs & KPIs
  String get tabInsights => _pick(l10n.tabInsights, l10n.tabInsightsRaccoon);
  String get tabAccounts => _pick(l10n.tabAccounts, l10n.tabAccountsRaccoon);
  String get tabFocus => _pick(l10n.tabFocus, l10n.tabFocusRaccoon);
  String get totalBalance => _pick(l10n.totalBalance, l10n.totalBalanceRaccoon);
  String get netWorth => _pick(l10n.netWorth, l10n.netWorthRaccoon);
  String get search => _pick(l10n.search, l10n.searchRaccoon);

  String kpiIncome(String month) =>
      isRaccoon ? l10n.snatchedFunds : l10n.incomeMonth(month);
  String kpiSpending(String month) =>
      isRaccoon ? l10n.burntCash : l10n.spendingMonth(month);
  String kpiSaved(String month) =>
      isRaccoon ? l10n.stash : l10n.savedMonth(month);

  String incomeMonth(String month) =>
      isRaccoon ? l10n.incomeMonthRaccoon(month) : l10n.incomeMonth(month);
  String spendingMonth(String month) =>
      isRaccoon ? l10n.spendingMonthRaccoon(month) : l10n.spendingMonth(month);
  String savedMonth(String month) =>
      isRaccoon ? l10n.savedMonthRaccoon(month) : l10n.savedMonth(month);

  String get income => isRaccoon ? l10n.snatched : l10n.income;
  String get spending => isRaccoon ? l10n.burnt : l10n.spending;
  String get saved => isRaccoon ? l10n.stash : l10n.saved;

  // Dashboard sections
  String get cashFlow => _pick(l10n.cashFlow, l10n.cashFlowRaccoon);
  String get whereMoneyGoes =>
      _pick(l10n.whereMoneyGoes, l10n.whereMoneyGoesRaccoon);
  String get recentActivity =>
      _pick(l10n.recentActivity, l10n.recentActivityRaccoon);
  String get yourAccounts => _pick(l10n.yourAccounts, l10n.yourAccountsRaccoon);
  String get budgetsAtGlance =>
      _pick(l10n.budgetsAtGlance, l10n.budgetsAtGlanceRaccoon);
  String get viewAllAccounts =>
      _pick(l10n.viewAllAccounts, l10n.viewAllAccountsRaccoon);
  String get lookingAhead => _pick(l10n.lookingAhead, l10n.lookingAheadRaccoon);
  String get openProjection =>
      _pick(l10n.openProjection, l10n.openProjectionRaccoon);
  String get noTransactionsYet =>
      _pick(l10n.noTransactionsYet, l10n.noTransactionsYetRaccoon);

  // Accounts
  String get assetAccounts =>
      _pick(l10n.assetAccounts, l10n.assetAccountsRaccoon);
  String get savingsAccounts => _pick('Savings Accounts', 'Savings Stashes');
  String get creditCardAccounts => _pick('Credit Cards', 'Credit Card Stashes');
  String get liabilityAccounts =>
      _pick(l10n.liabilityAccounts, l10n.liabilityAccountsRaccoon);
  String get stocksAndFundsAccounts =>
      _pick(l10n.stocksAndFundsAccounts, l10n.stocksAndFundsAccountsRaccoon);
  String get allAccounts => _pick(l10n.allAccounts, l10n.allAccountsRaccoon);
  String get accounts => _pick(l10n.accounts, l10n.accountsRaccoon);
  String get editAccount => _pick(l10n.editAccount, l10n.editAccountRaccoon);
  String get accountName => _pick(l10n.accountName, l10n.accountNameRaccoon);
  String get filterAccount =>
      _pick(l10n.filterAccount, l10n.filterAccountRaccoon);
  String get sourceAccount =>
      _pick(l10n.sourceAccount, l10n.sourceAccountRaccoon);
  String get destinationAccount =>
      _pick(l10n.destinationAccount, l10n.destinationAccountRaccoon);

  // Transactions
  String get newTransaction =>
      _pick(l10n.newTransaction, l10n.newTransactionRaccoon);
  String get editTransaction =>
      _pick(l10n.editTransaction, l10n.editTransactionRaccoon);
  String transactionsCount(int count) => isRaccoon
      ? l10n.transactionsCountRaccoon(count)
      : l10n.transactionsCount(count);
  String get oneTransaction =>
      _pick(l10n.oneTransaction, l10n.oneTransactionRaccoon);
  String get expenseLabel => _pick(l10n.expenseLabel, l10n.expenseLabelRaccoon);
  String get transfers => _pick(l10n.transfers, l10n.transfersRaccoon);
  String get expensesFilter =>
      _pick(l10n.expensesFilter, l10n.expensesFilterRaccoon);

  String transactionType(String type) => switch (type) {
    'deposit' =>
      isRaccoon
          ? l10n.transactionTypeDepositRaccoon
          : l10n.transactionTypeDeposit,
    'withdrawal' =>
      isRaccoon
          ? l10n.transactionTypeWithdrawalRaccoon
          : l10n.transactionTypeWithdrawal,
    'transfer' =>
      isRaccoon
          ? l10n.transactionTypeTransferRaccoon
          : l10n.transactionTypeTransfer,
    _ => type,
  };

  String totalForFilter(String filterName) => switch (filterName) {
    'expense' =>
      isRaccoon ? l10n.totalSpentPeriodRaccoon : l10n.totalSpentPeriod,
    'income' =>
      isRaccoon ? l10n.totalIncomePeriodRaccoon : l10n.totalIncomePeriod,
    'transfer' =>
      isRaccoon
          ? l10n.totalTransferredPeriodRaccoon
          : l10n.totalTransferredPeriod,
    _ => l10n.totalPeriod,
  };

  // Budgets & projection
  String get spent => _pick(l10n.spent, l10n.spentRaccoon);
  String get newBudget => _pick(l10n.newBudget, l10n.newBudgetRaccoon);
  String get newSubscription =>
      _pick(l10n.newSubscription, l10n.newSubscriptionRaccoon);
  String get newPiggyBank => _pick(l10n.newPiggyBank, l10n.newPiggyBankRaccoon);
  String get newAccount => _pick(l10n.newAccount, l10n.newAccountRaccoon);
  String get newExpense => _pick(l10n.newExpense, l10n.newExpenseRaccoon);
  String get newIncome => _pick(l10n.newIncome, l10n.newIncomeRaccoon);
  String get newTransfer =>
      _pick(l10n.newTransferAction, l10n.newTransferActionRaccoon);
  String get newLiability => _pick(l10n.newLiability, l10n.newLiabilityRaccoon);
  String get projectedBalance =>
      _pick(l10n.projectedBalance, l10n.projectedBalanceRaccoon);
  String get piggyBank => _pick(l10n.piggyBank, l10n.piggyBankRaccoon);
}
