// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FireRacoon';

  @override
  String get appTagline => 'The brightest bandit for your budget.';

  @override
  String get appNameFire => 'Fire';

  @override
  String get appNameRacoon => 'Racoon';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navDashboardShort => 'Dash';

  @override
  String get navAccounts => 'Accounts';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navBudgets => 'Budgets';

  @override
  String get navSubscriptions => 'Subscriptions & Recurring';

  @override
  String get navPiggyBanks => 'Piggy banks';

  @override
  String get navExpenses => 'Expenses';

  @override
  String get navIncome => 'Income';

  @override
  String get navTransfers => 'Transfers';

  @override
  String get navLiabilities => 'Liabilities';

  @override
  String get navProjection => 'Projection';

  @override
  String get navPrognosis => 'Prognosis';

  @override
  String get navSettings => 'Settings';

  @override
  String get netWorth => 'Net worth';

  @override
  String get search => 'Search...';

  @override
  String get loading => 'Loading…';

  @override
  String get fireflyUser => 'Firefly user';

  @override
  String get fireflyConnected => 'Firefly III · connected';

  @override
  String get fireflyDisconnected => 'Firefly III · disconnected';

  @override
  String get fireflyConnectionChecking => 'Firefly III · checking…';

  @override
  String get settingsTitle => 'Settings';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageSwedish => 'Svenska';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageJapanese => '日本語';

  @override
  String get defaultCurrency => 'Default Currency';

  @override
  String get selectCurrency => 'Select currency';

  @override
  String get primaryCurrencyChangeWarning =>
      'Firefly III may recalculate stored amounts when the default currency changes.';

  @override
  String primaryCurrencyChanged(String code) {
    return 'Default currency set to $code';
  }

  @override
  String failedToSetPrimaryCurrency(String error) {
    return 'Failed to set default currency: $error';
  }

  @override
  String get primaryCurrencyCurrent => 'Current';

  @override
  String get changePrimaryCurrencyTitle => 'Change default currency';

  @override
  String changePrimaryCurrencyMessage(String code, String warning) {
    return 'Change the default currency to $code? $warning';
  }

  @override
  String get changePrimaryCurrencyConfirm => 'Change';

  @override
  String get connectToFireflyToLoad => 'Connect to Firefly III to load';

  @override
  String get managedInFirefly => 'Managed in Firefly III';

  @override
  String get appearance => 'Appearance';

  @override
  String get racoonMode => 'Racoon Mode';

  @override
  String get themeStyle => 'Theme Style';

  @override
  String get themeStyleSubtitle =>
      'Pick a palette, accent colour, and brightness. Changes apply instantly.';

  @override
  String get systemDefault => 'System Default';

  @override
  String get themeBrightness => 'Brightness';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themePalette => 'Palette';

  @override
  String get paletteClassic => 'Classic';

  @override
  String get paletteSpectrum => 'Spectrum';

  @override
  String get paletteRaccoon => 'Raccoon';

  @override
  String get themeAccentColor => 'Accent colour';

  @override
  String get themePreview => 'Preview';

  @override
  String get done => 'Done';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentRed => 'Red';

  @override
  String get accentViolet => 'Violet';

  @override
  String get accentLime => 'Lime';

  @override
  String get accentSky => 'Sky';

  @override
  String get accentCharcoal => 'Charcoal';

  @override
  String get accentSilver => 'Silver';

  @override
  String get accentTan => 'Tan';

  @override
  String get accentAmber => 'Amber';

  @override
  String get accentSlate => 'Slate';

  @override
  String get accentMidnight => 'Midnight';

  @override
  String get accentSmoke => 'Smoke';

  @override
  String get accentPearl => 'Pearl';

  @override
  String get backendConnection => 'Backend Connection (Firefly III)';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get notConnected => 'Not connected';

  @override
  String get oauth2Connection => 'OAuth2 Connection';

  @override
  String get personalAccessToken => 'Personal Access Token';

  @override
  String get notSet => 'Not set';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get fireflyConnectionTitle => 'Firefly III Connection';

  @override
  String get serverUrlLabel =>
      'Server URL (e.g. https://firefly.my-domain.com)';

  @override
  String get allowHttpConnections => 'Allow HTTP connections';

  @override
  String get authenticationMethod => 'Authentication Method';

  @override
  String get oauth2 => 'OAuth2';

  @override
  String get oauthClientId => 'OAuth Client ID';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get connectionSuccessful => 'Connection successful!';

  @override
  String get connectionFailed =>
      'Connection failed. Please check your URL and Token.';

  @override
  String get loginViaBrowser => 'Login via Browser';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String errorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String errorLoadingData(String error) {
    return 'Error loading data: $error';
  }

  @override
  String get tabInsights => 'Insights';

  @override
  String get tabAccounts => 'Accounts';

  @override
  String get tabFocus => 'Focus';

  @override
  String get totalBalance => 'Total balance';

  @override
  String incomeMonth(String month) {
    return 'Income · $month';
  }

  @override
  String spendingMonth(String month) {
    return 'Spending · $month';
  }

  @override
  String savedMonth(String month) {
    return 'Saved · $month';
  }

  @override
  String get snatchedFunds => 'Snatched Funds';

  @override
  String get burntCash => 'Burnt Cash';

  @override
  String get stash => 'Stash';

  @override
  String get snatched => 'Snatched';

  @override
  String get burnt => 'Burnt';

  @override
  String get navDashboardRacoon => 'The Den';

  @override
  String get navDashboardShortRacoon => 'Den';

  @override
  String get navAccountsRacoon => 'Stashes';

  @override
  String get navTransactionsRacoon => 'Heist Log';

  @override
  String get navBudgetsRacoon => 'Hoard Plans';

  @override
  String get navSubscriptionsRacoon => 'Recurring Raids';

  @override
  String get navPiggyBanksRacoon => 'Mini Stashes';

  @override
  String get navExpensesRacoon => 'Burn Report';

  @override
  String get navProjectionRacoon => 'Crystal Stash';

  @override
  String get navPrognosisRacoon => 'Month-end loot';

  @override
  String get navSettingsRacoon => 'Den Rules';

  @override
  String get netWorthRacoon => 'Total Hoard';

  @override
  String get searchRacoon => 'Sniff around…';

  @override
  String get accountsTitleRacoon => 'Stashes';

  @override
  String get transactionsTitleRacoon => 'Heist Log';

  @override
  String get budgetsTitleRacoon => 'Hoard Plans';

  @override
  String get expensesTitleRacoon => 'Burn Report';

  @override
  String get projectionTitleRacoon => 'Crystal Stash';

  @override
  String get settingsTitleRacoon => 'Den Rules';

  @override
  String get tabInsightsRacoon => 'Loot Intel';

  @override
  String get tabAccountsRacoon => 'Stashes';

  @override
  String get tabFocusRacoon => 'Heist HQ';

  @override
  String get totalBalanceRacoon => 'Full Stash';

  @override
  String incomeMonthRacoon(String month) {
    return 'Snatched · $month';
  }

  @override
  String spendingMonthRacoon(String month) {
    return 'Burnt · $month';
  }

  @override
  String savedMonthRacoon(String month) {
    return 'Stashed · $month';
  }

  @override
  String get cashFlowRacoon => 'Loot Flow';

  @override
  String get whereMoneyGoesRacoon => 'Where loot goes';

  @override
  String get recentActivityRacoon => 'Recent Raids';

  @override
  String get yourAccountsRacoon => 'Your Stashes';

  @override
  String get budgetsAtGlanceRacoon => 'Hoard at a glance';

  @override
  String get viewAllAccountsRacoon => 'All stashes';

  @override
  String get assetAccountsRacoon => 'Treasure Stashes';

  @override
  String get liabilityAccountsRacoon => 'Debts & IOUs';

  @override
  String get stocksAndFundsAccountsRacoon => 'Market Stashes';

  @override
  String get allAccountsRacoon => 'All Stashes';

  @override
  String get accountsRacoon => 'Stashes';

  @override
  String get newTransactionRacoon => 'Plan a Heist';

  @override
  String get editTransactionRacoon => 'Edit Heist';

  @override
  String transactionsCountRacoon(int count) {
    return '$count heists';
  }

  @override
  String get oneTransactionRacoon => '1 heist';

  @override
  String get transactionTypeDepositRacoon => 'Snatch';

  @override
  String get transactionTypeWithdrawalRacoon => 'Burn';

  @override
  String get transactionTypeTransferRacoon => 'Stash Shuffle';

  @override
  String get expenseLabelRacoon => 'Burn';

  @override
  String get spentRacoon => 'Burnt';

  @override
  String get newBudgetRacoon => 'New Hoard Plan';

  @override
  String get projectedBalanceRacoon => 'Future Hoard';

  @override
  String get piggyBankRacoon => 'Mini Stash';

  @override
  String get transfersRacoon => 'Stash Shuffles';

  @override
  String get expensesFilterRacoon => 'Burns';

  @override
  String get noTransactionsYetRacoon => 'No heists yet';

  @override
  String get lookingAheadRacoon => 'Peeking Ahead';

  @override
  String get openProjectionRacoon => 'Peek the Future';

  @override
  String get editAccountRacoon => 'Edit Stash';

  @override
  String get accountNameRacoon => 'Stash name';

  @override
  String get filterAccountRacoon => 'Filter Stash';

  @override
  String get sourceAccountRacoon => 'From Stash';

  @override
  String get destinationAccountRacoon => 'To Stash';

  @override
  String get totalSpentPeriodRacoon => 'Total burnt this period';

  @override
  String get totalIncomePeriodRacoon => 'Total snatched this period';

  @override
  String get totalTransferredPeriodRacoon => 'Total shuffled this period';

  @override
  String get newAccount => 'New Account';

  @override
  String get newLiability => 'New Liability';

  @override
  String get newExpense => 'New Expense';

  @override
  String get newAccountRacoon => 'New Stash';

  @override
  String get newLiabilityRacoon => 'New IOU';

  @override
  String get newExpenseRacoon => 'Plan a Burn';

  @override
  String get income => 'Income';

  @override
  String get spending => 'Spending';

  @override
  String get saved => 'Saved';

  @override
  String get cashFlow => 'Cash flow';

  @override
  String get whereMoneyGoes => 'Where money goes';

  @override
  String get noSpendingThisMonth => 'No spending this month yet';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get viewAll => 'View all';

  @override
  String get noTransactionsYet => 'No transactions yet';

  @override
  String get lookingAhead => 'Looking ahead';

  @override
  String get spendingPaceWarning =>
      'Spending pace may exceed income this month';

  @override
  String get openProjection => 'Open projection';

  @override
  String get yourAccounts => 'Your Accounts';

  @override
  String get budgetsAtGlance => 'Budgets at a glance';

  @override
  String get viewAllAccounts => 'View all accounts';

  @override
  String get thirtyDayOutlook => '30-day outlook';

  @override
  String get monthEndPrognosis => 'Month-end prognosis';

  @override
  String get projectedEndOfMonth => 'End of month';

  @override
  String get includeCreditCardPayments => 'Include credit card payments';

  @override
  String prognosisDeltaPositive(String amount) {
    return '+$amount expected';
  }

  @override
  String prognosisDeltaNegative(String amount) {
    return '$amount expected';
  }

  @override
  String get prognosisLowBalanceWarning => 'Projected balance may go negative';

  @override
  String get prognosisDebtWarning => 'Projected debt may increase';

  @override
  String get openPrognosis => 'Open prognosis';

  @override
  String get prognosisMarginLabel => 'Margin of error';

  @override
  String prognosisMarginDetail(String percent) {
    return '±$percent% uncertainty on amounts';
  }

  @override
  String get prognosisIncludeScheduled => 'Scheduled transactions';

  @override
  String get prognosisIncludeRecurring => 'Recurring transactions';

  @override
  String get prognosisIncludeBills => 'Subscriptions';

  @override
  String get prognosisIncludeIncome => 'Income';

  @override
  String get prognosisIncludeExpenses => 'Expenses';

  @override
  String get prognosisIncludeTransfers => 'Transfers';

  @override
  String get prognosisIncludeCreditCards => 'Credit cards';

  @override
  String get prognosisEndOfNextMonth => 'End of next month';

  @override
  String get prognosisMinBalance => 'Min prognosis';

  @override
  String get prognosisMaxBalance => 'Max prognosis';

  @override
  String get prognosisExpectedBalance => 'Expected';

  @override
  String get prognosisSelectAccount => 'Account';

  @override
  String get prognosisBandLegend =>
      'Shaded band shows min–max range; line is expected';

  @override
  String get prognosisModeExpected => 'Real projection';

  @override
  String get prognosisModeProjected => 'Speculative projection';

  @override
  String get prognosisModeExpectedHint =>
      'Month-end balances from current balances, scheduled transactions, recurring items, and bills';

  @override
  String get prognosisModeProjectedHint =>
      'Trend-based forecast from historical net cash flow';

  @override
  String get prognosisHorizonLabel => 'Horizon';

  @override
  String get prognosisHorizonEndOfMonth => 'End of month';

  @override
  String get prognosisHorizonEndOfNextMonth => 'Next month';

  @override
  String get prognosisHorizonTwoMonths => '2 months';

  @override
  String get prognosisHorizonThreeMonths => '3 months';

  @override
  String get prognosisHorizonSixMonths => '6 months';

  @override
  String get prognosisHorizonOneYear => '1 year';

  @override
  String get prognosisHorizonThreeYears => '3 years';

  @override
  String get prognosisHorizonFiveYears => '5 years';

  @override
  String get prognosisHorizonTenYears => '10 years';

  @override
  String get prognosisMilestoneThreeMonths => 'End of 3 months';

  @override
  String get prognosisMilestoneSixMonths => 'End of 6 months';

  @override
  String get prognosisMilestoneOneYear => 'End of 1 year';

  @override
  String get prognosisIncludeSources => 'Include in forecast';

  @override
  String get prognosisIncludeLiabilities => 'Liabilities';

  @override
  String prognosisNegativeOn(String date) {
    return 'Negative on $date';
  }

  @override
  String get prognosisCurrentBalance => 'Current balance';

  @override
  String get prognosisPredictedBalances => 'Predicted balances';

  @override
  String get todaysTimeline => 'Today\'s timeline';

  @override
  String get noActivityToday => 'No activity today';

  @override
  String get noChangeVsLastMonth => 'No change vs last month';

  @override
  String get newActivityThisMonth => 'New activity this month';

  @override
  String percentVsLastMonth(String arrow, String percent) {
    return '$arrow$percent% vs last month';
  }

  @override
  String projectedSavingsHeadline(String amount) {
    return '$amount projected savings this month';
  }

  @override
  String onPaceDetail(String amount) {
    return 'On pace for $amount saved by month end';
  }

  @override
  String spendingOutpacingDetail(String amount) {
    return 'Spending is outpacing income by $amount';
  }

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get assetAccounts => 'Asset Accounts';

  @override
  String get stocksAndFundsAccounts => 'Stocks & Funds Accounts';

  @override
  String get liabilityAccounts => 'Liability Accounts';

  @override
  String get noAccountsFound => 'No accounts found.';

  @override
  String get allAccounts => 'All accounts';

  @override
  String get assetsOnly => 'Assets only';

  @override
  String get liabilitiesOnly => 'Liabilities only';

  @override
  String get accountName => 'Account name';

  @override
  String get accountRoleDefault => 'Checking account';

  @override
  String get accountRoleShared => 'Shared account';

  @override
  String get accountRoleSaving => 'Savings account';

  @override
  String get accountRoleCreditCard => 'Credit card';

  @override
  String get holdingAccountFundLabel => '(Fund)';

  @override
  String get holdingAccountStockLabel => '(Stock)';

  @override
  String failedToUpdate(String error) {
    return 'Failed to update: $error';
  }

  @override
  String get name => 'Name';

  @override
  String get transactionsTitle => 'Transactions';

  @override
  String filteredBy(String account) {
    return 'Filtered by: $account';
  }

  @override
  String get balance => 'Balance:';

  @override
  String get balanceCheckMode => 'Check balance';

  @override
  String get balanceCheckExpected => 'Expected balance';

  @override
  String get balanceCheckStatement => 'Your balance';

  @override
  String get balanceCheckStatementHint => 'Enter balance from your statement';

  @override
  String get balanceCheckMatch => 'Balances match';

  @override
  String balanceCheckDifference(String amount) {
    return 'Difference: $amount';
  }

  @override
  String get balanceCheckEnterBalance => 'Enter a balance to compare';

  @override
  String get balanceCheckInvalidAmount => 'Enter a valid amount';

  @override
  String get balanceCheckSelectedBalance => 'Balance from selected';

  @override
  String get balanceCheckReconcile => 'Reconcile selected';

  @override
  String get balanceCheckReconciled => 'Selected transactions reconciled';

  @override
  String get balanceCheckNothingToReconcile =>
      'Nothing to reconcile. Select unreconciled transactions to include them.';

  @override
  String get balanceCheckPaymentAccount => 'Payment account';

  @override
  String get balanceCheckPaybackDate => 'Payback date';

  @override
  String get balanceCheckSelectPaymentAccount => 'Select payment account';

  @override
  String get balanceCheckNoPaymentAccounts => 'No eligible payment accounts';

  @override
  String balanceCheckPaybackSummary(
    String amount,
    String account,
    String date,
  ) {
    return 'Payback: $amount from $account on $date';
  }

  @override
  String get balanceCheckPaybackReconciled =>
      'Purchases reconciled and payback transfer created';

  @override
  String get balanceCheckNoEligiblePurchases =>
      'Select at least one credit card purchase';

  @override
  String get tooltipBalanceCheckMode =>
      'Compare your statement balance with Firefly';

  @override
  String get tooltipBalanceCheckIncludePending => 'Include in balance check';

  @override
  String get tooltipBalanceCheckExcludeReconciled =>
      'Exclude from balance check';

  @override
  String get transactionReconciled => 'Reconciled';

  @override
  String get partiallyReconciled => 'Partially reconciled';

  @override
  String get tooltipTransactionReconciled =>
      'Verified against your bank statement';

  @override
  String get transactionReconciledUpdated => 'Reconciliation updated';

  @override
  String failedToUpdateReconciliation(String error) {
    return 'Failed to update reconciliation: $error';
  }

  @override
  String get reconciledFilter => 'Reconciliation';

  @override
  String get reconciledFilterAll => 'All transactions';

  @override
  String get reconciledFilterReconciled => 'Reconciled only';

  @override
  String get reconciledFilterUnreconciled => 'Unreconciled only';

  @override
  String get reconcile => 'Reconcile';

  @override
  String reconcileExpectedBalance(String amount) {
    return 'Expected balance: $amount';
  }

  @override
  String get reconcileClickHint => 'Click to reconcile';

  @override
  String get reconciliationTitle => 'Reconcile account';

  @override
  String get reconciliationSubtitle => 'Match your statement with Firefly III';

  @override
  String get reconciliationAccount => 'Account';

  @override
  String get reconciliationStartDate => 'Start date';

  @override
  String get reconciliationEndDate => 'End date';

  @override
  String get reconciliationStartBalance => 'Opening balance';

  @override
  String get reconciliationEndBalance => 'Closing balance';

  @override
  String get reconciliationStart => 'Start reconciling';

  @override
  String get reconciliationRestart => 'Restart';

  @override
  String get reconciliationOptions => 'Reconciliation options';

  @override
  String get reconciliationGapZero =>
      'Your checked transactions match the statement. You can store this reconciliation.';

  @override
  String reconciliationGapPositive(String amount) {
    return 'Firefly has $amount less than your statement. A correction transaction can be created when you store.';
  }

  @override
  String reconciliationGapNegative(String amount) {
    return 'Firefly has $amount more than your statement. A correction transaction can be created when you store.';
  }

  @override
  String get reconciliationStore => 'Store reconciliation';

  @override
  String get reconciliationStoreTitle => 'Store reconciliation?';

  @override
  String reconciliationStoreBody(int count) {
    return 'Mark $count transactions as reconciled.';
  }

  @override
  String get reconciliationCreateCorrectionTitle =>
      'Create correction transaction?';

  @override
  String reconciliationCreateCorrectionBody(String amount) {
    return 'There is a remaining difference of $amount. FireRacoon will create a reconciliation transaction to correct it.';
  }

  @override
  String get reconciliationStored => 'Reconciliation stored';

  @override
  String reconciliationStoreFailed(String error) {
    return 'Failed to store reconciliation: $error';
  }

  @override
  String get reconciliationSelectAccount =>
      'Select an asset account to reconcile';

  @override
  String get reconciliationInvalidBalances =>
      'Enter valid opening and closing balances';

  @override
  String get reconciliationInvalidDateRange =>
      'End date must be on or after the start date';

  @override
  String get reconciliationSelectTransactions =>
      'Check at least one transaction from your statement';

  @override
  String get reconciliationNoTransactions =>
      'No transactions found for this period';

  @override
  String get reconciliationUnreconciled => 'Unreconciled';

  @override
  String get reconciliationFutureTransaction => 'After period end';

  @override
  String get futureTransactions => 'Future transactions';

  @override
  String get reconciliationOpenWizard => 'Reconcile account';

  @override
  String get tooltipReconciliationWizard =>
      'Match transactions against your bank statement';

  @override
  String get reconciliationUseFireflyBalances => 'Use Firefly balances';

  @override
  String get reconciliationLoadingBalances => 'Loading balances from Firefly…';

  @override
  String get reconciliationBalancesFilled => 'Balances filled from Firefly';

  @override
  String reconciliationBalancesFailed(String error) {
    return 'Could not load balances: $error';
  }

  @override
  String get notAvailable => 'N/A';

  @override
  String get groupBy => 'Group By';

  @override
  String get groupByDate => 'Group by Date';

  @override
  String get groupByAccount => 'Group by Account';

  @override
  String get groupByPayee => 'Group by Payee';

  @override
  String get groupByType => 'Group by Type';

  @override
  String get groupByCategory => 'Group by Category';

  @override
  String get filterAccount => 'Filter Account';

  @override
  String get amount => 'Amount';

  @override
  String get accounts => 'Accounts';

  @override
  String get description => 'Description';

  @override
  String get sourceAccount => 'Source Account';

  @override
  String get destinationAccount => 'Destination Account';

  @override
  String get payee => 'Payee';

  @override
  String get savingNotSupported => 'Saving is not supported in read-only mode.';

  @override
  String transactionDateCategory(String category, String date) {
    return '$category · $date';
  }

  @override
  String foreignAmount(String amount) {
    return '($amount)';
  }

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String get subscriptionsTitle => 'Subscriptions & Recurring';

  @override
  String get newSubscription => 'New Subscription';

  @override
  String get createSubscription => 'Create Subscription';

  @override
  String get editSubscription => 'Edit Subscription';

  @override
  String get subscriptionCreated => 'Subscription created.';

  @override
  String subscriptionDeleted(String name) {
    return 'Subscription \"$name\" deleted.';
  }

  @override
  String failedToCreateSubscription(String error) {
    return 'Failed to create subscription: $error';
  }

  @override
  String failedToUpdateSubscription(String error) {
    return 'Failed to update subscription: $error';
  }

  @override
  String failedToDeleteSubscription(String error) {
    return 'Failed to delete subscription: $error';
  }

  @override
  String get deleteSubscription => 'Delete Subscription';

  @override
  String deleteSubscriptionConfirmBody(String name) {
    return 'Are you sure you want to delete the subscription \"$name\"? This action cannot be undone.';
  }

  @override
  String get noSubscriptionsFound => 'No subscriptions found.';

  @override
  String get subscriptionInactive => 'Inactive';

  @override
  String get subscriptionActive => 'Active';

  @override
  String get mandatoryFields => 'Mandatory fields';

  @override
  String get optionalFields => 'Optional fields';

  @override
  String get minimumAmount => 'Minimum amount';

  @override
  String get maximumAmount => 'Maximum amount';

  @override
  String get startDate => 'Start date';

  @override
  String get repeats => 'Repeats';

  @override
  String get skip => 'Skip';

  @override
  String get skipHelp =>
      'Use skip to create bi-monthly (skip = 1) or other custom intervals.';

  @override
  String get endDate => 'End date';

  @override
  String get endDateHelp =>
      'Optional. The subscription is expected to end on this date.';

  @override
  String get extensionDate => 'Extension date';

  @override
  String get extensionDateHelp =>
      'Optional. The subscription must be extended (or cancelled) on or before this date.';

  @override
  String get group => 'Group';

  @override
  String get notesMarkdownHint => 'This field supports Markdown.';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get repeatQuarterly => 'Quarterly';

  @override
  String get repeatHalfYear => 'Half-year';

  @override
  String get repeatYearly => 'Yearly';

  @override
  String subscriptionAmountRange(String min, String max) {
    return '$min – $max';
  }

  @override
  String get tabSubscriptions => 'Subscriptions';

  @override
  String get tabRecurringTransactions => 'Recurring transactions';

  @override
  String get badgeSubscription => 'Subscription';

  @override
  String get badgeRecurringTransaction => 'Recurring transaction';

  @override
  String get addSubscription => 'Subscription';

  @override
  String get addRecurringTransaction => 'Recurring';

  @override
  String get noSubscriptionsOrRecurrencesFound =>
      'No subscriptions or recurring transactions found.';

  @override
  String get newRecurringTransaction => 'New Recurring Transaction';

  @override
  String get createRecurringTransaction => 'Create Recurring Transaction';

  @override
  String get editRecurringTransaction => 'Edit Recurring Transaction';

  @override
  String get recurringTransactionCreated => 'Recurring transaction created.';

  @override
  String recurringTransactionDeleted(String name) {
    return 'Recurring transaction \"$name\" deleted.';
  }

  @override
  String failedToCreateRecurringTransaction(String error) {
    return 'Failed to create recurring transaction: $error';
  }

  @override
  String failedToUpdateRecurringTransaction(String error) {
    return 'Failed to update recurring transaction: $error';
  }

  @override
  String failedToDeleteRecurringTransaction(String error) {
    return 'Failed to delete recurring transaction: $error';
  }

  @override
  String get deleteRecurringTransaction => 'Delete Recurring Transaction';

  @override
  String deleteRecurringTransactionConfirmBody(String name) {
    return 'Are you sure you want to delete the recurring transaction \"$name\"? This action cannot be undone.';
  }

  @override
  String get noRecurringTransactionsFound => 'No recurring transactions found.';

  @override
  String get recurringTransactionInactive => 'Inactive';

  @override
  String get mandatoryRecurrenceFields => 'Mandatory recurrence information';

  @override
  String get optionalRecurrenceFields => 'Optional recurrence information';

  @override
  String get mandatoryTransactionFields => 'Mandatory transaction information';

  @override
  String get optionalTransactionFields => 'Optional transaction information';

  @override
  String get recurrenceTitle => 'Title';

  @override
  String get firstDate => 'First date';

  @override
  String get firstDateHelp =>
      'Indicate the first expected recurrence. This must be in the future.';

  @override
  String get typeOfRepetition => 'Type of repetition';

  @override
  String get typeOfRepetitionHelp =>
      'Change the first date to see more options.';

  @override
  String get weekendHandling => 'Weekend';

  @override
  String get weekendCreateAnyway => 'Just create the transaction';

  @override
  String get weekendSkip => 'Do not create a transaction';

  @override
  String get weekendPreviousFriday => 'Skip to the previous Friday';

  @override
  String get weekendNextMonday => 'Skip to the next Monday';

  @override
  String get weekendHelp =>
      'What should Firefly III do when the recurring transaction falls on a Saturday or Sunday?';

  @override
  String get repetitionEnds => 'Repetition ends';

  @override
  String get repeatForever => 'Repeat forever';

  @override
  String get repeatUntilDate => 'Repeat until date';

  @override
  String get repeatCount => 'Repeat a fixed number of times';

  @override
  String get numberOfRepetitions => 'Number of repetitions';

  @override
  String get applyRules => 'Apply rules';

  @override
  String get applyRulesHelp =>
      'Whether to fire rules after creating each transaction.';

  @override
  String get recurrenceDescription => 'Recurring transaction description';

  @override
  String get repeatDaily => 'Daily';

  @override
  String get repeatNdom => 'Monthly on nth weekday';

  @override
  String recurrenceAmount(String amount) {
    return '$amount';
  }

  @override
  String get tooltipOpenSubscriptions =>
      'Open subscriptions and recurring transactions.';

  @override
  String get subscriptionsTitleRacoon => 'Recurring Raids & Schedules';

  @override
  String get newSubscriptionRacoon => 'New Recurring Raid';

  @override
  String get piggyBanksTitle => 'Piggy banks';

  @override
  String get newPiggyBank => 'New piggy bank';

  @override
  String get createPiggyBank => 'Create piggy bank';

  @override
  String get editPiggyBank => 'Edit piggy bank';

  @override
  String get piggyBankCreated => 'Piggy bank created.';

  @override
  String piggyBankDeleted(String name) {
    return 'Piggy bank \"$name\" deleted.';
  }

  @override
  String failedToCreatePiggyBank(String error) {
    return 'Failed to create piggy bank: $error';
  }

  @override
  String failedToUpdatePiggyBank(String error) {
    return 'Failed to update piggy bank: $error';
  }

  @override
  String failedToDeletePiggyBank(String error) {
    return 'Failed to delete piggy bank: $error';
  }

  @override
  String get deletePiggyBank => 'Delete piggy bank';

  @override
  String deletePiggyBankConfirmBody(String name) {
    return 'Are you sure you want to delete the piggy bank \"$name\"? This action cannot be undone.';
  }

  @override
  String get noPiggyBanksFound => 'No piggy banks found.';

  @override
  String get targetAmount => 'Target amount';

  @override
  String get piggyBankCurrencyHelp =>
      'Piggy banks can only save money in a single currency.';

  @override
  String get saveOnAccounts => 'Save on account(s)';

  @override
  String get piggyBankAccountsHelp =>
      'Only accounts that use the previously selected currency will be accepted.';

  @override
  String get targetDate => 'Target date';

  @override
  String get targetDateHelp => 'The date you intend to finish saving money.';

  @override
  String get accountGroupDefaultAssets => 'Default asset accounts';

  @override
  String get accountGroupSavings => 'Savings accounts';

  @override
  String get accountGroupCash => 'Cash wallets';

  @override
  String get accountGroupLiabilities => 'Liabilities';

  @override
  String get selectAtLeastOneAccount => 'Select at least one account.';

  @override
  String piggyBankProgress(String current, String target) {
    return '$current / $target';
  }

  @override
  String get piggyBanksTitleRacoon => 'Mini Stashes';

  @override
  String get newPiggyBankRacoon => 'New Mini Stash';

  @override
  String get newBudget => 'New Budget';

  @override
  String get deleteBudget => 'Delete Budget';

  @override
  String deleteBudgetMessage(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String budgetDeleted(String name) {
    return 'Budget \"$name\" deleted.';
  }

  @override
  String failedToDeleteBudget(String error) {
    return 'Failed to delete budget: $error';
  }

  @override
  String get spent => 'Spent';

  @override
  String ofAmount(String amount) {
    return 'of $amount';
  }

  @override
  String overBudget(String amount) {
    return '$amount over budget';
  }

  @override
  String leftInBudget(String amount) {
    return '$amount left';
  }

  @override
  String budgetPerPeriod(String amount, String period) {
    return '$amount per $period';
  }

  @override
  String budgetLimitForPeriod(String amount, String period) {
    return '$amount for $period';
  }

  @override
  String get budgetCadenceDaily => 'day';

  @override
  String get budgetCadenceWeekly => 'week';

  @override
  String get budgetCadenceMonthly => 'month';

  @override
  String get budgetCadenceQuarterly => 'quarter';

  @override
  String get budgetCadenceHalfYear => 'half-year';

  @override
  String get budgetCadenceYearly => 'year';

  @override
  String get viewPeriod => 'View period';

  @override
  String get budgetAmount => 'Budget amount';

  @override
  String get editBudget => 'Edit Budget';

  @override
  String get createBudget => 'Create Budget';

  @override
  String get createPayee => 'Create Payee';

  @override
  String get createCategory => 'Create Category';

  @override
  String get budgetLimit => 'Budget limit';

  @override
  String get autoBudget => 'Auto-budget amount';

  @override
  String get budgetAmountMode => 'Limit type';

  @override
  String get budgetAmountModeAuto => 'Repeating period';

  @override
  String get budgetAmountModeDateRange => 'Fixed date range';

  @override
  String get budgetAmountModeNone => 'No amount';

  @override
  String get budgetRepeatPeriod => 'Repeats every';

  @override
  String get budgetAutoType => 'Auto-budget behavior';

  @override
  String get budgetAutoTypeReset => 'Reset each period';

  @override
  String get budgetAutoTypeRollover => 'Roll over unused';

  @override
  String get budgetAutoTypeAdjusted => 'Adjust to spending';

  @override
  String get budgetAutoTypeNone => 'None';

  @override
  String get budgetActive => 'Active';

  @override
  String get budgetPeriodDaily => 'Daily';

  @override
  String get budgetPeriodWeekly => 'Weekly';

  @override
  String get budgetPeriodMonthly => 'Monthly';

  @override
  String get budgetPeriodQuarterly => 'Quarterly';

  @override
  String get budgetPeriodHalfYear => 'Every half year';

  @override
  String get budgetPeriodYearly => 'Yearly';

  @override
  String get tooltipBudgetAmountMode =>
      'Choose a repeating auto-budget, a fixed date range, or no limit';

  @override
  String get tooltipBudgetRepeatPeriod =>
      'How often the budget amount applies (e.g. monthly)';

  @override
  String get tooltipBudgetAutoType =>
      'What happens at the start of each budget period';

  @override
  String get tooltipBudgetStartDate => 'First day this budget limit applies';

  @override
  String get tooltipBudgetEndDate => 'Last day this budget limit applies';

  @override
  String get tooltipBudgetActive =>
      'Inactive budgets are hidden from default views in Firefly';

  @override
  String get tooltipBudgetNotes => 'Optional notes stored with the budget';

  @override
  String get tooltipBudgetCurrency => 'Currency for the budget amount';

  @override
  String get expensesTitle => 'Expenses';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get overview => 'Overview';

  @override
  String get byCategory => 'By Category';

  @override
  String get allCategories => 'All Categories';

  @override
  String get allTypes => 'All Types';

  @override
  String get expensesFilter => 'Expenses';

  @override
  String get transfers => 'Transfers';

  @override
  String get expensePeriodWeek => 'This Week';

  @override
  String get expensePeriodMonth => 'This Month';

  @override
  String get expensePeriodQuarter => 'This Quarter';

  @override
  String get expensePeriodSemester => 'This Semester';

  @override
  String get expensePeriodYear => 'This Year';

  @override
  String get expensePeriodAll => 'All Time';

  @override
  String get dashboardPeriodThisWeek => 'This week';

  @override
  String get dashboardPeriodLastWeek => 'Last week';

  @override
  String get dashboardPeriodThisMonth => 'This month';

  @override
  String get dashboardPeriodLastMonth => 'Last month';

  @override
  String get dashboardPeriodThisQuarter => 'This quarter';

  @override
  String get dashboardPeriodLastQuarter => 'Last quarter';

  @override
  String get dashboardPeriodThisYear => 'This year';

  @override
  String get dashboardPeriodLastYear => 'Last year';

  @override
  String get dashboardPeriodLast2Years => 'Last 2 years';

  @override
  String get dashboardPeriodLast5Years => 'Last 5 years';

  @override
  String get dashboardPeriodLast10Years => 'Last 10 years';

  @override
  String get dashboardPeriodAll => 'All';

  @override
  String get deltaComparisonPreviousWeek => 'previous week';

  @override
  String get deltaComparisonPreviousMonth => 'previous month';

  @override
  String get deltaComparisonPreviousQuarter => 'previous quarter';

  @override
  String get deltaComparisonPreviousYear => 'previous year';

  @override
  String get deltaComparisonPrevious2Years => 'previous 2 years';

  @override
  String get deltaComparisonPrevious5Years => 'previous 5 years';

  @override
  String get deltaComparisonPrevious10Years => 'previous 10 years';

  @override
  String get deltaComparisonCustomPeriod => 'previous period';

  @override
  String noChangeVsComparisonPeriod(String period) {
    return 'No change vs $period';
  }

  @override
  String newActivityVsComparisonPeriod(String period) {
    return 'New activity vs $period';
  }

  @override
  String percentVsComparisonPeriod(
    String arrow,
    String percent,
    String period,
  ) {
    return '$arrow$percent% vs $period';
  }

  @override
  String get dateRangeSeparator => '–';

  @override
  String get dateEllipsis => '…';

  @override
  String get projectionTitle => 'Projection';

  @override
  String get projectedBalance => 'Projected balance';

  @override
  String get visualization => 'Visualization';

  @override
  String get parameters => 'Parameters';

  @override
  String predictedBalances(String period) {
    return 'Predicted balances · $period';
  }

  @override
  String get noAccountsLoaded => 'No accounts loaded';

  @override
  String get scenarioSummary => 'Scenario summary';

  @override
  String nowAmount(String amount) {
    return 'now $amount';
  }

  @override
  String get worstCase => 'Worst case';

  @override
  String get expected => 'Expected';

  @override
  String get bestCase => 'Best case';

  @override
  String get moveSliderToSeeImpact => 'Move the slider to see impact';

  @override
  String whatIfImpact(String amount, String period) {
    return '+$amount over $period';
  }

  @override
  String get projectionPeriod3Months => '3 Months';

  @override
  String get projectionPeriod6Months => '6 Months';

  @override
  String get projectionPeriod1Year => '1 Year';

  @override
  String get projectionPeriod3Years => '3 Years';

  @override
  String get projectionTypeSavings => 'Savings rate';

  @override
  String get projectionTypeCompound => 'Compound growth';

  @override
  String get projectionTypePortfolio => 'Portfolio (volatile)';

  @override
  String get projectionTypeCashflow => 'Cash flow';

  @override
  String get projectionTypeSavingsDesc =>
      'Linear projection from your historical net savings';

  @override
  String get projectionTypeCompoundDesc =>
      'Balance grows with compound interest plus contributions';

  @override
  String get projectionTypePortfolioDesc =>
      'Expected return with worst/best bands from volatility';

  @override
  String get projectionTypeCashflowDesc =>
      'Income minus expenses with discretionary adjustments';

  @override
  String get chartStyleFan => 'Fan chart';

  @override
  String get chartStyleLines => 'Three lines';

  @override
  String get chartStyleScenarios => 'Scenario cards';

  @override
  String get whatIfSpending => 'What-if spending';

  @override
  String get annualReturn => 'Annual return';

  @override
  String get volatility => 'Volatility';

  @override
  String projectionAlertLiability(String name, String balance) {
    return 'At worst case, $name may reach $balance sooner than expected.';
  }

  @override
  String get projectionAlertBelowZero =>
      'Worst-case projection dips below zero within the selected period.';

  @override
  String get projectionAlertActionLiability =>
      'Consider moving funds from a savings account.';

  @override
  String get projectionAlertActionSpending =>
      'Review discretionary spending or increase savings.';

  @override
  String get confirmTypeWord => 'Type ';

  @override
  String get confirmToConfirm => ' to confirm:';

  @override
  String get confirmHint => 'Type the word above…';

  @override
  String currencyPair(String name, String symbol) {
    return '$name ($symbol)';
  }

  @override
  String budgetSpentFraction(String spent, String total) {
    return '$spent / $total';
  }

  @override
  String get editAccount => 'Edit Account';

  @override
  String get editAction => 'Edit';

  @override
  String get filterAllShort => 'All';

  @override
  String get filterAssetsShort => 'Assets';

  @override
  String get filterLiabilitiesShort => 'Liabilities';

  @override
  String get showInactiveAccounts => 'Show inactive accounts';

  @override
  String get showInactiveAccountsShort => 'Inactive';

  @override
  String get accountInactive => 'Inactive';

  @override
  String get unknown => 'Unknown';

  @override
  String showingTransactionsOfTotal(int loaded, int total) {
    return 'Showing $loaded of $total transactions';
  }

  @override
  String transactionsCount(int count) {
    return '$count transactions';
  }

  @override
  String get oneTransaction => '1 transaction';

  @override
  String deleteBudgetConfirmBody(String name) {
    return 'Are you sure you want to delete the budget \"$name\"? This action cannot be undone.';
  }

  @override
  String get scrollForMore => 'Scroll for more…';

  @override
  String get noTransactionsMatchFilters =>
      'No transactions match the current filters.';

  @override
  String get category => 'Category';

  @override
  String get totalSpentPeriod => 'Total spent this period';

  @override
  String get totalIncomePeriod => 'Total income this period';

  @override
  String get totalTransferredPeriod => 'Total transferred this period';

  @override
  String get totalPeriod => 'Total this period';

  @override
  String get volatilityUncertainty => 'Volatility / uncertainty';

  @override
  String get editTransaction => 'Edit Transaction';

  @override
  String get newDeposit => 'Create new deposit';

  @override
  String get editDeposit => 'Edit deposit';

  @override
  String get newWithdrawal => 'Create new withdrawal';

  @override
  String get editWithdrawal => 'Edit withdrawal';

  @override
  String get newTransfer => 'Create new transfer';

  @override
  String get editTransfer => 'Edit transfer';

  @override
  String get revenueAccount => 'Revenue account';

  @override
  String get assetAccount => 'Asset account';

  @override
  String get expenseAccount => 'Expense account';

  @override
  String get expenseLabel => 'Expense';

  @override
  String get transactionTypeDeposit => 'Deposit';

  @override
  String get transactionTypeWithdrawal => 'Withdrawal';

  @override
  String get transactionTypeTransfer => 'Transfer';

  @override
  String get dataAndLoading => 'Data & loading';

  @override
  String get transactionPageSize => 'Transactions per page';

  @override
  String get transactionPageSizeDescription =>
      'How many transactions to load each time you scroll. Applies to the transactions list.';

  @override
  String transactionPageSizeValue(int count) {
    return '$count per page';
  }

  @override
  String get defaultPeriod => 'Default period';

  @override
  String get defaultPeriodDescription =>
      'Applied when opening the dashboard, expenses, income, transfers, and transactions.';

  @override
  String get customDateRange => 'Custom Range';

  @override
  String get pickDates => 'Pick Dates';

  @override
  String get budgetStatusOnTrack => 'On track';

  @override
  String get budgetStatusOver => 'Over budget';

  @override
  String whatIfCutSpending(int percent) {
    return 'What if I cut discretionary spending by $percent%?';
  }

  @override
  String get usesAveragePatterns =>
      'Uses your average income and expense patterns from transactions.';

  @override
  String get historicalNetSavingsNote =>
      'Based on historical net savings. Adjust uncertainty to widen or narrow the band.';

  @override
  String get accountFilterLabel => 'Account';

  @override
  String get noTransactionsForBudget => 'No transactions for this budget.';

  @override
  String get noTransactionsForAccount => 'No transactions for this account.';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String deleteAccountConfirmBody(String name) {
    return 'Are you sure you want to delete the account \"$name\"? This action cannot be undone.';
  }

  @override
  String accountDeleted(String name) {
    return 'Account \"$name\" deleted.';
  }

  @override
  String failedToDeleteAccount(String error) {
    return 'Failed to delete account: $error';
  }

  @override
  String get budgetNameHint => 'Budget name';

  @override
  String budgetAmountWithSymbol(String symbol) {
    return 'Budget Amount ($symbol)';
  }

  @override
  String get chartLegendActual => 'Actual';

  @override
  String get chartLegendWorst => 'Worst';

  @override
  String get chartLegendBest => 'Best';

  @override
  String get chartLegendWorstBest => 'Worst ↔ Best';

  @override
  String get today => 'today';

  @override
  String get mcpServer => 'MCP server';

  @override
  String mcpStatusFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String mcpStatusRunning(int port) {
    return 'Running on port $port';
  }

  @override
  String get mcpStatusStarting => 'Starting…';

  @override
  String get mcpStatusNoKeys => 'No agent keys yet, so the server is idle';

  @override
  String get mcpAgentKeys => 'Agent keys';

  @override
  String get mcpAgentKeysHint =>
      'Agents authenticate with a FireRacoon key, not your Firefly III token. Each key acts as the person who created it.';

  @override
  String get mcpNoAgentKeys => 'No agent keys yet';

  @override
  String get mcpCreateKey => 'Create key';

  @override
  String get mcpKeyLabel => 'Label';

  @override
  String get mcpKeyLabelHint => 'Claude Desktop';

  @override
  String get mcpKeyIssuedTitle => 'Copy your agent key';

  @override
  String get mcpForgetKey => 'Forget this key';

  @override
  String get mcpPickKeyTitle => 'Which key should it use?';

  @override
  String get mcpWithoutKey => 'Without a key';

  @override
  String get mcpShowKey => 'Show key';

  @override
  String get mcpKeyNotRecoverable =>
      'This key was created before keys could be read back. Revoke it and create a new one.';

  @override
  String get mcpKeyIssuedBody =>
      'Paste this into your MCP client as initialize.params.apiKey, or set FIRERACOON_API_KEY. You can reopen it later from this list.';

  @override
  String get mcpCopyKey => 'Copy';

  @override
  String get mcpKeyCopied => 'Agent key copied';

  @override
  String get mcpRevokeKey => 'Revoke';

  @override
  String get mcpRevokeKeyTitle => 'Revoke agent key?';

  @override
  String mcpRevokeKeyBody(String label) {
    return '$label stops working immediately and its open connections drop.';
  }

  @override
  String mcpKeyCreatedAt(String date) {
    return 'Created $date';
  }

  @override
  String mcpKeyRevokedAt(String date) {
    return 'Revoked $date';
  }

  @override
  String get mcpServerCredentials => 'MCP server credentials';

  @override
  String get mcpAddress => 'Address';

  @override
  String get mcpNotRunning => 'Not running';

  @override
  String get mcpAuthParameter => 'Auth parameter';

  @override
  String get mcpTransportLabel => 'Transport';

  @override
  String get mcpTransportTcp => 'TCP (localhost only)';

  @override
  String get mcpCopyConnection => 'Copy connection details';

  @override
  String get mcpConnectionCopied => 'Connection details copied';

  @override
  String mcpKeyLastUsedAt(String date) {
    return 'Last used $date';
  }

  @override
  String get mcpKeyNeverUsed => 'Never used';

  @override
  String mcpKeyOwner(String name, String role) {
    return 'Acts as $name ($role)';
  }

  @override
  String get transactionDate => 'Date';

  @override
  String get moreOptions => 'More';

  @override
  String get foreignAmountLabel => 'Foreign amount';

  @override
  String get budgetLabel => 'Budget';

  @override
  String get piggyBank => 'Piggy bank';

  @override
  String get noPiggyBank => '(no piggy bank)';

  @override
  String get tags => 'Tags';

  @override
  String get subscription => 'Subscription';

  @override
  String get interestDate => 'Interest date';

  @override
  String get attachments => 'Attachments';

  @override
  String get notes => 'Notes';

  @override
  String get none => '(none)';

  @override
  String get attachmentsNotSupported =>
      'Attachments are not supported in this app yet.';

  @override
  String get deleteTransaction => 'Delete Transaction';

  @override
  String deleteTransactionConfirmBody(String description) {
    return 'Are you sure you want to delete \"$description\"? This action cannot be undone.';
  }

  @override
  String get transactionDeleted => 'Transaction deleted.';

  @override
  String failedToDeleteTransaction(String error) {
    return 'Failed to delete transaction: $error';
  }

  @override
  String get transactionSaved => 'Transaction saved.';

  @override
  String failedToSaveTransaction(String error) {
    return 'Failed to save transaction: $error';
  }

  @override
  String get transactionDuplicated => 'Transaction duplicated.';

  @override
  String failedToDuplicateTransaction(String error) {
    return 'Failed to duplicate transaction: $error';
  }

  @override
  String get duplicate => 'Duplicate';

  @override
  String get newTransaction => 'New Transaction';

  @override
  String get transactionCreated => 'Transaction created.';

  @override
  String failedToCreateTransaction(String error) {
    return 'Failed to create transaction: $error';
  }

  @override
  String get transactionFormIncomplete =>
      'Please fill in description, amount, and both accounts.';

  @override
  String get transactionInformation => 'Transaction information';

  @override
  String get addAnotherSplit => 'Add another split';

  @override
  String splitLabel(int number) {
    return 'Split $number';
  }

  @override
  String get removeSplit => 'Remove split';

  @override
  String splitCount(int count) {
    return '$count splits';
  }

  @override
  String splitCategoriesCount(int count) {
    return '$count categories';
  }

  @override
  String get splitMainAmount => 'Total amount';

  @override
  String get tooltipSplitMainAmount =>
      'Main transaction total. Split amounts must add up to this before saving.';

  @override
  String splitTotalLabel(String amount) {
    return 'Split total: $amount';
  }

  @override
  String splitRemainder(String amount) {
    return 'Remainder: $amount';
  }

  @override
  String splitsTotalMismatch(String expected) {
    return 'Split amounts must total $expected.';
  }

  @override
  String get splitOptionalFields => 'Optional fields';

  @override
  String get foreignCurrency => 'Foreign currency';

  @override
  String get noSubscriptionsHint =>
      'You have no subscriptions yet. Create some on the Subscriptions page to link recurring expenses.';

  @override
  String get incomeTitle => 'Income';

  @override
  String get transfersTitle => 'Transfers';

  @override
  String get newTransferAction => 'New Transfer';

  @override
  String get liabilitiesTitle => 'Liabilities';

  @override
  String get newIncome => 'New Income';

  @override
  String get newIncomeRacoon => 'New Snatch';

  @override
  String get create => 'Create';

  @override
  String get accountCreated => 'Account created.';

  @override
  String get liabilityCreated => 'Liability created.';

  @override
  String get budgetCreated => 'Budget created.';

  @override
  String failedToCreateAccount(String error) {
    return 'Failed to create account: $error';
  }

  @override
  String failedToCreateBudget(String error) {
    return 'Failed to create budget: $error';
  }

  @override
  String get noLiabilitiesFound => 'No liabilities found.';

  @override
  String get liabilityType => 'Liability type';

  @override
  String get liabilityTypeDebt => 'Debt';

  @override
  String get liabilityTypeLoan => 'Loan';

  @override
  String get liabilityTypeMortgage => 'Mortgage';

  @override
  String get liabilityDirection => 'Liability in/out';

  @override
  String get liabilityDirectionOwe => 'I owe this debt to somebody else';

  @override
  String get liabilityDirectionOwed => 'Somebody owes this debt to me';

  @override
  String get amountOwed => 'I owe amount';

  @override
  String get debtStartDate => 'Start date of debt';

  @override
  String get interestRate => 'Interest';

  @override
  String get interestPeriod => 'Interest period';

  @override
  String get interestPeriodDaily => 'Per day';

  @override
  String get includeInNetWorth => 'Include in net worth';

  @override
  String get accountNumber => 'Account number';

  @override
  String get iban => 'IBAN';

  @override
  String get bic => 'BIC';

  @override
  String get liabilityCurrencyHelp =>
      'Default currency for this liability account.';

  @override
  String get interestPeriodHelp =>
      'Cosmetic only — Firefly III does not calculate interest automatically.';

  @override
  String failedToCreateLiability(String error) {
    return 'Failed to create liability: $error';
  }

  @override
  String get navIncomeRacoon => 'Snatched';

  @override
  String get navTransfersRacoon => 'Stash Shuffles';

  @override
  String get navLiabilitiesRacoon => 'Debts';

  @override
  String get incomeTitleRacoon => 'Snatched Funds';

  @override
  String get transfersTitleRacoon => 'Stash Shuffles';

  @override
  String get newTransferActionRacoon => 'New Stash Shuffle';

  @override
  String get liabilitiesTitleRacoon => 'Debts Owed';

  @override
  String tooltipOpenSection(String section) {
    return 'Open $section.';
  }

  @override
  String get tooltipOpenDashboard => 'Open the dashboard with your key KPIs.';

  @override
  String get tooltipOpenAccounts => 'Open your accounts and balances.';

  @override
  String get tooltipOpenTransactions => 'Open all transactions and filters.';

  @override
  String get tooltipOpenBudgets => 'Open your budgets and spending progress.';

  @override
  String get tooltipOpenPiggyBanks =>
      'Open your savings goals and piggy banks.';

  @override
  String get tooltipOpenExpenses => 'Open expense analytics and breakdowns.';

  @override
  String get tooltipOpenIncome => 'Open income analytics and trends.';

  @override
  String get tooltipOpenTransfers => 'Open transfer analytics and history.';

  @override
  String get tooltipOpenLiabilities => 'Open liabilities and debt overview.';

  @override
  String get tooltipOpenProjection =>
      'Open projection scenarios and forecasts.';

  @override
  String get tooltipOpenPrognosis =>
      'Open month-end account balance prognosis.';

  @override
  String get projectionTabLongTerm => 'Long-term forecast';

  @override
  String get tooltipOpenSettings => 'Open app settings and Firefly connection.';

  @override
  String get tooltipToggleSidebar => 'Expand or collapse the sidebar.';

  @override
  String get tooltipSearchTransactions => 'Search by text in the current page.';

  @override
  String get tooltipToggleViewMode => 'Switch between list and grid view.';

  @override
  String get refreshFromFirefly => 'Refresh';

  @override
  String get tooltipRefreshFromFirefly => 'Re-fetch data from Firefly III';

  @override
  String get viewModeCards => 'Cards';

  @override
  String get viewModeRows => 'Rows';

  @override
  String get viewModeTightRows => 'Tight rows';

  @override
  String get columnSelection => 'Select columns';

  @override
  String get columnDate => 'Date';

  @override
  String get columnAccount => 'Account';

  @override
  String get columnType => 'Mode';

  @override
  String get columnPayee => 'Payee';

  @override
  String get columnDescription => 'Comment';

  @override
  String get columnCategory => 'Category';

  @override
  String get columnBudget => 'Budget';

  @override
  String get columnAmount => 'Amount';

  @override
  String get columnReconciled => 'Reconciled';

  @override
  String get columnBalance => 'Balance';

  @override
  String get tooltipTransactionType => 'Choose the transaction type.';

  @override
  String get tooltipFieldDescription => 'What happened in this transaction.';

  @override
  String get tooltipFieldSourceAccount => 'Account money comes from.';

  @override
  String get tooltipFieldDestinationAccount => 'Account money goes to.';

  @override
  String get tooltipFieldDate => 'Date and time of the transaction.';

  @override
  String get tooltipFieldAmount => 'Main amount in the selected currency.';

  @override
  String get tooltipFieldCurrency => 'Primary currency of this split.';

  @override
  String get tooltipFieldForeignAmount =>
      'Optional amount in another currency.';

  @override
  String get tooltipFieldForeignCurrency => 'Currency used for foreign amount.';

  @override
  String get tooltipFieldBudget => 'Assign this split to a budget.';

  @override
  String get tooltipFieldCategory => 'Category for reporting and filters.';

  @override
  String get tooltipFieldPiggyBank => 'Link this split to a piggy bank.';

  @override
  String get tooltipFieldTags => 'Comma-separated tags for quick filtering.';

  @override
  String get tooltipFieldSubscription => 'Link this split to a subscription.';

  @override
  String get tooltipFieldInterestDate => 'Optional interest or booking date.';

  @override
  String get tooltipFieldAttachments =>
      'Attachments are shown but not uploaded yet.';

  @override
  String get tooltipFieldNotes => 'Extra details for future reference.';

  @override
  String get tooltipAddSplit => 'Add another split to this transaction.';

  @override
  String get tooltipRemoveSplit => 'Remove this split line.';

  @override
  String get tooltipCancelTransaction => 'Discard changes and close.';

  @override
  String get tooltipSaveTransaction => 'Save this transaction.';

  @override
  String get tooltipCancel => 'Discard changes and close without saving.';

  @override
  String get tooltipSave => 'Save your changes.';

  @override
  String get tooltipCreate => 'Create the new item.';

  @override
  String get tooltipConfirmDelete => 'Permanently delete this item.';

  @override
  String get tooltipConfirmChallenge =>
      'Type the challenge word to confirm deletion.';

  @override
  String get tooltipExpandDetails => 'Show more details.';

  @override
  String get tooltipCollapseDetails => 'Hide extra details.';

  @override
  String get tooltipClearDate => 'Remove the selected date.';

  @override
  String get tooltipAccountName => 'Display name shown in lists and reports.';

  @override
  String get tooltipAccountCurrentBalance =>
      'Current balance from Firefly as of today.';

  @override
  String get tooltipAccountEndOfMonthBalance =>
      'Projected balance at the selected date, including scheduled transactions, recurrences, and bills.';

  @override
  String get tooltipBalanceDatePick => 'Show balances at another date';

  @override
  String get tooltipBalanceDateReset => 'Back to the end of this month';

  @override
  String get tooltipBalanceBeyondForecast =>
      'The forecast does not reach this far ahead, so this is the last projected figure.';

  @override
  String get tooltipRecordedBalance =>
      'Balance the ledger holds through this date, including transactions already dated ahead.';

  @override
  String get tooltipBudgetName => 'Name for this spending budget.';

  @override
  String get tooltipBudgetAmount => 'Limit amount for this budget period.';

  @override
  String get tooltipSubscriptionName =>
      'Name of the recurring bill or subscription.';

  @override
  String get tooltipSubscriptionCurrency =>
      'Currency used for expected amounts.';

  @override
  String get tooltipSubscriptionAmountMin =>
      'Lowest expected charge per period.';

  @override
  String get tooltipSubscriptionAmountMax =>
      'Highest expected charge per period.';

  @override
  String get tooltipSubscriptionStartDate =>
      'Date the subscription begins or was first recorded.';

  @override
  String get tooltipSubscriptionRepeats =>
      'How often this subscription repeats.';

  @override
  String get tooltipSubscriptionSkip =>
      'Skip the next N occurrences before charging again.';

  @override
  String get tooltipSubscriptionEndDate =>
      'Optional date when this subscription stops.';

  @override
  String get tooltipSubscriptionExtensionDate =>
      'Optional date to extend or pause billing.';

  @override
  String get tooltipSubscriptionGroup =>
      'Optional group label for organizing subscriptions.';

  @override
  String get tooltipSubscriptionActive =>
      'Whether this subscription is currently active.';

  @override
  String get tooltipPiggyBankName => 'Name of this savings goal.';

  @override
  String get tooltipPiggyBankTargetAmount =>
      'Amount you want to save in total.';

  @override
  String get tooltipPiggyBankCurrency =>
      'Currency for the target and tracked savings.';

  @override
  String get tooltipPiggyBankAccounts =>
      'Accounts whose balances count toward this goal.';

  @override
  String tooltipPiggyBankAccount(String name) {
    return 'Include $name in this piggy bank.';
  }

  @override
  String get tooltipPiggyBankStartDate =>
      'When you started tracking this goal.';

  @override
  String get tooltipPiggyBankTargetDate =>
      'Optional deadline to reach the target.';

  @override
  String get tooltipPiggyBankGroup =>
      'Optional group label for organizing piggy banks.';

  @override
  String get tooltipThemeLight => 'Use the light color scheme.';

  @override
  String get tooltipThemeDark => 'Use the dark color scheme.';

  @override
  String get tooltipThemePaletteClassic => 'Firefly-inspired classic palette.';

  @override
  String get tooltipThemePaletteSpectrum =>
      'Vivid multi-color category palette.';

  @override
  String get tooltipThemePaletteRaccoon => 'Playful raccoon-themed palette.';

  @override
  String get tooltipThemeAccent =>
      'Accent color for buttons, links, and highlights.';

  @override
  String tooltipThemeAccentOption(String name) {
    return 'Use $name as the accent color.';
  }

  @override
  String get tooltipThemeDone => 'Close and keep the selected theme.';

  @override
  String get repeatIntervalLabel => 'Interval';

  @override
  String get repeatIntervalHelp =>
      'How often this repeats, e.g. every 3 months.';

  @override
  String repeatEveryNDays(int count) {
    return 'Every $count days';
  }

  @override
  String repeatEveryNWeeks(int count) {
    return 'Every $count weeks';
  }

  @override
  String repeatEveryNMonths(int count) {
    return 'Every $count months';
  }

  @override
  String repeatEveryNYears(int count) {
    return 'Every $count years';
  }

  @override
  String get writeAheadDays => 'Write recurring transactions in advance';

  @override
  String get writeAheadDaysDescription =>
      'Create upcoming recurring transactions this many days ahead.';

  @override
  String get writeAheadOff => 'Off';

  @override
  String writeAheadNDays(int count) {
    return '$count days';
  }

  @override
  String get plannedLabel => 'Planned';

  @override
  String get navHistory => 'History';

  @override
  String get navHistoryRacoon => 'Heist Replay';

  @override
  String get tooltipOpenHistory => 'Open undo/redo history.';

  @override
  String get tooltipUndo => 'Undo the last action.';

  @override
  String get tooltipRedo => 'Redo the last undone action.';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get clear => 'Clear';

  @override
  String get advanced => 'Advanced';

  @override
  String get undoHistorySize => 'Undo/Redo history size';

  @override
  String undoHistoryStoredEntries(int count, int limit) {
    return 'Stored entries: $count / $limit';
  }

  @override
  String get openHistoryScreen => 'Open history screen';

  @override
  String undoHistoryLimitRange(int min, int defaultValue, int max) {
    return 'Min $min  •  Default $defaultValue  •  Max $max';
  }

  @override
  String get searchHistory => 'Search history';

  @override
  String get allActions => 'All actions';

  @override
  String get noHistoryEntriesMatchFilters =>
      'No history entries match your filters.';

  @override
  String historyExportedTo(String path) {
    return 'History exported to $path';
  }

  @override
  String get historyExportedAndShared =>
      'History exported and share sheet opened';

  @override
  String get exportJson => 'Export JSON';

  @override
  String get exportAndShare => 'Export & Share';

  @override
  String get jumpToCurrent => 'Jump to current';

  @override
  String get historyExportSubject => 'History export';

  @override
  String get historyExportText => 'FireRacoon history export';

  @override
  String get historySectionToday => 'Today';

  @override
  String get historySectionYesterday => 'Yesterday';

  @override
  String get historySectionOlder => 'Older';

  @override
  String historyEntriesCount(int count, int limit) {
    return '$count / $limit';
  }

  @override
  String get undoActionTypeThemeMode => 'Theme mode';

  @override
  String get undoActionTypeThemePalette => 'Theme palette';

  @override
  String get undoActionTypeThemeAccent => 'Theme accent';

  @override
  String get undoActionTypeThemeFunMode => 'Fun mode';

  @override
  String get undoActionTypeLocale => 'Language';

  @override
  String get undoActionTypeViewMode => 'View mode';

  @override
  String get undoActionTypeTransactionPageSize => 'Transaction page size';

  @override
  String get undoActionTypePrognosisMode => 'Projection view mode';

  @override
  String get undoActionTypePrognosisHorizon => 'Projection horizon';

  @override
  String get undoActionTypePrognosisInclusion => 'Projection inclusion';

  @override
  String get undoActionTypePrognosisMarginPercent => 'Projection margin';

  @override
  String get undoActionTypeAccountCreate => 'Account created';

  @override
  String get undoActionTypeAccountUpdate => 'Account updated';

  @override
  String get undoActionTypeAccountDelete => 'Account deleted';

  @override
  String get undoActionTypeBudgetCreate => 'Budget created';

  @override
  String get undoActionTypeBudgetUpdate => 'Budget updated';

  @override
  String get undoActionTypeBudgetDelete => 'Budget deleted';

  @override
  String get undoActionTypeTransactionCreate => 'Transaction created';

  @override
  String get undoActionTypeTransactionUpdate => 'Transaction updated';

  @override
  String get undoActionTypeTransactionDelete => 'Transaction deleted';

  @override
  String get undoActionTypeBillCreate => 'Subscription created';

  @override
  String get undoActionTypeBillUpdate => 'Subscription updated';

  @override
  String get undoActionTypeBillDelete => 'Subscription deleted';

  @override
  String get undoActionTypeRecurrenceCreate => 'Recurring transaction created';

  @override
  String get undoActionTypeRecurrenceUpdate => 'Recurring transaction updated';

  @override
  String get undoActionTypeRecurrenceDelete => 'Recurring transaction deleted';

  @override
  String get undoActionTypePiggyBankCreate => 'Piggy bank created';

  @override
  String get undoActionTypePiggyBankUpdate => 'Piggy bank updated';

  @override
  String get undoActionTypePiggyBankDelete => 'Piggy bank deleted';

  @override
  String get undoActionTypeLiabilityCreate => 'Liability created';

  @override
  String get searchHintTitle => 'Start typing to search';

  @override
  String get searchHintSubtitle =>
      'Search by description, account, category, tag, note, or amount.';

  @override
  String get noSuggestions => 'No matching suggestions';

  @override
  String get invalidAmount => 'Amount must be a valid number greater than 0.';

  @override
  String get invalidForeignAmount =>
      'Foreign amount must be a valid number greater than 0.';

  @override
  String get exportFireflyData => 'Back up Firefly data';

  @override
  String get exportFireflyDataDescription =>
      'Saves a snapshot of your Firefly data to a JSON file: accounts, transactions with every split, budgets, categories, tags, bills, piggy banks, recurring rules and currencies.\n\nThis is not a full backup. Firefly III has no backup feature, and an app talking to its API cannot reach the database, uploaded attachments or the instance key. Restoring a working Firefly needs a volume archive taken on the server; see the deployment guide.';

  @override
  String fireflyDataExportedTo(String path) {
    return 'Firefly data exported to $path';
  }

  @override
  String get missingInformation => 'Missing information';

  @override
  String get missingDescription => 'Please enter a description.';

  @override
  String get missingAmount => 'Please enter an amount.';

  @override
  String get missingAccounts =>
      'Please select both source and destination accounts.';

  @override
  String get appUsers => 'People';

  @override
  String get enableAppUsers => 'Add people';

  @override
  String get enableAppUsersDescription =>
      'Add household members who can use this app and own shares of accounts. Everyone still shares the same Firefly III data.';

  @override
  String get createAdmin => 'Add first person';

  @override
  String get createAdminDescription =>
      'The first person becomes an admin. You can add more people afterwards.';

  @override
  String get addUser => 'Add person';

  @override
  String get editUser => 'Edit person';

  @override
  String get deleteUser => 'Delete person';

  @override
  String get role => 'Role';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleUser => 'User';

  @override
  String get roleViewer => 'Viewer';

  @override
  String get roleAdminDescription =>
      'Full access, including Firefly settings and people management.';

  @override
  String get roleUserDescription => 'Can add and edit financial data.';

  @override
  String get roleViewerDescription => 'Read-only access.';

  @override
  String get requireLogin => 'Login with password';

  @override
  String get requireLoginDescription =>
      'When on, every launch requires a password (or biometrics). Every person must have a password before this can be enabled.';

  @override
  String get switchUser => 'Switch person';

  @override
  String get selectUserSubtitle =>
      'Choose whose profile to use. No password needed while login with password is off.';

  @override
  String get assignPerson => 'Linked person';

  @override
  String get noPersonAssigned => 'None';

  @override
  String get myAccount => 'My profile';

  @override
  String get changePassword => 'Change password';

  @override
  String get setPassword => 'Set password';

  @override
  String get clearPassword => 'Remove password';

  @override
  String get passwordOptionalHint =>
      'Optional. Leave blank to skip. Required only if login with password is enabled.';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get logout => 'Log out';

  @override
  String get login => 'Log in';

  @override
  String get username => 'Name';

  @override
  String get password => 'Password';

  @override
  String get loginSubtitle => 'Sign in to continue to FireRacoon.';

  @override
  String get loginMissingFields => 'Enter your name and password.';

  @override
  String get loginInvalidCredentials => 'Incorrect name or password.';

  @override
  String get passwordTooWeak =>
      'Password must be at least 10 characters and include an uppercase letter, a lowercase letter, a digit, and a special character.';

  @override
  String get passwordRequirements =>
      'At least 10 characters, with uppercase, lowercase, a digit, and a special character.';

  @override
  String passwordMissingRequirements(String requirements) {
    return 'Password is missing $requirements.';
  }

  @override
  String get passwordReqMinLength => 'at least 10 characters';

  @override
  String get passwordReqUpper => 'an uppercase letter';

  @override
  String get passwordReqLower => 'a lowercase letter';

  @override
  String get passwordReqDigit => 'a digit';

  @override
  String get passwordReqSpecial => 'a special character';

  @override
  String get passwordPwned =>
      'This password has appeared in a known data breach. Please choose another one.';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match.';

  @override
  String get usernameTaken => 'That name is already taken.';

  @override
  String get currentPasswordIncorrect => 'Current password is incorrect.';

  @override
  String get userCreated => 'Person created.';

  @override
  String get userUpdated => 'Person updated.';

  @override
  String get userDeleted => 'Person deleted.';

  @override
  String get passwordChanged => 'Password updated.';

  @override
  String get passwordCleared => 'Password removed.';

  @override
  String get deleteUserConfirmTitle => 'Delete person';

  @override
  String deleteUserConfirmMessage(String username) {
    return 'This removes $username and their ownership shares. Firefly III data is not affected.';
  }

  @override
  String signedInAs(String username) {
    return 'Signed in as $username';
  }

  @override
  String get usernameRequired => 'Please enter a name.';

  @override
  String get unlockWithBiometrics => 'Unlock with biometrics';

  @override
  String get unlockWithBiometricsDescription =>
      'Use Face ID, Touch ID, fingerprint, or your device PIN on the login screen.';

  @override
  String get biometricUnlockReason => 'Unlock FireRacoon';

  @override
  String get biometricEnableReason => 'Confirm to enable biometric unlock';

  @override
  String get biometricUnlockFailed =>
      'Biometric unlock was cancelled or failed.';

  @override
  String get peopleMissingPasswordsTitle => 'Passwords required';

  @override
  String peopleMissingPasswordsMessage(String names) {
    return 'Set a password for these people before enabling login with password: $names.';
  }

  @override
  String get hasPassword => 'Password set';

  @override
  String get noPasswordSet => 'No password';

  @override
  String get cropAvatarTitle => 'Adjust photo';

  @override
  String get saveAvatar => 'Save photo';

  @override
  String get chooseAvatar => 'Profile picture';

  @override
  String get uploadAvatar => 'Upload photo';

  @override
  String get avatarPresets => 'Raccoon presets';

  @override
  String get avatarTooSmall => 'Image is too small (minimum 10 KB).';

  @override
  String get avatarTooLarge => 'Image is too large (maximum 5 MB).';

  @override
  String get avatarInvalidFormat =>
      'Could not read image. Use a JPG or PNG file.';

  @override
  String get personAppearance => 'Appearance';

  @override
  String get personLanguage => 'Language';

  @override
  String get allPeople => 'All People';

  @override
  String get filterByPersonTooltip => 'Filter by Person';

  @override
  String get peopleAndOwnership => 'People';

  @override
  String get peopleAndOwnershipSubtitle =>
      'Profiles, roles, passwords, and account ownership';

  @override
  String get addPerson => 'Add Person';

  @override
  String get editPerson => 'Edit Person';

  @override
  String get deletePerson => 'Delete Person';

  @override
  String get cannotDeleteOnlyAdmin =>
      'Cannot delete the only admin. Promote someone else first.';

  @override
  String get cannotDemoteOnlyAdmin =>
      'Cannot demote the only admin. Promote someone else first.';

  @override
  String get personName => 'Person Name';

  @override
  String get selectOwners => 'Assign Owners';

  @override
  String get customSplit => 'Custom Percentage Split';

  @override
  String get accountAssignments => 'Account Assignments & Split Ratios';

  @override
  String get colorBadge => 'Color Badge';

  @override
  String get settingsBackup => 'Backup & restore';

  @override
  String get exportSettingsDisclosureTitle => 'What goes into the file?';

  @override
  String get exportSettingsDisclosure =>
      'INCLUDED:\n• People, their roles, and account assignments\n• Account classifications, layout, and preferences\n• Prognosis settings and the Firefly URL\n\nNOT INCLUDED:\n• MCP agent keys. They never leave this device, so an agent needs a key issued where it will run.\n• Your Firefly data itself: accounts, transactions, budgets. That stays in Firefly III.\n• Custom profile photos and biometric unlock\n• The Firefly API token and password hashes, unless you set a backup passphrase on the next screen, which seals them into the file';

  @override
  String get exportSettingsContinue => 'Export';

  @override
  String get exportSettings => 'Export settings';

  @override
  String get exportSettingsDescription =>
      'Saves people and their roles, account assignments and classifications, layout, preferences, prognosis settings, and the Firefly URL to a JSON file.\n\nLeft out: MCP agent keys, which never leave this device; your Firefly data itself (accounts, transactions, budgets), which stays in Firefly III; custom profile photos; and biometric unlock. The Firefly API token and password hashes are only included if you set a backup passphrase, which encrypts them.';

  @override
  String get importSettings => 'Import settings';

  @override
  String get importSettingsDescription =>
      'Replaces what is on this device with a previously exported file: people and their roles, account assignments and classifications, layout, preferences, prognosis settings, and the Firefly connection if the file has one.\n\nDeletes MCP agent keys whose owner no longer exists afterwards. A key created before People were set up belongs to \"this device\", so importing people removes it and any agent using it stops working.\n\nDoes not restore custom profile photos or biometric unlock. Password login stays off unless the file carries portable password hashes and you enter its passphrase.';

  @override
  String get importSettingsConfirmTitle => 'Overwrite settings?';

  @override
  String get importSettingsConfirmMessage =>
      'REPLACED on this device:\n• People, their roles, and account assignments\n• Account classifications\n• Layout: side menu, columns, view mode, row density\n• Theme, language, dashboard period, page size, write-ahead days, undo limit\n• Prognosis settings\n• The Firefly connection, if the file carries one\n\nDELETED:\n• MCP agent keys whose owner no longer exists afterwards. A key created before People were set up belongs to \"this device\" and will be removed, so any agent using it stops working and needs a new key.\n\nNOT RESTORED:\n• Custom profile photos and biometric unlock\n• Password login, unless the file carries portable password hashes and you enter its passphrase';

  @override
  String get backupPassphraseExportTitle => 'Protect backup';

  @override
  String get backupPassphraseExportMessage =>
      'Choose a passphrase to encrypt the Firefly API token and password hashes in this file. You will need the same passphrase to import.';

  @override
  String get backupPassphraseImportTitle => 'Unlock backup';

  @override
  String get backupPassphraseImportMessage =>
      'Enter the passphrase used when this settings file was exported.';

  @override
  String get backupPassphrase => 'Backup passphrase';

  @override
  String get backupPassphraseRequired => 'Enter the backup passphrase.';

  @override
  String get backupPassphraseShow => 'Show passphrase';

  @override
  String get backupPassphraseHide => 'Hide passphrase';

  @override
  String settingsExportedTo(String path) {
    return 'Settings exported to $path';
  }

  @override
  String get settingsImported => 'Settings imported.';

  @override
  String settingsImportFailed(String error) {
    return 'Could not import settings: $error';
  }

  @override
  String get settingsExportSubject => 'FireRacoon settings';

  @override
  String get settingsExportText => 'FireRacoon settings backup';

  @override
  String get recordedBalance => 'Recorded';

  @override
  String get upcoming => 'Upcoming';
}
