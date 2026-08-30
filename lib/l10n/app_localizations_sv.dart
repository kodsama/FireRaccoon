// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get appTitle => 'FireRaccoon';

  @override
  String get appTagline => 'Den smartaste banditen för din budget.';

  @override
  String get appNameFire => 'Fire';

  @override
  String get appNameRaccoon => 'Raccoon';

  @override
  String get navDashboard => 'Översikt';

  @override
  String get navDashboardShort => 'Övers.';

  @override
  String get navAccounts => 'Konton';

  @override
  String get navTransactions => 'Transaktioner';

  @override
  String get navBudgets => 'Budgetar';

  @override
  String get navSubscriptions => 'Subscriptions & Recurring';

  @override
  String get navPiggyBanks => 'Piggy banks';

  @override
  String get navExpenses => 'Utgifter';

  @override
  String get navIncome => 'Income';

  @override
  String get navTransfers => 'Transfers';

  @override
  String get navLiabilities => 'Liabilities';

  @override
  String get navProjection => 'Prognos';

  @override
  String get navPrognosis => 'Prognosis';

  @override
  String get navSettings => 'Inställningar';

  @override
  String get netWorth => 'Nettoförmögenhet';

  @override
  String get search => 'Sök...';

  @override
  String get loading => 'Laddar…';

  @override
  String get fireflyUser => 'Firefly-användare';

  @override
  String get fireflyConnected => 'Firefly III · ansluten';

  @override
  String get fireflyDisconnected => 'Firefly III · frånkopplad';

  @override
  String get fireflyConnectionChecking => 'Firefly III · kontrollerar…';

  @override
  String get settingsTitle => 'Inställningar';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get language => 'Språk';

  @override
  String get selectLanguage => 'Välj språk';

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
  String get defaultCurrency => 'Standardvaluta';

  @override
  String get selectCurrency => 'Välj valuta';

  @override
  String get primaryCurrencyChangeWarning =>
      'Firefly III kan räkna om sparade belopp när standardvalutan ändras.';

  @override
  String primaryCurrencyChanged(String code) {
    return 'Standardvaluta satt till $code';
  }

  @override
  String failedToSetPrimaryCurrency(String error) {
    return 'Kunde inte ange standardvaluta: $error';
  }

  @override
  String get primaryCurrencyCurrent => 'Aktuell';

  @override
  String get changePrimaryCurrencyTitle => 'Byt standardvaluta';

  @override
  String changePrimaryCurrencyMessage(String code, String warning) {
    return 'Byt standardvaluta till $code? $warning';
  }

  @override
  String get changePrimaryCurrencyConfirm => 'Byt';

  @override
  String get connectToFireflyToLoad => 'Anslut Firefly III för att ladda';

  @override
  String get managedInFirefly => 'Hanteras i Firefly III';

  @override
  String get appearance => 'Utseende';

  @override
  String get raccoonMode => 'Raccoon-läge';

  @override
  String get themeStyle => 'Temastil';

  @override
  String get themeStyleSubtitle =>
      'Välj palett, accentfärg och ljusstyrka. Ändringar tillämpas direkt.';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get themeBrightness => 'Ljusstyrka';

  @override
  String get themeLight => 'Ljust';

  @override
  String get themeDark => 'Mörkt';

  @override
  String get themePalette => 'Palett';

  @override
  String get paletteClassic => 'Klassisk';

  @override
  String get paletteSpectrum => 'Spektrum';

  @override
  String get paletteRaccoon => 'Tvättbjörn';

  @override
  String get themeAccentColor => 'Accentfärg';

  @override
  String get themePreview => 'Förhandsvisning';

  @override
  String get done => 'Klar';

  @override
  String get accentGreen => 'Grön';

  @override
  String get accentTeal => 'Blågrön';

  @override
  String get accentBlue => 'Blå';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentRed => 'Röd';

  @override
  String get accentViolet => 'Violett';

  @override
  String get accentLime => 'Lime';

  @override
  String get accentSky => 'Himmel';

  @override
  String get accentCharcoal => 'Kol';

  @override
  String get accentSilver => 'Silver';

  @override
  String get accentTan => 'Beige';

  @override
  String get accentAmber => 'Bärnsten';

  @override
  String get accentSlate => 'Skiffer';

  @override
  String get accentMidnight => 'Midnatt';

  @override
  String get accentSmoke => 'Rök';

  @override
  String get accentPearl => 'Pärla';

  @override
  String get backendConnection => 'Backend-anslutning (Firefly III)';

  @override
  String get serverUrl => 'Server-URL';

  @override
  String get notConnected => 'Ej ansluten';

  @override
  String get oauth2Connection => 'OAuth2-anslutning';

  @override
  String get personalAccessToken => 'Personlig åtkomsttoken';

  @override
  String get notSet => 'Ej angiven';

  @override
  String get disconnect => 'Koppla från';

  @override
  String get fireflyConnectionTitle => 'Firefly III-anslutning';

  @override
  String get serverUrlLabel =>
      'Server-URL (t.ex. https://firefly.min-domän.se)';

  @override
  String get allowHttpConnections => 'Tillåt HTTP-anslutningar';

  @override
  String get authenticationMethod => 'Autentiseringsmetod';

  @override
  String get oauth2 => 'OAuth2';

  @override
  String get oauthClientId => 'OAuth-klient-ID';

  @override
  String get testConnection => 'Testa anslutning';

  @override
  String get connectionSuccessful => 'Anslutning lyckades!';

  @override
  String get connectionFailed =>
      'Anslutning misslyckades. Kontrollera URL och token.';

  @override
  String get loginViaBrowser => 'Logga in via webbläsare';

  @override
  String get cancel => 'Avbryt';

  @override
  String get save => 'Spara';

  @override
  String get delete => 'Radera';

  @override
  String errorGeneric(String error) {
    return 'Fel: $error';
  }

  @override
  String errorLoadingData(String error) {
    return 'Fel vid inläsning: $error';
  }

  @override
  String get tabInsights => 'Insikter';

  @override
  String get tabAccounts => 'Konton';

  @override
  String get tabFocus => 'Fokus';

  @override
  String get totalBalance => 'Totalsaldo';

  @override
  String incomeMonth(String month) {
    return 'Inkomst · $month';
  }

  @override
  String spendingMonth(String month) {
    return 'Utgifter · $month';
  }

  @override
  String savedMonth(String month) {
    return 'Sparat · $month';
  }

  @override
  String get snatchedFunds => 'Snodda medel';

  @override
  String get burntCash => 'Brändt kontant';

  @override
  String get stash => 'Gömma';

  @override
  String get snatched => 'Snoddat';

  @override
  String get burnt => 'Bränt';

  @override
  String get navDashboardRaccoon => 'Unket';

  @override
  String get navDashboardShortRaccoon => 'Unke';

  @override
  String get navAccountsRaccoon => 'Gömmor';

  @override
  String get navTransactionsRaccoon => 'Kupploggen';

  @override
  String get navBudgetsRaccoon => 'Bytplans';

  @override
  String get navSubscriptionsRaccoon => 'Recurring Raids';

  @override
  String get navPiggyBanksRaccoon => 'Mini Stashes';

  @override
  String get navExpensesRaccoon => 'Brännrapport';

  @override
  String get navProjectionRaccoon => 'Kristallbyte';

  @override
  String get navPrognosisRaccoon => 'Month-end loot';

  @override
  String get navSettingsRaccoon => 'Unkregler';

  @override
  String get netWorthRaccoon => 'Totalt byte';

  @override
  String get searchRaccoon => 'Sniffa…';

  @override
  String get accountsTitleRaccoon => 'Gömmor';

  @override
  String get transactionsTitleRaccoon => 'Kupploggen';

  @override
  String get budgetsTitleRaccoon => 'Bytplans';

  @override
  String get expensesTitleRaccoon => 'Brännrapport';

  @override
  String get projectionTitleRaccoon => 'Kristallbyte';

  @override
  String get settingsTitleRaccoon => 'Unkregler';

  @override
  String get tabInsightsRaccoon => 'Byteinfo';

  @override
  String get tabAccountsRaccoon => 'Gömmor';

  @override
  String get tabFocusRaccoon => 'Kupp-HQ';

  @override
  String get totalBalanceRaccoon => 'Full gömma';

  @override
  String incomeMonthRaccoon(String month) {
    return 'Snoddat · $month';
  }

  @override
  String spendingMonthRaccoon(String month) {
    return 'Bränt · $month';
  }

  @override
  String savedMonthRaccoon(String month) {
    return 'Gömt · $month';
  }

  @override
  String get cashFlowRaccoon => 'Byteflöde';

  @override
  String get whereMoneyGoesRaccoon => 'Vart bytet går';

  @override
  String get recentActivityRaccoon => 'Senaste kupper';

  @override
  String get yourAccountsRaccoon => 'Dina gömmor';

  @override
  String get budgetsAtGlanceRaccoon => 'Byte i korthet';

  @override
  String get viewAllAccountsRaccoon => 'Alla gömmor';

  @override
  String get assetAccountsRaccoon => 'Skattgömmor';

  @override
  String get liabilityAccountsRaccoon => 'Skulder & IOU';

  @override
  String get stocksAndFundsAccountsRaccoon => 'Börs gömmor';

  @override
  String get allAccountsRaccoon => 'Alla gömmor';

  @override
  String get accountsRaccoon => 'Gömmor';

  @override
  String get newTransactionRaccoon => 'Planera ett kupp';

  @override
  String get editTransactionRaccoon => 'Redigera kupp';

  @override
  String transactionsCountRaccoon(int count) {
    return '$count kupper';
  }

  @override
  String get oneTransactionRaccoon => '1 kupp';

  @override
  String get transactionTypeDepositRaccoon => 'Snatt';

  @override
  String get transactionTypeWithdrawalRaccoon => 'Bränn';

  @override
  String get transactionTypeTransferRaccoon => 'Gömmbyte';

  @override
  String get expenseLabelRaccoon => 'Bränn';

  @override
  String get spentRaccoon => 'Bränt';

  @override
  String get newBudgetRaccoon => 'Nytt bytplan';

  @override
  String get projectedBalanceRaccoon => 'Framtida byte';

  @override
  String get piggyBankRaccoon => 'Minigömma';

  @override
  String get transfersRaccoon => 'Gömmbyten';

  @override
  String get expensesFilterRaccoon => 'Bränningar';

  @override
  String get noTransactionsYetRaccoon => 'Inga kupper än';

  @override
  String get lookingAheadRaccoon => 'Kika framåt';

  @override
  String get openProjectionRaccoon => 'Spana in framtiden';

  @override
  String get editAccountRaccoon => 'Redigera gömma';

  @override
  String get accountNameRaccoon => 'Gömmanamn';

  @override
  String get filterAccountRaccoon => 'Filtrera gömma';

  @override
  String get sourceAccountRaccoon => 'Från gömma';

  @override
  String get destinationAccountRaccoon => 'Till gömma';

  @override
  String get totalSpentPeriodRaccoon => 'Totalt bränt under perioden';

  @override
  String get totalIncomePeriodRaccoon => 'Totalt snott under perioden';

  @override
  String get totalTransferredPeriodRaccoon => 'Total shuffled this period';

  @override
  String get newAccount => 'New Account';

  @override
  String get newLiability => 'New Liability';

  @override
  String get newExpense => 'New Expense';

  @override
  String get newAccountRaccoon => 'Ny gömma';

  @override
  String get newLiabilityRaccoon => 'Ny skuld';

  @override
  String get newExpenseRaccoon => 'Planera en bränning';

  @override
  String get income => 'Inkomst';

  @override
  String get spending => 'Utgifter';

  @override
  String get saved => 'Sparat';

  @override
  String get cashFlow => 'Kassaflöde';

  @override
  String get whereMoneyGoes => 'Vart pengarna går';

  @override
  String get noSpendingThisMonth => 'Inga utgifter denna månad än';

  @override
  String get recentActivity => 'Senaste aktivitet';

  @override
  String get viewAll => 'Visa alla';

  @override
  String get noTransactionsYet => 'Inga transaktioner än';

  @override
  String get lookingAhead => 'Framåtblick';

  @override
  String get spendingPaceWarning =>
      'Utgiftstakten kan överstiga inkomsten denna månad';

  @override
  String get openProjection => 'Öppna prognos';

  @override
  String get yourAccounts => 'Dina konton';

  @override
  String get budgetsAtGlance => 'Budgetar i korthet';

  @override
  String get viewAllAccounts => 'Visa alla konton';

  @override
  String get thirtyDayOutlook => '30-dagars utsikt';

  @override
  String get monthEndPrognosis => 'Prognos i månadens slut';

  @override
  String get projectedEndOfMonth => 'Månadens slut';

  @override
  String get includeCreditCardPayments => 'Inkludera kreditkortsbetalningar';

  @override
  String prognosisDeltaPositive(String amount) {
    return '+$amount förväntat';
  }

  @override
  String prognosisDeltaNegative(String amount) {
    return '$amount förväntat';
  }

  @override
  String get prognosisLowBalanceWarning =>
      'Prognostiserat saldo kan bli negativt';

  @override
  String get prognosisDebtWarning => 'Prognostiserad skuld kan öka';

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
  String get todaysTimeline => 'Dagens tidslinje';

  @override
  String get noActivityToday => 'Ingen aktivitet idag';

  @override
  String get noChangeVsLastMonth =>
      'Ingen förändring jämfört med förra månaden';

  @override
  String get newActivityThisMonth => 'Ny aktivitet denna månad';

  @override
  String percentVsLastMonth(String arrow, String percent) {
    return '$arrow$percent % jämfört med förra månaden';
  }

  @override
  String projectedSavingsHeadline(String amount) {
    return '$amount prognostiserat sparande denna månad';
  }

  @override
  String onPaceDetail(String amount) {
    return 'I takt för $amount sparat vid månadens slut';
  }

  @override
  String spendingOutpacingDetail(String amount) {
    return 'Utgifterna överstiger inkomsten med $amount';
  }

  @override
  String get accountsTitle => 'Konton';

  @override
  String get assetAccounts => 'Tillgångskonton';

  @override
  String get stocksAndFundsAccounts => 'Aktie- och fondkonton';

  @override
  String get liabilityAccounts => 'Skuldkonton';

  @override
  String get noAccountsFound => 'Inga konton hittades.';

  @override
  String get allAccounts => 'Alla konton';

  @override
  String get assetsOnly => 'Endast tillgångar';

  @override
  String get liabilitiesOnly => 'Endast skulder';

  @override
  String get accountName => 'Kontonamn';

  @override
  String get accountRoleDefault => 'Betalkonto';

  @override
  String get accountRoleShared => 'Delat konto';

  @override
  String get accountRoleSaving => 'Sparkonto';

  @override
  String get accountRoleCreditCard => 'Kreditkort';

  @override
  String get holdingAccountFundLabel => '(Fond)';

  @override
  String get holdingAccountStockLabel => '(Aktie)';

  @override
  String failedToUpdate(String error) {
    return 'Kunde inte uppdatera: $error';
  }

  @override
  String get name => 'Namn';

  @override
  String get transactionsTitle => 'Transaktioner';

  @override
  String filteredBy(String account) {
    return 'Filtrerat på: $account';
  }

  @override
  String get balance => 'Saldo:';

  @override
  String get balanceCheckMode => 'Kontrollera saldo';

  @override
  String get balanceCheckExpected => 'Förväntat saldo';

  @override
  String get balanceCheckStatement => 'Ditt saldo';

  @override
  String get balanceCheckStatementHint => 'Ange saldo från kontoutdrag';

  @override
  String get balanceCheckMatch => 'Saldona stämmer';

  @override
  String balanceCheckDifference(String amount) {
    return 'Skillnad: $amount';
  }

  @override
  String get balanceCheckEnterBalance => 'Ange ett saldo att jämföra';

  @override
  String get balanceCheckInvalidAmount => 'Ange ett giltigt belopp';

  @override
  String get balanceCheckSelectedBalance => 'Saldo från valda transaktioner';

  @override
  String get balanceCheckReconcile => 'Avstäm valda';

  @override
  String get balanceCheckReconciled => 'Valda transaktioner avstämda';

  @override
  String get balanceCheckNothingToReconcile =>
      'Inget att stämma av. Välj oavstämda transaktioner för att inkludera dem.';

  @override
  String get balanceCheckPaymentAccount => 'Betalkonto';

  @override
  String get balanceCheckPaybackDate => 'Återbetalningsdatum';

  @override
  String get balanceCheckSelectPaymentAccount => 'Välj betalkonto';

  @override
  String get balanceCheckNoPaymentAccounts => 'Inga giltiga betalkonton';

  @override
  String balanceCheckPaybackSummary(
    String amount,
    String account,
    String date,
  ) {
    return 'Återbetalning: $amount från $account den $date';
  }

  @override
  String get balanceCheckPaybackReconciled =>
      'Köp avstämda och återbetalningsöverföring skapad';

  @override
  String get balanceCheckNoEligiblePurchases => 'Välj minst ett kreditkortsköp';

  @override
  String get tooltipBalanceCheckMode => 'Jämför kontoutdragssaldo med Firefly';

  @override
  String get tooltipBalanceCheckIncludePending => 'Inkludera i saldokontroll';

  @override
  String get tooltipBalanceCheckExcludeReconciled =>
      'Exkludera från saldokontroll';

  @override
  String get transactionReconciled => 'Avstämd';

  @override
  String get partiallyReconciled => 'Delvis avstämd';

  @override
  String get tooltipTransactionReconciled => 'Verifierad mot ditt kontoutdrag';

  @override
  String get transactionReconciledUpdated => 'Avstämning uppdaterad';

  @override
  String failedToUpdateReconciliation(String error) {
    return 'Kunde inte uppdatera avstämning: $error';
  }

  @override
  String get reconciledFilter => 'Avstämning';

  @override
  String get reconciledFilterAll => 'Alla transaktioner';

  @override
  String get reconciledFilterReconciled => 'Endast avstämda';

  @override
  String get reconciledFilterUnreconciled => 'Endast ej avstämda';

  @override
  String get reconcile => 'Stäm av';

  @override
  String reconcileExpectedBalance(String amount) {
    return 'Förväntat saldo: $amount';
  }

  @override
  String get reconcileClickHint => 'Klicka för att stämma av';

  @override
  String get reconciliationTitle => 'Avstäm konto';

  @override
  String get reconciliationSubtitle => 'Matcha kontoutdraget med Firefly III';

  @override
  String get reconciliationAccount => 'Konto';

  @override
  String get reconciliationStartDate => 'Startdatum';

  @override
  String get reconciliationEndDate => 'Slutdatum';

  @override
  String get reconciliationStartBalance => 'Ingående saldo';

  @override
  String get reconciliationEndBalance => 'Utgående saldo';

  @override
  String get reconciliationStart => 'Starta avstämning';

  @override
  String get reconciliationRestart => 'Börja om';

  @override
  String get reconciliationOptions => 'Avstämningsalternativ';

  @override
  String get reconciliationGapZero =>
      'Markerade transaktioner matchar kontoutdraget.';

  @override
  String reconciliationGapPositive(String amount) {
    return 'Firefly har $amount mindre än kontoutdraget.';
  }

  @override
  String reconciliationGapNegative(String amount) {
    return 'Firefly har $amount mer än kontoutdraget.';
  }

  @override
  String get reconciliationStore => 'Spara avstämning';

  @override
  String get reconciliationStoreTitle => 'Spara avstämning?';

  @override
  String reconciliationStoreBody(int count) {
    return 'Markera $count transaktioner som avstämda.';
  }

  @override
  String get reconciliationCreateCorrectionTitle =>
      'Skapa korrigeringstransaktion?';

  @override
  String reconciliationCreateCorrectionBody(String amount) {
    return 'Det återstår en skillnad på $amount. FireRaccoon skapar en avstämningspost.';
  }

  @override
  String get reconciliationStored => 'Avstämning sparad';

  @override
  String reconciliationStoreFailed(String error) {
    return 'Kunde inte spara avstämning: $error';
  }

  @override
  String get reconciliationSelectAccount => 'Välj ett tillgångskonto';

  @override
  String get reconciliationInvalidBalances =>
      'Ange giltiga ingående och utgående saldon';

  @override
  String get reconciliationInvalidDateRange =>
      'Slutdatum måste vara samma dag eller senare än startdatum';

  @override
  String get reconciliationSelectTransactions =>
      'Markera minst en transaktion från kontoutdraget';

  @override
  String get reconciliationNoTransactions =>
      'Inga transaktioner hittades för perioden';

  @override
  String get reconciliationUnreconciled => 'Ej avstämd';

  @override
  String get reconciliationFutureTransaction => 'Efter periodens slut';

  @override
  String get futureTransactions => 'Framtida transaktioner';

  @override
  String get reconciliationOpenWizard => 'Avstäm konto';

  @override
  String get tooltipReconciliationWizard =>
      'Matcha transaktioner mot kontoutdraget';

  @override
  String get reconciliationUseFireflyBalances => 'Använd Firefly-saldon';

  @override
  String get reconciliationLoadingBalances => 'Hämtar saldon från Firefly…';

  @override
  String get reconciliationBalancesFilled => 'Saldon ifyllda från Firefly';

  @override
  String reconciliationBalancesFailed(String error) {
    return 'Kunde inte hämta saldon: $error';
  }

  @override
  String get notAvailable => 'Saknas';

  @override
  String get groupBy => 'Gruppera efter';

  @override
  String get groupByDate => 'Gruppera efter datum';

  @override
  String get groupByAccount => 'Gruppera efter konto';

  @override
  String get groupByPayee => 'Gruppera efter mottagare';

  @override
  String get groupByType => 'Gruppera efter typ';

  @override
  String get groupByCategory => 'Gruppera efter kategori';

  @override
  String get filterAccount => 'Filtrera konto';

  @override
  String get amount => 'Belopp';

  @override
  String get accounts => 'Konton';

  @override
  String get description => 'Beskrivning';

  @override
  String get sourceAccount => 'Källkonto';

  @override
  String get destinationAccount => 'Målkonto';

  @override
  String get payee => 'Mottagare';

  @override
  String get savingNotSupported => 'Sparning stöds inte i skrivskyddat läge.';

  @override
  String transactionDateCategory(String category, String date) {
    return '$category · $date';
  }

  @override
  String foreignAmount(String amount) {
    return '($amount)';
  }

  @override
  String get budgetsTitle => 'Budgetar';

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
      'Öppna återkommande abonnemang och räkningar.';

  @override
  String get subscriptionsTitleRaccoon => 'Recurring Raids & Schedules';

  @override
  String get newSubscriptionRaccoon => 'New Recurring Raid';

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
  String get piggyBanksTitleRaccoon => 'Mini Stashes';

  @override
  String get newPiggyBankRaccoon => 'New Mini Stash';

  @override
  String get newBudget => 'Ny budget';

  @override
  String get deleteBudget => 'Radera budget';

  @override
  String deleteBudgetMessage(String name) {
    return 'Är du säker på att du vill radera \"$name\"?';
  }

  @override
  String budgetDeleted(String name) {
    return 'Budget \"$name\" raderad.';
  }

  @override
  String failedToDeleteBudget(String error) {
    return 'Kunde inte radera budget: $error';
  }

  @override
  String get spent => 'Spenderat';

  @override
  String ofAmount(String amount) {
    return 'av $amount';
  }

  @override
  String overBudget(String amount) {
    return '$amount över budget';
  }

  @override
  String leftInBudget(String amount) {
    return '$amount kvar';
  }

  @override
  String budgetPerPeriod(String amount, String period) {
    return '$amount per $period';
  }

  @override
  String budgetLimitForPeriod(String amount, String period) {
    return '$amount för $period';
  }

  @override
  String get budgetCadenceDaily => 'dag';

  @override
  String get budgetCadenceWeekly => 'vecka';

  @override
  String get budgetCadenceMonthly => 'månad';

  @override
  String get budgetCadenceQuarterly => 'kvartal';

  @override
  String get budgetCadenceHalfYear => 'halvår';

  @override
  String get budgetCadenceYearly => 'år';

  @override
  String get viewPeriod => 'Visningsperiod';

  @override
  String get budgetAmount => 'Budgetbelopp';

  @override
  String get editBudget => 'Redigera budget';

  @override
  String get createBudget => 'Skapa budget';

  @override
  String get createPayee => 'Skapa mottagare';

  @override
  String get createCategory => 'Skapa kategori';

  @override
  String get budgetLimit => 'Budgetgräns';

  @override
  String get autoBudget => 'Auto-budgetbelopp';

  @override
  String get budgetAmountMode => 'Gränstyp';

  @override
  String get budgetAmountModeAuto => 'Återkommande period';

  @override
  String get budgetAmountModeDateRange => 'Fast datumintervall';

  @override
  String get budgetAmountModeNone => 'Inget belopp';

  @override
  String get budgetRepeatPeriod => 'Upprepas varje';

  @override
  String get budgetAutoType => 'Auto-budgetbeteende';

  @override
  String get budgetAutoTypeReset => 'Återställ varje period';

  @override
  String get budgetAutoTypeRollover => 'Rulla över oanvänt';

  @override
  String get budgetAutoTypeAdjusted => 'Justera efter utgifter';

  @override
  String get budgetAutoTypeNone => 'Ingen';

  @override
  String get budgetActive => 'Aktiv';

  @override
  String get budgetPeriodDaily => 'Dagligen';

  @override
  String get budgetPeriodWeekly => 'Veckovis';

  @override
  String get budgetPeriodMonthly => 'Månadsvis';

  @override
  String get budgetPeriodQuarterly => 'Kvartalsvis';

  @override
  String get budgetPeriodHalfYear => 'Halvårsvis';

  @override
  String get budgetPeriodYearly => 'Årsvis';

  @override
  String get tooltipBudgetAmountMode =>
      'Återkommande auto-budget, fast intervall eller ingen gräns';

  @override
  String get tooltipBudgetRepeatPeriod =>
      'Hur ofta budgetbeloppet gäller (t.ex. månadsvis)';

  @override
  String get tooltipBudgetAutoType =>
      'Vad som händer i början av varje budgetperiod';

  @override
  String get tooltipBudgetStartDate => 'Första dag gränsen gäller';

  @override
  String get tooltipBudgetEndDate => 'Sista dag gränsen gäller';

  @override
  String get tooltipBudgetActive =>
      'Inaktiva budgetar döljs som standard i Firefly';

  @override
  String get tooltipBudgetNotes => 'Valfria anteckningar för budgeten';

  @override
  String get tooltipBudgetCurrency => 'Valuta för budgetbeloppet';

  @override
  String get expensesTitle => 'Utgifter';

  @override
  String get clearFilters => 'Rensa filter';

  @override
  String get overview => 'Översikt';

  @override
  String get byCategory => 'Per kategori';

  @override
  String get allCategories => 'Alla kategorier';

  @override
  String get allTypes => 'Alla typer';

  @override
  String get expensesFilter => 'Utgifter';

  @override
  String get transfers => 'Överföringar';

  @override
  String get expensePeriodWeek => 'Denna vecka';

  @override
  String get expensePeriodMonth => 'Denna månad';

  @override
  String get expensePeriodQuarter => 'Detta kvartal';

  @override
  String get expensePeriodSemester => 'Detta halvår';

  @override
  String get expensePeriodYear => 'Detta år';

  @override
  String get expensePeriodAll => 'All tid';

  @override
  String get dashboardPeriodThisWeek => 'Denna vecka';

  @override
  String get dashboardPeriodLastWeek => 'Förra veckan';

  @override
  String get dashboardPeriodThisMonth => 'Denna månad';

  @override
  String get dashboardPeriodLastMonth => 'Förra månaden';

  @override
  String get dashboardPeriodThisQuarter => 'Detta kvartal';

  @override
  String get dashboardPeriodLastQuarter => 'Förra kvartalet';

  @override
  String get dashboardPeriodThisYear => 'I år';

  @override
  String get dashboardPeriodLastYear => 'Förra året';

  @override
  String get dashboardPeriodLast2Years => 'Senaste 2 åren';

  @override
  String get dashboardPeriodLast5Years => 'Senaste 5 åren';

  @override
  String get dashboardPeriodLast10Years => 'Senaste 10 åren';

  @override
  String get dashboardPeriodAll => 'Allt';

  @override
  String get deltaComparisonPreviousWeek => 'föregående vecka';

  @override
  String get deltaComparisonPreviousMonth => 'föregående månad';

  @override
  String get deltaComparisonPreviousQuarter => 'föregående kvartal';

  @override
  String get deltaComparisonPreviousYear => 'föregående år';

  @override
  String get deltaComparisonPrevious2Years => 'föregående 2 år';

  @override
  String get deltaComparisonPrevious5Years => 'föregående 5 år';

  @override
  String get deltaComparisonPrevious10Years => 'föregående 10 år';

  @override
  String get deltaComparisonCustomPeriod => 'föregående period';

  @override
  String noChangeVsComparisonPeriod(String period) {
    return 'Ingen förändring jämfört med $period';
  }

  @override
  String newActivityVsComparisonPeriod(String period) {
    return 'Ny aktivitet jämfört med $period';
  }

  @override
  String percentVsComparisonPeriod(
    String arrow,
    String percent,
    String period,
  ) {
    return '$arrow$percent% jämfört med $period';
  }

  @override
  String get dateRangeSeparator => '–';

  @override
  String get dateEllipsis => '…';

  @override
  String get projectionTitle => 'Prognos';

  @override
  String get projectedBalance => 'Prognostiserat saldo';

  @override
  String get visualization => 'Visualisering';

  @override
  String get parameters => 'Parametrar';

  @override
  String predictedBalances(String period) {
    return 'Prognostiserade saldon · $period';
  }

  @override
  String get noAccountsLoaded => 'Inga konton inlästa';

  @override
  String get scenarioSummary => 'Scenarioöversikt';

  @override
  String nowAmount(String amount) {
    return 'nu $amount';
  }

  @override
  String get worstCase => 'Värsta fall';

  @override
  String get expected => 'Förväntat';

  @override
  String get bestCase => 'Bästa fall';

  @override
  String get moveSliderToSeeImpact => 'Flytta reglaget för att se effekten';

  @override
  String whatIfImpact(String amount, String period) {
    return '+$amount under $period';
  }

  @override
  String get projectionPeriod3Months => '3 månader';

  @override
  String get projectionPeriod6Months => '6 månader';

  @override
  String get projectionPeriod1Year => '1 år';

  @override
  String get projectionPeriod3Years => '3 år';

  @override
  String get projectionTypeSavings => 'Sparkvot';

  @override
  String get projectionTypeCompound => 'Ränta på ränta';

  @override
  String get projectionTypePortfolio => 'Portfölj (volatil)';

  @override
  String get projectionTypeCashflow => 'Kassaflöde';

  @override
  String get projectionTypeSavingsDesc =>
      'Linjär prognos baserad på ditt historiska nettosparande';

  @override
  String get projectionTypeCompoundDesc =>
      'Saldo växer med ränta på ränta plus insättningar';

  @override
  String get projectionTypePortfolioDesc =>
      'Förväntad avkastning med värsta/bästa band baserat på volatilitet';

  @override
  String get projectionTypeCashflowDesc =>
      'Inkomst minus utgifter med diskretionära justeringar';

  @override
  String get chartStyleFan => 'Solfjädersdiagram';

  @override
  String get chartStyleLines => 'Tre linjer';

  @override
  String get chartStyleScenarios => 'Scenariokort';

  @override
  String get whatIfSpending => 'Tänk om-utgifter';

  @override
  String get annualReturn => 'Årlig avkastning';

  @override
  String get volatility => 'Volatilitet';

  @override
  String projectionAlertLiability(String name, String balance) {
    return 'I värsta fall kan $name nå $balance tidigare än väntat.';
  }

  @override
  String get projectionAlertBelowZero =>
      'Värsta prognosen går under noll inom vald period.';

  @override
  String get projectionAlertActionLiability =>
      'Överväg att flytta medel från ett sparkonto.';

  @override
  String get projectionAlertActionSpending =>
      'Granska diskretionära utgifter eller öka sparandet.';

  @override
  String get confirmTypeWord => 'Skriv ';

  @override
  String get confirmToConfirm => ' för att bekräfta:';

  @override
  String get confirmHint => 'Skriv ordet ovan…';

  @override
  String currencyPair(String name, String symbol) {
    return '$name ($symbol)';
  }

  @override
  String budgetSpentFraction(String spent, String total) {
    return '$spent / $total';
  }

  @override
  String get editAccount => 'Redigera konto';

  @override
  String get editAction => 'Redigera';

  @override
  String get filterAllShort => 'Alla';

  @override
  String get filterAssetsShort => 'Tillgångar';

  @override
  String get filterLiabilitiesShort => 'Skulder';

  @override
  String get showInactiveAccounts => 'Visa inaktiva konton';

  @override
  String get showInactiveAccountsShort => 'Inaktiva';

  @override
  String get accountInactive => 'Inaktiv';

  @override
  String get unknown => 'Okänd';

  @override
  String showingTransactionsOfTotal(int loaded, int total) {
    return 'Visar $loaded av $total transaktioner';
  }

  @override
  String transactionsCount(int count) {
    return '$count transaktioner';
  }

  @override
  String get oneTransaction => '1 transaktion';

  @override
  String deleteBudgetConfirmBody(String name) {
    return 'Är du säker på att du vill radera budgeten \"$name\"? Detta kan inte ångras.';
  }

  @override
  String get scrollForMore => 'Scrolla för mer…';

  @override
  String get noTransactionsMatchFilters =>
      'Inga transaktioner matchar de aktuella filtren.';

  @override
  String get category => 'Kategori';

  @override
  String get totalSpentPeriod => 'Totalt spenderat denna period';

  @override
  String get totalIncomePeriod => 'Total inkomst denna period';

  @override
  String get totalTransferredPeriod => 'Totalt överfört denna period';

  @override
  String get totalPeriod => 'Totalt denna period';

  @override
  String get volatilityUncertainty => 'Volatilitet / osäkerhet';

  @override
  String get editTransaction => 'Redigera transaktion';

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
  String get expenseLabel => 'Utgift';

  @override
  String get transactionTypeDeposit => 'Insättning';

  @override
  String get transactionTypeWithdrawal => 'Uttag';

  @override
  String get transactionTypeTransfer => 'Överföring';

  @override
  String get dataAndLoading => 'Data och inläsning';

  @override
  String get transactionPageSize => 'Transaktioner per sida';

  @override
  String get transactionPageSizeDescription =>
      'Hur många transaktioner som laddas vid varje scroll. Gäller transaktionslistan.';

  @override
  String transactionPageSizeValue(int count) {
    return '$count per sida';
  }

  @override
  String get defaultPeriod => 'Default period';

  @override
  String get defaultPeriodDescription =>
      'Applied when opening the dashboard, expenses, income, transfers, and transactions.';

  @override
  String get customDateRange => 'Anpassat intervall';

  @override
  String get pickDates => 'Välj datum';

  @override
  String get budgetStatusOnTrack => 'Inom budget';

  @override
  String get budgetStatusOver => 'Över budget';

  @override
  String whatIfCutSpending(int percent) {
    return 'Vad händer om jag minskar diskretionära utgifter med $percent %?';
  }

  @override
  String get usesAveragePatterns =>
      'Använder dina genomsnittliga inkomst- och utgiftsmönster från transaktioner.';

  @override
  String get historicalNetSavingsNote =>
      'Baserat på historiskt nettobesparing. Justera osäkerheten för att bredda eller smalna av bandet.';

  @override
  String get accountFilterLabel => 'Konto';

  @override
  String get noTransactionsForBudget => 'Inga transaktioner för denna budget.';

  @override
  String get noTransactionsForAccount => 'Inga transaktioner för detta konto.';

  @override
  String get deleteAccount => 'Ta bort konto';

  @override
  String deleteAccountConfirmBody(String name) {
    return 'Är du säker på att du vill ta bort kontot \"$name\"? Detta kan inte ångras.';
  }

  @override
  String accountDeleted(String name) {
    return 'Kontot \"$name\" har tagits bort.';
  }

  @override
  String failedToDeleteAccount(String error) {
    return 'Det gick inte att ta bort kontot: $error';
  }

  @override
  String get budgetNameHint => 'Budgetnamn';

  @override
  String budgetAmountWithSymbol(String symbol) {
    return 'Budgetbelopp ($symbol)';
  }

  @override
  String get chartLegendActual => 'Faktisk';

  @override
  String get chartLegendWorst => 'Sämst';

  @override
  String get chartLegendBest => 'Bäst';

  @override
  String get chartLegendWorstBest => 'Sämst ↔ Bäst';

  @override
  String get today => 'idag';

  @override
  String get mcpServer => 'MCP-server';

  @override
  String mcpStatusFailed(String error) {
    return 'Misslyckades: $error';
  }

  @override
  String mcpStatusRunning(int port) {
    return 'Kör på port $port';
  }

  @override
  String get mcpStatusStarting => 'Startar…';

  @override
  String get mcpStatusNoKeys => 'No agent keys yet, so the server is idle';

  @override
  String get mcpAgentKeys => 'Agent keys';

  @override
  String get mcpAgentKeysHint =>
      'Agents authenticate with a FireRaccoon key, not your Firefly III token. Each key acts as the person who created it.';

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
      'Paste this into your MCP client as initialize.params.apiKey, or set FIRERACCOON_API_KEY. You can reopen it later from this list.';

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
  String get splitMainAmount => 'Totalt belopp';

  @override
  String get tooltipSplitMainAmount =>
      'Transaktionens totalsumma. Delbeloppen måste summera till detta innan sparande.';

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
  String get newIncomeRaccoon => 'New Snatch';

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
  String get navIncomeRaccoon => 'Snatched';

  @override
  String get navTransfersRaccoon => 'Stash Shuffles';

  @override
  String get navLiabilitiesRaccoon => 'Debts';

  @override
  String get incomeTitleRaccoon => 'Snatched Funds';

  @override
  String get transfersTitleRaccoon => 'Stash Shuffles';

  @override
  String get newTransferActionRaccoon => 'New Stash Shuffle';

  @override
  String get liabilitiesTitleRaccoon => 'Debts Owed';

  @override
  String tooltipOpenSection(String section) {
    return 'Öppna $section.';
  }

  @override
  String get tooltipOpenDashboard =>
      'Öppna översikten med dina viktigaste nyckeltal.';

  @override
  String get tooltipOpenAccounts => 'Öppna dina konton och saldon.';

  @override
  String get tooltipOpenTransactions => 'Öppna alla transaktioner och filter.';

  @override
  String get tooltipOpenBudgets => 'Öppna budgetar och utgiftsprogress.';

  @override
  String get tooltipOpenPiggyBanks => 'Öppna sparmål och sparbössor.';

  @override
  String get tooltipOpenExpenses => 'Öppna utgiftsanalyser.';

  @override
  String get tooltipOpenIncome => 'Öppna inkomstanalyser.';

  @override
  String get tooltipOpenTransfers =>
      'Öppna historik och analys av överföringar.';

  @override
  String get tooltipOpenLiabilities =>
      'Öppna översikt över skulder och åtaganden.';

  @override
  String get tooltipOpenProjection => 'Öppna prognoser och scenarier.';

  @override
  String get tooltipOpenPrognosis =>
      'Öppna prognos för kontosaldo vid månadsslut.';

  @override
  String get projectionTabLongTerm => 'Long-term forecast';

  @override
  String get tooltipOpenSettings =>
      'Öppna inställningar och Firefly-anslutning.';

  @override
  String get tooltipToggleSidebar => 'Expandera eller fäll ihop sidofältet.';

  @override
  String get tooltipSearchTransactions => 'Sök text på den aktuella sidan.';

  @override
  String get tooltipToggleViewMode => 'Växla mellan list- och rutnätsvy.';

  @override
  String get refreshFromFirefly => 'Uppdatera';

  @override
  String get tooltipRefreshFromFirefly => 'Hämta om data från Firefly III';

  @override
  String get viewModeCards => 'Kort';

  @override
  String get viewModeRows => 'Rader';

  @override
  String get viewModeTightRows => 'Täta rader';

  @override
  String get columnSelection => 'Välj kolumner';

  @override
  String get columnDate => 'Datum';

  @override
  String get columnAccount => 'Konto';

  @override
  String get columnType => 'Läge';

  @override
  String get columnPayee => 'Mottagare';

  @override
  String get columnDescription => 'Kommentar';

  @override
  String get columnCategory => 'Kategori';

  @override
  String get columnBudget => 'Budget';

  @override
  String get columnAmount => 'Belopp';

  @override
  String get columnReconciled => 'Avstämd';

  @override
  String get columnBalance => 'Saldo';

  @override
  String get tooltipTransactionType => 'Välj transaktionstyp.';

  @override
  String get tooltipFieldDescription => 'Vad den här transaktionen gäller.';

  @override
  String get tooltipFieldSourceAccount => 'Konto pengarna kommer från.';

  @override
  String get tooltipFieldDestinationAccount => 'Konto pengarna går till.';

  @override
  String get tooltipSwapTransferAccounts => 'Byt plats på de två kontona.';

  @override
  String get disconnectConfirmTitle => 'Koppla från Firefly III';

  @override
  String get connectionFailedNotFirefly =>
      'Adressen svarade, men inte med Firefly III:s API. Kontrollera serveradressen: en gränssnittsadress, eller en bakom en inloggningssida, svarar på varje sökväg med en webbsida.';

  @override
  String get connectionFailedUnauthorized =>
      'Servern svarade och avvisade token. Kontrollera den personliga åtkomsttoken.';

  @override
  String get connectionFailedUnreachable =>
      'Kunde inte nå servern. Kontrollera adressen och att den körs.';

  @override
  String get connectionFailedInsecure =>
      'Det är en oskyddad http://-adress. Slå på Tillåt HTTP-anslutningar om det är meningen.';

  @override
  String get disconnectConfirmMessage =>
      'Detta tar bort serveradressen och den personliga åtkomsttoken från enhetens nyckelring. Du måste ange dem igen för att ansluta på nytt.';

  @override
  String get tooltipFieldDate => 'Datum och tid för transaktionen.';

  @override
  String get tooltipFieldAmount => 'Huvudbelopp i vald valuta.';

  @override
  String get tooltipFieldCurrency => 'Primär valuta för den här raden.';

  @override
  String get tooltipFieldForeignAmount => 'Valfritt belopp i annan valuta.';

  @override
  String get tooltipFieldForeignCurrency =>
      'Valuta för det utländska beloppet.';

  @override
  String get tooltipFieldBudget => 'Koppla raden till en budget.';

  @override
  String get tooltipFieldCategory => 'Kategori för rapporter och filter.';

  @override
  String get tooltipFieldPiggyBank => 'Koppla raden till en sparbössa.';

  @override
  String get tooltipFieldTags =>
      'Taggar separerade med kommatecken för snabb filtrering.';

  @override
  String get tooltipFieldSubscription => 'Koppla raden till ett abonnemang.';

  @override
  String get tooltipFieldInterestDate =>
      'Valfritt ränte- eller bokföringsdatum.';

  @override
  String get tooltipFieldAttachments =>
      'Bilagor visas, men uppladdning stöds inte ännu.';

  @override
  String get tooltipFieldNotes => 'Extra anteckningar för senare referens.';

  @override
  String get tooltipAddSplit => 'Lägg till ytterligare en splitrad.';

  @override
  String get tooltipRemoveSplit => 'Ta bort den här splitraden.';

  @override
  String get tooltipCancelTransaction => 'Avbryt ändringar och stäng.';

  @override
  String get tooltipSaveTransaction => 'Spara transaktionen.';

  @override
  String get tooltipCancel => 'Kasta ändringar och stäng utan att spara.';

  @override
  String get tooltipSave => 'Spara dina ändringar.';

  @override
  String get tooltipCreate => 'Skapa det nya objektet.';

  @override
  String get tooltipConfirmDelete => 'Ta bort detta objekt permanent.';

  @override
  String get tooltipConfirmChallenge =>
      'Skriv utmaningsordet för att bekräfta borttagning.';

  @override
  String get tooltipExpandDetails => 'Visa fler detaljer.';

  @override
  String get tooltipCollapseDetails => 'Dölj extra detaljer.';

  @override
  String get tooltipClearDate => 'Ta bort det valda datumet.';

  @override
  String get tooltipAccountName => 'Visningsnamn i listor och rapporter.';

  @override
  String get tooltipAccountCurrentBalance =>
      'Aktuellt saldo från Firefly per idag.';

  @override
  String get tooltipAccountEndOfMonthBalance =>
      'Prognostiserat saldo på det valda datumet, inklusive planerade transaktioner, upprepningar och räkningar.';

  @override
  String get tooltipBalanceDatePick => 'Visa saldon vid ett annat datum';

  @override
  String get tooltipBalanceDateReset => 'Tillbaka till månadens slut';

  @override
  String get tooltipBalanceBeyondForecast =>
      'Prognosen sträcker sig inte så långt fram, så detta är den sista beräknade siffran.';

  @override
  String get tooltipRecordedBalance =>
      'Saldo som bokföringen håller till och med detta datum, inklusive transaktioner som redan är daterade framåt.';

  @override
  String get tooltipBudgetName => 'Namn på denna utgiftsbudget.';

  @override
  String get tooltipBudgetAmount => 'Gränsbelopp för denna budgetperiod.';

  @override
  String get tooltipSubscriptionName =>
      'Namn på återkommande räkning eller prenumeration.';

  @override
  String get tooltipSubscriptionCurrency => 'Valuta för förväntade belopp.';

  @override
  String get tooltipSubscriptionAmountMin =>
      'Lägsta förväntade kostnad per period.';

  @override
  String get tooltipSubscriptionAmountMax =>
      'Högsta förväntade kostnad per period.';

  @override
  String get tooltipSubscriptionStartDate =>
      'Datum då prenumerationen börjar eller registrerades.';

  @override
  String get tooltipSubscriptionRepeats =>
      'Hur ofta denna prenumeration upprepas.';

  @override
  String get tooltipSubscriptionSkip =>
      'Hoppa över nästa N förekomster innan debitering.';

  @override
  String get tooltipSubscriptionEndDate =>
      'Valfritt datum när prenumerationen avslutas.';

  @override
  String get tooltipSubscriptionExtensionDate =>
      'Valfritt datum för förlängning eller paus.';

  @override
  String get tooltipSubscriptionGroup =>
      'Valfri gruppetikett för att organisera prenumerationer.';

  @override
  String get tooltipSubscriptionActive =>
      'Om denna prenumeration är aktiv just nu.';

  @override
  String get tooltipPiggyBankName => 'Namn på detta sparmål.';

  @override
  String get tooltipPiggyBankTargetAmount => 'Totalt belopp du vill spara.';

  @override
  String get tooltipPiggyBankCurrency => 'Valuta för mål och spårad besparing.';

  @override
  String get tooltipPiggyBankAccounts =>
      'Konton vars saldon räknas mot detta mål.';

  @override
  String tooltipPiggyBankAccount(String name) {
    return 'Inkludera $name i denna spargris.';
  }

  @override
  String get tooltipPiggyBankStartDate => 'När du började följa detta mål.';

  @override
  String get tooltipPiggyBankTargetDate => 'Valfri deadline för att nå målet.';

  @override
  String get tooltipPiggyBankGroup =>
      'Valfri gruppetikett för att organisera spargrisar.';

  @override
  String get tooltipThemeLight => 'Använd ljust färgschema.';

  @override
  String get tooltipThemeDark => 'Använd mörkt färgschema.';

  @override
  String get tooltipThemePaletteClassic =>
      'Klassisk palett inspirerad av Firefly.';

  @override
  String get tooltipThemePaletteSpectrum =>
      'Livfull flerfärgad kategoripalett.';

  @override
  String get tooltipThemePaletteRaccoon => 'Lekfull tvättbjörnstema-palett.';

  @override
  String get tooltipThemeAccent =>
      'Accentfärg för knappar, länkar och markeringar.';

  @override
  String tooltipThemeAccentOption(String name) {
    return 'Använd $name som accentfärg.';
  }

  @override
  String get tooltipThemeDone => 'Stäng och behåll valt tema.';

  @override
  String get repeatIntervalLabel => 'Intervall';

  @override
  String get repeatIntervalHelp =>
      'Hur ofta upprepningen sker, t.ex. var tredje månad.';

  @override
  String repeatEveryNDays(int count) {
    return 'Var $count:e dag';
  }

  @override
  String repeatEveryNWeeks(int count) {
    return 'Var $count:e vecka';
  }

  @override
  String repeatEveryNMonths(int count) {
    return 'Var $count:e månad';
  }

  @override
  String repeatEveryNYears(int count) {
    return 'Vart $count:e år';
  }

  @override
  String get writeAheadDays => 'Skriv återkommande transaktioner i förväg';

  @override
  String get writeAheadDaysDescription =>
      'Skapa kommande återkommande transaktioner så här många dagar i förväg.';

  @override
  String get writeAheadOff => 'Av';

  @override
  String writeAheadNDays(int count) {
    return '$count dagar';
  }

  @override
  String get plannedLabel => 'Planerad';

  @override
  String get navHistory => 'Historik';

  @override
  String get navHistoryRaccoon => 'Kaptr replay';

  @override
  String get tooltipOpenHistory => 'Öppna historik för ångra/gör om.';

  @override
  String get tooltipUndo => 'Ångra den senaste åtgärden.';

  @override
  String get tooltipRedo => 'Gör om den senast ångrade åtgärden.';

  @override
  String get undo => 'Ångra';

  @override
  String get redo => 'Gör om';

  @override
  String get clear => 'Rensa';

  @override
  String get advanced => 'Avancerat';

  @override
  String get undoHistorySize => 'Storlek på ångra/gör om-historik';

  @override
  String undoHistoryStoredEntries(int count, int limit) {
    return 'Lagrade poster: $count / $limit';
  }

  @override
  String get openHistoryScreen => 'Öppna historikskärmen';

  @override
  String undoHistoryLimitRange(int min, int defaultValue, int max) {
    return 'Min $min  •  Standard $defaultValue  •  Max $max';
  }

  @override
  String get searchHistory => 'Sök i historik';

  @override
  String get allActions => 'Alla åtgärder';

  @override
  String get noHistoryEntriesMatchFilters => 'Inga poster matchar filtren.';

  @override
  String historyExportedTo(String path) {
    return 'Historik exporterad till $path';
  }

  @override
  String get historyExportedAndShared =>
      'Historik exporterad och delningsvy öppnad';

  @override
  String get exportJson => 'Exportera JSON';

  @override
  String get exportAndShare => 'Exportera och dela';

  @override
  String get jumpToCurrent => 'Hoppa till aktuell';

  @override
  String get historyExportSubject => 'Historikexport';

  @override
  String get historyExportText => 'FireRaccoon-historikexport';

  @override
  String get historySectionToday => 'Idag';

  @override
  String get historySectionYesterday => 'Igår';

  @override
  String get historySectionOlder => 'Äldre';

  @override
  String historyEntriesCount(int count, int limit) {
    return '$count / $limit';
  }

  @override
  String get undoActionTypeThemeMode => 'Temaläge';

  @override
  String get undoActionTypeThemePalette => 'Temapalett';

  @override
  String get undoActionTypeThemeAccent => 'Temaccent';

  @override
  String get undoActionTypeThemeFunMode => 'Roligt läge';

  @override
  String get undoActionTypeLocale => 'Språk';

  @override
  String get undoActionTypeViewMode => 'Visningsläge';

  @override
  String get undoActionTypeTransactionPageSize => 'Transaktioner per sida';

  @override
  String get undoActionTypePrognosisMode => 'Prognosvisningsläge';

  @override
  String get undoActionTypePrognosisHorizon => 'Prognoshorisont';

  @override
  String get undoActionTypePrognosisInclusion => 'Prognosinkludering';

  @override
  String get undoActionTypePrognosisMarginPercent => 'Prognosmarginal';

  @override
  String get undoActionTypeAccountCreate => 'Konto skapat';

  @override
  String get undoActionTypeAccountUpdate => 'Konto uppdaterat';

  @override
  String get undoActionTypeAccountDelete => 'Konto raderat';

  @override
  String get undoActionTypeBudgetCreate => 'Budget skapat';

  @override
  String get undoActionTypeBudgetUpdate => 'Budget uppdaterat';

  @override
  String get undoActionTypeBudgetDelete => 'Budget raderat';

  @override
  String get undoActionTypeTransactionCreate => 'Transaktion skapad';

  @override
  String get undoActionTypeTransactionUpdate => 'Transaktion uppdaterad';

  @override
  String get undoActionTypeTransactionDelete => 'Transaktion raderad';

  @override
  String get undoActionTypeBillCreate => 'Abonnemang skapat';

  @override
  String get undoActionTypeBillUpdate => 'Abonnemang uppdaterat';

  @override
  String get undoActionTypeBillDelete => 'Abonnemang raderat';

  @override
  String get undoActionTypeRecurrenceCreate =>
      'Återkommande transaktion skapad';

  @override
  String get undoActionTypeRecurrenceUpdate =>
      'Återkommande transaktion uppdaterad';

  @override
  String get undoActionTypeRecurrenceDelete =>
      'Återkommande transaktion raderad';

  @override
  String get undoActionTypePiggyBankCreate => 'Spargris skapad';

  @override
  String get undoActionTypePiggyBankUpdate => 'Spargris uppdaterad';

  @override
  String get undoActionTypePiggyBankDelete => 'Spargris raderad';

  @override
  String get undoActionTypeLiabilityCreate => 'Skuld skapad';

  @override
  String get searchHintTitle => 'Börja skriva för att söka';

  @override
  String get searchHintSubtitle =>
      'Skriv för att filtrera efter beskrivning, konto, kategori, tagg, anteckning eller belopp.';

  @override
  String get noSuggestions => 'Inga matchande förslag';

  @override
  String get invalidAmount =>
      'Beloppet måste vara ett giltigt tal större än 0.';

  @override
  String get invalidForeignAmount =>
      'Utländska beloppet måste vara ett giltigt tal större än 0.';

  @override
  String get exportFireflyData => 'Säkerhetskopiera Firefly-data';

  @override
  String get exportFireflyDataDescription =>
      'Sparar en ögonblicksbild av dina Firefly-data till en JSON-fil: konton, transaktioner med varje delpost, budgetar, kategorier, etiketter, räkningar, spargrisar, återkommande regler och valutor.\n\nDetta är inte en fullständig säkerhetskopia. Firefly III har ingen inbyggd säkerhetskopiering, och en app som går via dess API kan inte nå databasen, uppladdade bilagor eller instansnyckeln. För att återställa ett fungerande Firefly krävs ett volymarkiv taget på servern; se distributionsguiden.';

  @override
  String fireflyDataExportedTo(String path) {
    return 'Firefly-data exporterade till $path';
  }

  @override
  String get missingInformation => 'Saknad information';

  @override
  String get missingDescription => 'Ange en beskrivning.';

  @override
  String get missingAmount => 'Ange ett belopp.';

  @override
  String get missingAccounts => 'Välj både käll- och destinationskonto.';

  @override
  String get appUsers => 'Appanvändare';

  @override
  String get enableAppUsers => 'Aktivera appanvändare';

  @override
  String get enableAppUsersDescription =>
      'Add password-protected profiles for the people who use this app. Everyone still shares the same Firefly III data.';

  @override
  String get createAdmin => 'Skapa administratörskonto';

  @override
  String get createAdminDescription =>
      'You will be the first admin. You can add more accounts afterwards.';

  @override
  String get addUser => 'Lägg till användare';

  @override
  String get editUser => 'Redigera användare';

  @override
  String get deleteUser => 'Ta bort användare';

  @override
  String get role => 'Roll';

  @override
  String get roleAdmin => 'Administratör';

  @override
  String get roleUser => 'Användare';

  @override
  String get roleViewer => 'Granskare';

  @override
  String get roleAdminDescription =>
      'Full access, including Firefly settings and user management.';

  @override
  String get roleUserDescription => 'Can add and edit financial data.';

  @override
  String get roleViewerDescription => 'Read-only access.';

  @override
  String get requireLogin => 'Kräv inloggning vid varje start';

  @override
  String get requireLoginDescription =>
      'When off, signed-in users stay signed in between launches.';

  @override
  String get switchUser => 'Switch user';

  @override
  String get selectUserSubtitle =>
      'Choose whose profile to use. No password needed while login is not required.';

  @override
  String get assignPerson => 'Kopplad person';

  @override
  String get noPersonAssigned => 'Ingen';

  @override
  String get myAccount => 'Mitt konto';

  @override
  String get changePassword => 'Byt lösenord';

  @override
  String get setPassword => 'Set password';

  @override
  String get clearPassword => 'Remove password';

  @override
  String get passwordOptionalHint =>
      'Optional. Leave blank to skip. Required only if login with password is enabled.';

  @override
  String get currentPassword => 'Nuvarande lösenord';

  @override
  String get newPassword => 'Nytt lösenord';

  @override
  String get confirmNewPassword => 'Bekräfta nytt lösenord';

  @override
  String get logout => 'Logga ut';

  @override
  String get login => 'Logga in';

  @override
  String get username => 'Användarnamn';

  @override
  String get password => 'Lösenord';

  @override
  String get loginSubtitle => 'Logga in för att fortsätta till FireRaccoon.';

  @override
  String get loginMissingFields => 'Ange användarnamn och lösenord.';

  @override
  String get loginInvalidCredentials => 'Fel användarnamn eller lösenord.';

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
  String get passwordsDoNotMatch => 'Lösenorden matchar inte.';

  @override
  String get usernameTaken => 'Användarnamnet är redan taget.';

  @override
  String get currentPasswordIncorrect => 'Nuvarande lösenord är felaktigt.';

  @override
  String get userCreated => 'Användare skapad.';

  @override
  String get userUpdated => 'Användare uppdaterad.';

  @override
  String get userDeleted => 'Användare borttagen.';

  @override
  String get passwordChanged => 'Lösenord uppdaterat.';

  @override
  String get passwordCleared => 'Password removed.';

  @override
  String get deleteUserConfirmTitle => 'Ta bort användare';

  @override
  String deleteUserConfirmMessage(String username) {
    return 'This removes $username\'s app profile. Their Firefly III data is not affected.';
  }

  @override
  String signedInAs(String username) {
    return 'Inloggad som $username';
  }

  @override
  String get usernameRequired => 'Ange ett användarnamn.';

  @override
  String get unlockWithBiometrics => 'Lås upp med biometri';

  @override
  String get unlockWithBiometricsDescription =>
      'Använd Face ID, Touch ID, fingeravtryck eller enhetens PIN på inloggningsskärmen.';

  @override
  String get biometricUnlockReason => 'Lås upp FireRaccoon';

  @override
  String get biometricEnableReason =>
      'Bekräfta för att aktivera biometrisk upplåsning';

  @override
  String get biometricUnlockFailed =>
      'Biometrisk upplåsning avbröts eller misslyckades.';

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
  String get settingsExportSubject => 'FireRaccoon settings';

  @override
  String get settingsExportText => 'FireRaccoon settings backup';

  @override
  String get recordedBalance => 'Bokfört';

  @override
  String get upcoming => 'Kommande';
}
