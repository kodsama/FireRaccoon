// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'FireRacoon';

  @override
  String get appTagline => 'Le bandit le plus brillant pour votre budget.';

  @override
  String get appNameFire => 'Fire';

  @override
  String get appNameRacoon => 'Racoon';

  @override
  String get navDashboard => 'Tableau de bord';

  @override
  String get navDashboardShort => 'Aperçu';

  @override
  String get navAccounts => 'Comptes';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navBudgets => 'Budgets';

  @override
  String get navSubscriptions => 'Subscriptions & Recurring';

  @override
  String get navPiggyBanks => 'Piggy banks';

  @override
  String get navExpenses => 'Dépenses';

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
  String get navSettings => 'Paramètres';

  @override
  String get netWorth => 'Patrimoine net';

  @override
  String get search => 'Rechercher...';

  @override
  String get loading => 'Chargement…';

  @override
  String get fireflyUser => 'Utilisateur Firefly';

  @override
  String get fireflyConnected => 'Firefly III · connecté';

  @override
  String get fireflyDisconnected => 'Firefly III · déconnecté';

  @override
  String get fireflyConnectionChecking => 'Firefly III · vérification…';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get language => 'Langue';

  @override
  String get selectLanguage => 'Choisir la langue';

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
  String get defaultCurrency => 'Devise par défaut';

  @override
  String get selectCurrency => 'Choisir la devise';

  @override
  String get primaryCurrencyChangeWarning =>
      'Firefly III peut recalculer les montants enregistrés lorsque la devise par défaut change.';

  @override
  String primaryCurrencyChanged(String code) {
    return 'Devise par défaut définie sur $code';
  }

  @override
  String failedToSetPrimaryCurrency(String error) {
    return 'Impossible de définir la devise par défaut : $error';
  }

  @override
  String get primaryCurrencyCurrent => 'Actuelle';

  @override
  String get changePrimaryCurrencyTitle => 'Changer la devise par défaut';

  @override
  String changePrimaryCurrencyMessage(String code, String warning) {
    return 'Changer la devise par défaut pour $code ? $warning';
  }

  @override
  String get changePrimaryCurrencyConfirm => 'Changer';

  @override
  String get connectToFireflyToLoad => 'Connectez Firefly III pour charger';

  @override
  String get managedInFirefly => 'Géré dans Firefly III';

  @override
  String get appearance => 'Apparence';

  @override
  String get racoonMode => 'Mode Racoon';

  @override
  String get themeStyle => 'Style du thème';

  @override
  String get themeStyleSubtitle =>
      'Choisissez une palette, une couleur d\'accent et la luminosité. Les changements s\'appliquent immédiatement.';

  @override
  String get systemDefault => 'Système par défaut';

  @override
  String get themeBrightness => 'Luminosité';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themePalette => 'Palette';

  @override
  String get paletteClassic => 'Classique';

  @override
  String get paletteSpectrum => 'Spectre';

  @override
  String get paletteRaccoon => 'Raton laveur';

  @override
  String get themeAccentColor => 'Couleur d\'accent';

  @override
  String get themePreview => 'Aperçu';

  @override
  String get done => 'Terminé';

  @override
  String get accentGreen => 'Vert';

  @override
  String get accentTeal => 'Sarcelle';

  @override
  String get accentBlue => 'Bleu';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentRed => 'Rouge';

  @override
  String get accentViolet => 'Violet';

  @override
  String get accentLime => 'Citron vert';

  @override
  String get accentSky => 'Ciel';

  @override
  String get accentCharcoal => 'Charbon';

  @override
  String get accentSilver => 'Argent';

  @override
  String get accentTan => 'Beige';

  @override
  String get accentAmber => 'Ambre';

  @override
  String get accentSlate => 'Ardoise';

  @override
  String get accentMidnight => 'Minuit';

  @override
  String get accentSmoke => 'Fumée';

  @override
  String get accentPearl => 'Perle';

  @override
  String get backendConnection => 'Connexion backend (Firefly III)';

  @override
  String get serverUrl => 'URL du serveur';

  @override
  String get notConnected => 'Non connecté';

  @override
  String get oauth2Connection => 'Connexion OAuth2';

  @override
  String get personalAccessToken => 'Jeton d\'accès personnel';

  @override
  String get notSet => 'Non défini';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get fireflyConnectionTitle => 'Connexion Firefly III';

  @override
  String get serverUrlLabel =>
      'URL du serveur (ex. https://firefly.mon-domaine.com)';

  @override
  String get allowHttpConnections => 'Autoriser les connexions HTTP';

  @override
  String get authenticationMethod => 'Méthode d\'authentification';

  @override
  String get oauth2 => 'OAuth2';

  @override
  String get oauthClientId => 'ID client OAuth';

  @override
  String get testConnection => 'Tester la connexion';

  @override
  String get connectionSuccessful => 'Connexion réussie !';

  @override
  String get connectionFailed =>
      'Échec de la connexion. Vérifiez l\'URL et le jeton.';

  @override
  String get loginViaBrowser => 'Connexion via navigateur';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String errorGeneric(String error) {
    return 'Erreur : $error';
  }

  @override
  String errorLoadingData(String error) {
    return 'Erreur de chargement : $error';
  }

  @override
  String get tabInsights => 'Aperçu';

  @override
  String get tabAccounts => 'Comptes';

  @override
  String get tabFocus => 'Focus';

  @override
  String get totalBalance => 'Solde total';

  @override
  String incomeMonth(String month) {
    return 'Revenus · $month';
  }

  @override
  String spendingMonth(String month) {
    return 'Dépenses · $month';
  }

  @override
  String savedMonth(String month) {
    return 'Épargne · $month';
  }

  @override
  String get snatchedFunds => 'Fonds chapardés';

  @override
  String get burntCash => 'Cash cramé';

  @override
  String get stash => 'Planque';

  @override
  String get snatched => 'Chapardé';

  @override
  String get burnt => 'Cramé';

  @override
  String get navDashboardRacoon => 'Le Repaire';

  @override
  String get navDashboardShortRacoon => 'Repaire';

  @override
  String get navAccountsRacoon => 'Planques';

  @override
  String get navTransactionsRacoon => 'Journal de coups';

  @override
  String get navBudgetsRacoon => 'Plans de butin';

  @override
  String get navSubscriptionsRacoon => 'Recurring Raids';

  @override
  String get navPiggyBanksRacoon => 'Mini Stashes';

  @override
  String get navExpensesRacoon => 'Rapport de crame';

  @override
  String get navProjectionRacoon => 'Butin de cristal';

  @override
  String get navPrognosisRacoon => 'Month-end loot';

  @override
  String get navSettingsRacoon => 'Règles du repaire';

  @override
  String get netWorthRacoon => 'Butin total';

  @override
  String get searchRacoon => 'Renifler…';

  @override
  String get accountsTitleRacoon => 'Planques';

  @override
  String get transactionsTitleRacoon => 'Journal de coups';

  @override
  String get budgetsTitleRacoon => 'Plans de butin';

  @override
  String get expensesTitleRacoon => 'Rapport de crame';

  @override
  String get projectionTitleRacoon => 'Butin de cristal';

  @override
  String get settingsTitleRacoon => 'Règles du repaire';

  @override
  String get tabInsightsRacoon => 'Infos butin';

  @override
  String get tabAccountsRacoon => 'Planques';

  @override
  String get tabFocusRacoon => 'QG des coups';

  @override
  String get totalBalanceRacoon => 'Planque pleine';

  @override
  String incomeMonthRacoon(String month) {
    return 'Chapardé · $month';
  }

  @override
  String spendingMonthRacoon(String month) {
    return 'Cramé · $month';
  }

  @override
  String savedMonthRacoon(String month) {
    return 'Planqué · $month';
  }

  @override
  String get cashFlowRacoon => 'Flux de butin';

  @override
  String get whereMoneyGoesRacoon => 'Où va le butin';

  @override
  String get recentActivityRacoon => 'Derniers coups';

  @override
  String get yourAccountsRacoon => 'Vos planques';

  @override
  String get budgetsAtGlanceRacoon => 'Butin en un coup d\'œil';

  @override
  String get viewAllAccountsRacoon => 'Toutes les planques';

  @override
  String get assetAccountsRacoon => 'Planques au trésor';

  @override
  String get liabilityAccountsRacoon => 'Dettes & IOU';

  @override
  String get stocksAndFundsAccountsRacoon => 'Planques boursières';

  @override
  String get allAccountsRacoon => 'Toutes les planques';

  @override
  String get accountsRacoon => 'Planques';

  @override
  String get newTransactionRacoon => 'Planifier un coup';

  @override
  String get editTransactionRacoon => 'Modifier le coup';

  @override
  String transactionsCountRacoon(int count) {
    return '$count coups';
  }

  @override
  String get oneTransactionRacoon => '1 coup';

  @override
  String get transactionTypeDepositRacoon => 'Chapardage';

  @override
  String get transactionTypeWithdrawalRacoon => 'Crame';

  @override
  String get transactionTypeTransferRacoon => 'Échange de planques';

  @override
  String get expenseLabelRacoon => 'Crame';

  @override
  String get spentRacoon => 'Cramé';

  @override
  String get newBudgetRacoon => 'Nouveau plan de butin';

  @override
  String get projectedBalanceRacoon => 'Butin futur';

  @override
  String get piggyBankRacoon => 'Mini-planque';

  @override
  String get transfersRacoon => 'Échanges de planques';

  @override
  String get expensesFilterRacoon => 'Crames';

  @override
  String get noTransactionsYetRacoon => 'Aucun coup pour l\'instant';

  @override
  String get lookingAheadRacoon => 'Jeter un œil';

  @override
  String get openProjectionRacoon => 'Voir l\'avenir';

  @override
  String get editAccountRacoon => 'Modifier la planque';

  @override
  String get accountNameRacoon => 'Nom de la planque';

  @override
  String get filterAccountRacoon => 'Filtrer la planque';

  @override
  String get sourceAccountRacoon => 'Depuis la planque';

  @override
  String get destinationAccountRacoon => 'Vers la planque';

  @override
  String get totalSpentPeriodRacoon => 'Total cramé sur la période';

  @override
  String get totalIncomePeriodRacoon => 'Total chapardé sur la période';

  @override
  String get totalTransferredPeriodRacoon => 'Total shuffled this period';

  @override
  String get newAccount => 'New Account';

  @override
  String get newLiability => 'New Liability';

  @override
  String get newExpense => 'New Expense';

  @override
  String get newAccountRacoon => 'Nouvelle planque';

  @override
  String get newLiabilityRacoon => 'Nouvelle dette';

  @override
  String get newExpenseRacoon => 'Planifier une crame';

  @override
  String get income => 'Revenus';

  @override
  String get spending => 'Dépenses';

  @override
  String get saved => 'Épargne';

  @override
  String get cashFlow => 'Flux de trésorerie';

  @override
  String get whereMoneyGoes => 'Où va l\'argent';

  @override
  String get noSpendingThisMonth => 'Aucune dépense ce mois-ci';

  @override
  String get recentActivity => 'Activité récente';

  @override
  String get viewAll => 'Tout voir';

  @override
  String get noTransactionsYet => 'Aucune transaction';

  @override
  String get lookingAhead => 'Perspectives';

  @override
  String get spendingPaceWarning =>
      'Le rythme de dépenses pourrait dépasser les revenus ce mois-ci';

  @override
  String get openProjection => 'Ouvrir la projection';

  @override
  String get yourAccounts => 'Vos comptes';

  @override
  String get budgetsAtGlance => 'Budgets en un coup d\'œil';

  @override
  String get viewAllAccounts => 'Voir tous les comptes';

  @override
  String get thirtyDayOutlook => 'Perspective sur 30 jours';

  @override
  String get monthEndPrognosis => 'Prévision de fin de mois';

  @override
  String get projectedEndOfMonth => 'Fin du mois';

  @override
  String get includeCreditCardPayments =>
      'Inclure les paiements de carte de crédit';

  @override
  String prognosisDeltaPositive(String amount) {
    return '+$amount prévu';
  }

  @override
  String prognosisDeltaNegative(String amount) {
    return '$amount prévu';
  }

  @override
  String get prognosisLowBalanceWarning =>
      'Le solde prévu peut devenir négatif';

  @override
  String get prognosisDebtWarning => 'La dette prévue peut augmenter';

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
  String get todaysTimeline => 'Chronologie du jour';

  @override
  String get noActivityToday => 'Aucune activité aujourd\'hui';

  @override
  String get noChangeVsLastMonth => 'Aucun changement vs le mois dernier';

  @override
  String get newActivityThisMonth => 'Nouvelle activité ce mois-ci';

  @override
  String percentVsLastMonth(String arrow, String percent) {
    return '$arrow$percent % vs le mois dernier';
  }

  @override
  String projectedSavingsHeadline(String amount) {
    return '$amount d\'épargne projetée ce mois-ci';
  }

  @override
  String onPaceDetail(String amount) {
    return 'En bonne voie pour $amount épargnés fin de mois';
  }

  @override
  String spendingOutpacingDetail(String amount) {
    return 'Les dépenses dépassent les revenus de $amount';
  }

  @override
  String get accountsTitle => 'Comptes';

  @override
  String get assetAccounts => 'Comptes d\'actifs';

  @override
  String get stocksAndFundsAccounts => 'Comptes actions et fonds';

  @override
  String get liabilityAccounts => 'Comptes de passifs';

  @override
  String get noAccountsFound => 'Aucun compte trouvé.';

  @override
  String get allAccounts => 'Tous les comptes';

  @override
  String get assetsOnly => 'Actifs uniquement';

  @override
  String get liabilitiesOnly => 'Passifs uniquement';

  @override
  String get accountName => 'Nom du compte';

  @override
  String get accountRoleDefault => 'Compte courant';

  @override
  String get accountRoleShared => 'Compte partagé';

  @override
  String get accountRoleSaving => 'Compte d\'épargne';

  @override
  String get accountRoleCreditCard => 'Carte de crédit';

  @override
  String get holdingAccountFundLabel => '(Fonds)';

  @override
  String get holdingAccountStockLabel => '(Action)';

  @override
  String failedToUpdate(String error) {
    return 'Échec de la mise à jour : $error';
  }

  @override
  String get name => 'Nom';

  @override
  String get transactionsTitle => 'Transactions';

  @override
  String filteredBy(String account) {
    return 'Filtré par : $account';
  }

  @override
  String get balance => 'Solde :';

  @override
  String get balanceCheckMode => 'Vérifier le solde';

  @override
  String get balanceCheckExpected => 'Solde attendu';

  @override
  String get balanceCheckStatement => 'Votre solde';

  @override
  String get balanceCheckStatementHint => 'Saisissez le solde de votre relevé';

  @override
  String get balanceCheckMatch => 'Les soldes correspondent';

  @override
  String balanceCheckDifference(String amount) {
    return 'Écart : $amount';
  }

  @override
  String get balanceCheckEnterBalance => 'Saisissez un solde à comparer';

  @override
  String get balanceCheckInvalidAmount => 'Saisissez un montant valide';

  @override
  String get balanceCheckSelectedBalance =>
      'Solde des opérations sélectionnées';

  @override
  String get balanceCheckReconcile => 'Rapprocher la sélection';

  @override
  String get balanceCheckReconciled => 'Opérations sélectionnées rapprochées';

  @override
  String get balanceCheckNothingToReconcile =>
      'Rien à rapprocher. Sélectionnez des opérations non rapprochées pour les inclure.';

  @override
  String get balanceCheckPaymentAccount => 'Compte de paiement';

  @override
  String get balanceCheckPaybackDate => 'Date de remboursement';

  @override
  String get balanceCheckSelectPaymentAccount =>
      'Sélectionner le compte de paiement';

  @override
  String get balanceCheckNoPaymentAccounts =>
      'Aucun compte de paiement éligible';

  @override
  String balanceCheckPaybackSummary(
    String amount,
    String account,
    String date,
  ) {
    return 'Remboursement : $amount depuis $account le $date';
  }

  @override
  String get balanceCheckPaybackReconciled =>
      'Achats rapprochés et virement de remboursement créé';

  @override
  String get balanceCheckNoEligiblePurchases =>
      'Sélectionnez au moins un achat par carte';

  @override
  String get tooltipBalanceCheckMode =>
      'Comparez le solde de votre relevé avec Firefly';

  @override
  String get tooltipBalanceCheckIncludePending =>
      'Inclure dans la vérification du solde';

  @override
  String get tooltipBalanceCheckExcludeReconciled =>
      'Exclure de la vérification du solde';

  @override
  String get transactionReconciled => 'Rapproché';

  @override
  String get partiallyReconciled => 'Partiellement rapproché';

  @override
  String get tooltipTransactionReconciled =>
      'Vérifié par rapport à votre relevé bancaire';

  @override
  String get transactionReconciledUpdated => 'Rapprochement mis à jour';

  @override
  String failedToUpdateReconciliation(String error) {
    return 'Échec de la mise à jour du rapprochement : $error';
  }

  @override
  String get reconciledFilter => 'Rapprochement';

  @override
  String get reconciledFilterAll => 'Toutes les transactions';

  @override
  String get reconciledFilterReconciled => 'Rapprochées uniquement';

  @override
  String get reconciledFilterUnreconciled => 'Non rapprochées uniquement';

  @override
  String get reconcile => 'Rapprocher';

  @override
  String reconcileExpectedBalance(String amount) {
    return 'Solde attendu : $amount';
  }

  @override
  String get reconcileClickHint => 'Cliquer pour rapprocher';

  @override
  String get reconciliationTitle => 'Rapprocher le compte';

  @override
  String get reconciliationSubtitle =>
      'Faites correspondre votre relevé avec Firefly III';

  @override
  String get reconciliationAccount => 'Compte';

  @override
  String get reconciliationStartDate => 'Date de début';

  @override
  String get reconciliationEndDate => 'Date de fin';

  @override
  String get reconciliationStartBalance => 'Solde d\'ouverture';

  @override
  String get reconciliationEndBalance => 'Solde de clôture';

  @override
  String get reconciliationStart => 'Commencer le rapprochement';

  @override
  String get reconciliationRestart => 'Recommencer';

  @override
  String get reconciliationOptions => 'Options de rapprochement';

  @override
  String get reconciliationGapZero =>
      'Les transactions cochées correspondent au relevé.';

  @override
  String reconciliationGapPositive(String amount) {
    return 'Firefly a $amount de moins que votre relevé.';
  }

  @override
  String reconciliationGapNegative(String amount) {
    return 'Firefly a $amount de plus que votre relevé.';
  }

  @override
  String get reconciliationStore => 'Enregistrer le rapprochement';

  @override
  String get reconciliationStoreTitle => 'Enregistrer le rapprochement ?';

  @override
  String reconciliationStoreBody(int count) {
    return 'Marquer $count transactions comme rapprochées.';
  }

  @override
  String get reconciliationCreateCorrectionTitle =>
      'Créer une transaction de correction ?';

  @override
  String reconciliationCreateCorrectionBody(String amount) {
    return 'Il reste un écart de $amount. FireRacoon créera une transaction de rapprochement.';
  }

  @override
  String get reconciliationStored => 'Rapprochement enregistré';

  @override
  String reconciliationStoreFailed(String error) {
    return 'Échec de l\'enregistrement : $error';
  }

  @override
  String get reconciliationSelectAccount => 'Sélectionnez un compte d\'actif';

  @override
  String get reconciliationInvalidBalances =>
      'Saisissez des soldes d\'ouverture et de clôture valides';

  @override
  String get reconciliationInvalidDateRange =>
      'La date de fin doit être postérieure ou égale à la date de début';

  @override
  String get reconciliationSelectTransactions =>
      'Cochez au moins une transaction du relevé';

  @override
  String get reconciliationNoTransactions =>
      'Aucune transaction trouvée pour cette période';

  @override
  String get reconciliationUnreconciled => 'Non rapprochée';

  @override
  String get reconciliationFutureTransaction => 'Après la fin de période';

  @override
  String get futureTransactions => 'Transactions futures';

  @override
  String get reconciliationOpenWizard => 'Rapprocher le compte';

  @override
  String get tooltipReconciliationWizard =>
      'Faire correspondre les transactions à votre relevé bancaire';

  @override
  String get reconciliationUseFireflyBalances => 'Utiliser les soldes Firefly';

  @override
  String get reconciliationLoadingBalances =>
      'Chargement des soldes depuis Firefly…';

  @override
  String get reconciliationBalancesFilled => 'Soldes remplis depuis Firefly';

  @override
  String reconciliationBalancesFailed(String error) {
    return 'Impossible de charger les soldes : $error';
  }

  @override
  String get notAvailable => 'N/D';

  @override
  String get groupBy => 'Grouper par';

  @override
  String get groupByDate => 'Grouper par date';

  @override
  String get groupByAccount => 'Grouper par compte';

  @override
  String get groupByPayee => 'Grouper par bénéficiaire';

  @override
  String get groupByType => 'Grouper par type';

  @override
  String get groupByCategory => 'Grouper par catégorie';

  @override
  String get filterAccount => 'Filtrer par compte';

  @override
  String get amount => 'Montant';

  @override
  String get accounts => 'Comptes';

  @override
  String get description => 'Description';

  @override
  String get sourceAccount => 'Compte source';

  @override
  String get destinationAccount => 'Compte destination';

  @override
  String get payee => 'Bénéficiaire';

  @override
  String get savingNotSupported =>
      'L\'enregistrement n\'est pas pris en charge en mode lecture seule.';

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
      'Ouvrir les abonnements et factures récurrentes.';

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
  String get newBudget => 'Nouveau budget';

  @override
  String get deleteBudget => 'Supprimer le budget';

  @override
  String deleteBudgetMessage(String name) {
    return 'Voulez-vous vraiment supprimer « $name » ?';
  }

  @override
  String budgetDeleted(String name) {
    return 'Budget « $name » supprimé.';
  }

  @override
  String failedToDeleteBudget(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String get spent => 'Dépensé';

  @override
  String ofAmount(String amount) {
    return 'sur $amount';
  }

  @override
  String overBudget(String amount) {
    return '$amount au-dessus du budget';
  }

  @override
  String leftInBudget(String amount) {
    return '$amount restants';
  }

  @override
  String budgetPerPeriod(String amount, String period) {
    return '$amount par $period';
  }

  @override
  String budgetLimitForPeriod(String amount, String period) {
    return '$amount pour $period';
  }

  @override
  String get budgetCadenceDaily => 'jour';

  @override
  String get budgetCadenceWeekly => 'semaine';

  @override
  String get budgetCadenceMonthly => 'mois';

  @override
  String get budgetCadenceQuarterly => 'trimestre';

  @override
  String get budgetCadenceHalfYear => 'semestre';

  @override
  String get budgetCadenceYearly => 'an';

  @override
  String get viewPeriod => 'Période affichée';

  @override
  String get budgetAmount => 'Montant du budget';

  @override
  String get editBudget => 'Modifier le budget';

  @override
  String get createBudget => 'Créer un budget';

  @override
  String get createPayee => 'Créer un bénéficiaire';

  @override
  String get createCategory => 'Créer une catégorie';

  @override
  String get budgetLimit => 'Limite du budget';

  @override
  String get autoBudget => 'Montant auto-budget';

  @override
  String get budgetAmountMode => 'Type de limite';

  @override
  String get budgetAmountModeAuto => 'Période récurrente';

  @override
  String get budgetAmountModeDateRange => 'Plage de dates fixe';

  @override
  String get budgetAmountModeNone => 'Sans montant';

  @override
  String get budgetRepeatPeriod => 'Répétition';

  @override
  String get budgetAutoType => 'Comportement auto-budget';

  @override
  String get budgetAutoTypeReset => 'Réinitialiser chaque période';

  @override
  String get budgetAutoTypeRollover => 'Reporter le non utilisé';

  @override
  String get budgetAutoTypeAdjusted => 'Ajuster selon les dépenses';

  @override
  String get budgetAutoTypeNone => 'Aucun';

  @override
  String get budgetActive => 'Actif';

  @override
  String get budgetPeriodDaily => 'Quotidien';

  @override
  String get budgetPeriodWeekly => 'Hebdomadaire';

  @override
  String get budgetPeriodMonthly => 'Mensuel';

  @override
  String get budgetPeriodQuarterly => 'Trimestriel';

  @override
  String get budgetPeriodHalfYear => 'Semestriel';

  @override
  String get budgetPeriodYearly => 'Annuel';

  @override
  String get tooltipBudgetAmountMode =>
      'Auto-budget récurrent, plage de dates fixe ou sans limite';

  @override
  String get tooltipBudgetRepeatPeriod => 'Fréquence du budget (ex. mensuel)';

  @override
  String get tooltipBudgetAutoType => 'Comportement au début de chaque période';

  @override
  String get tooltipBudgetStartDate => 'Premier jour de la limite';

  @override
  String get tooltipBudgetEndDate => 'Dernier jour de la limite';

  @override
  String get tooltipBudgetActive =>
      'Les budgets inactifs sont masqués par défaut dans Firefly';

  @override
  String get tooltipBudgetNotes => 'Notes optionnelles du budget';

  @override
  String get tooltipBudgetCurrency => 'Devise du montant du budget';

  @override
  String get expensesTitle => 'Dépenses';

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get overview => 'Aperçu';

  @override
  String get byCategory => 'Par catégorie';

  @override
  String get allCategories => 'Toutes les catégories';

  @override
  String get allTypes => 'Tous les types';

  @override
  String get expensesFilter => 'Dépenses';

  @override
  String get transfers => 'Virements';

  @override
  String get expensePeriodWeek => 'Cette semaine';

  @override
  String get expensePeriodMonth => 'Ce mois-ci';

  @override
  String get expensePeriodQuarter => 'Ce trimestre';

  @override
  String get expensePeriodSemester => 'Ce semestre';

  @override
  String get expensePeriodYear => 'Cette année';

  @override
  String get expensePeriodAll => 'Tout';

  @override
  String get dashboardPeriodThisWeek => 'Cette semaine';

  @override
  String get dashboardPeriodLastWeek => 'Semaine dernière';

  @override
  String get dashboardPeriodThisMonth => 'Ce mois';

  @override
  String get dashboardPeriodLastMonth => 'Mois dernier';

  @override
  String get dashboardPeriodThisQuarter => 'Ce trimestre';

  @override
  String get dashboardPeriodLastQuarter => 'Trimestre dernier';

  @override
  String get dashboardPeriodThisYear => 'Cette année';

  @override
  String get dashboardPeriodLastYear => 'Année dernière';

  @override
  String get dashboardPeriodLast2Years => '2 dernières années';

  @override
  String get dashboardPeriodLast5Years => '5 dernières années';

  @override
  String get dashboardPeriodLast10Years => '10 dernières années';

  @override
  String get dashboardPeriodAll => 'Tout';

  @override
  String get deltaComparisonPreviousWeek => 'semaine précédente';

  @override
  String get deltaComparisonPreviousMonth => 'mois précédent';

  @override
  String get deltaComparisonPreviousQuarter => 'trimestre précédent';

  @override
  String get deltaComparisonPreviousYear => 'année précédente';

  @override
  String get deltaComparisonPrevious2Years => '2 années précédentes';

  @override
  String get deltaComparisonPrevious5Years => '5 années précédentes';

  @override
  String get deltaComparisonPrevious10Years => '10 années précédentes';

  @override
  String get deltaComparisonCustomPeriod => 'période précédente';

  @override
  String noChangeVsComparisonPeriod(String period) {
    return 'Aucun changement vs $period';
  }

  @override
  String newActivityVsComparisonPeriod(String period) {
    return 'Nouvelle activité vs $period';
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
  String get projectedBalance => 'Solde projeté';

  @override
  String get visualization => 'Visualisation';

  @override
  String get parameters => 'Paramètres';

  @override
  String predictedBalances(String period) {
    return 'Soldes prévus · $period';
  }

  @override
  String get noAccountsLoaded => 'Aucun compte chargé';

  @override
  String get scenarioSummary => 'Résumé du scénario';

  @override
  String nowAmount(String amount) {
    return 'maintenant $amount';
  }

  @override
  String get worstCase => 'Pire cas';

  @override
  String get expected => 'Attendu';

  @override
  String get bestCase => 'Meilleur cas';

  @override
  String get moveSliderToSeeImpact => 'Déplacez le curseur pour voir l\'impact';

  @override
  String whatIfImpact(String amount, String period) {
    return '+$amount sur $period';
  }

  @override
  String get projectionPeriod3Months => '3 mois';

  @override
  String get projectionPeriod6Months => '6 mois';

  @override
  String get projectionPeriod1Year => '1 an';

  @override
  String get projectionPeriod3Years => '3 ans';

  @override
  String get projectionTypeSavings => 'Taux d\'épargne';

  @override
  String get projectionTypeCompound => 'Croissance composée';

  @override
  String get projectionTypePortfolio => 'Portefeuille (volatile)';

  @override
  String get projectionTypeCashflow => 'Flux de trésorerie';

  @override
  String get projectionTypeSavingsDesc =>
      'Projection linéaire à partir de votre épargne nette historique';

  @override
  String get projectionTypeCompoundDesc =>
      'Le solde croît avec les intérêts composés et les contributions';

  @override
  String get projectionTypePortfolioDesc =>
      'Rendement attendu avec bandes pire/meilleur selon la volatilité';

  @override
  String get projectionTypeCashflowDesc =>
      'Revenus moins dépenses avec ajustements discrétionnaires';

  @override
  String get chartStyleFan => 'Graphique en éventail';

  @override
  String get chartStyleLines => 'Trois lignes';

  @override
  String get chartStyleScenarios => 'Cartes de scénarios';

  @override
  String get whatIfSpending => 'Dépenses hypothétiques';

  @override
  String get annualReturn => 'Rendement annuel';

  @override
  String get volatility => 'Volatilité';

  @override
  String projectionAlertLiability(String name, String balance) {
    return 'Dans le pire des cas, $name pourrait atteindre $balance plus tôt que prévu.';
  }

  @override
  String get projectionAlertBelowZero =>
      'La projection pessimiste passe sous zéro sur la période sélectionnée.';

  @override
  String get projectionAlertActionLiability =>
      'Envisagez de transférer des fonds depuis un compte épargne.';

  @override
  String get projectionAlertActionSpending =>
      'Révisez les dépenses discrétionnaires ou augmentez l\'épargne.';

  @override
  String get confirmTypeWord => 'Tapez ';

  @override
  String get confirmToConfirm => ' pour confirmer :';

  @override
  String get confirmHint => 'Tapez le mot ci-dessus…';

  @override
  String currencyPair(String name, String symbol) {
    return '$name ($symbol)';
  }

  @override
  String budgetSpentFraction(String spent, String total) {
    return '$spent / $total';
  }

  @override
  String get editAccount => 'Modifier le compte';

  @override
  String get editAction => 'Modifier';

  @override
  String get filterAllShort => 'Tous';

  @override
  String get filterAssetsShort => 'Actifs';

  @override
  String get filterLiabilitiesShort => 'Passifs';

  @override
  String get showInactiveAccounts => 'Afficher les comptes inactifs';

  @override
  String get showInactiveAccountsShort => 'Inactifs';

  @override
  String get accountInactive => 'Inactif';

  @override
  String get unknown => 'Inconnu';

  @override
  String showingTransactionsOfTotal(int loaded, int total) {
    return 'Affichage de $loaded sur $total transactions';
  }

  @override
  String transactionsCount(int count) {
    return '$count transactions';
  }

  @override
  String get oneTransaction => '1 transaction';

  @override
  String deleteBudgetConfirmBody(String name) {
    return 'Voulez-vous vraiment supprimer le budget « $name » ? Cette action est irréversible.';
  }

  @override
  String get scrollForMore => 'Faites défiler pour en voir plus…';

  @override
  String get noTransactionsMatchFilters =>
      'Aucune transaction ne correspond aux filtres actuels.';

  @override
  String get category => 'Catégorie';

  @override
  String get totalSpentPeriod => 'Total dépensé sur la période';

  @override
  String get totalIncomePeriod => 'Total des revenus sur la période';

  @override
  String get totalTransferredPeriod => 'Total transféré sur la période';

  @override
  String get totalPeriod => 'Total sur la période';

  @override
  String get volatilityUncertainty => 'Volatilité / incertitude';

  @override
  String get editTransaction => 'Modifier la transaction';

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
  String get expenseLabel => 'Dépense';

  @override
  String get transactionTypeDeposit => 'Dépôt';

  @override
  String get transactionTypeWithdrawal => 'Retrait';

  @override
  String get transactionTypeTransfer => 'Virement';

  @override
  String get dataAndLoading => 'Données et chargement';

  @override
  String get transactionPageSize => 'Transactions par page';

  @override
  String get transactionPageSizeDescription =>
      'Nombre de transactions chargées à chaque défilement. S\'applique à la liste des transactions.';

  @override
  String transactionPageSizeValue(int count) {
    return '$count par page';
  }

  @override
  String get defaultPeriod => 'Default period';

  @override
  String get defaultPeriodDescription =>
      'Applied when opening the dashboard, expenses, income, transfers, and transactions.';

  @override
  String get customDateRange => 'Plage personnalisée';

  @override
  String get pickDates => 'Choisir des dates';

  @override
  String get budgetStatusOnTrack => 'Dans les clous';

  @override
  String get budgetStatusOver => 'Budget dépassé';

  @override
  String whatIfCutSpending(int percent) {
    return 'Et si je réduisais les dépenses discrétionnaires de $percent % ?';
  }

  @override
  String get usesAveragePatterns =>
      'Utilise vos revenus et dépenses moyens issus des transactions.';

  @override
  String get historicalNetSavingsNote =>
      'Basé sur l\'épargne nette historique. Ajustez l\'incertitude pour élargir ou réduire la bande.';

  @override
  String get accountFilterLabel => 'Compte';

  @override
  String get noTransactionsForBudget => 'Aucune transaction pour ce budget.';

  @override
  String get noTransactionsForAccount => 'Aucune transaction pour ce compte.';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String deleteAccountConfirmBody(String name) {
    return 'Voulez-vous vraiment supprimer le compte « $name » ? Cette action est irréversible.';
  }

  @override
  String accountDeleted(String name) {
    return 'Compte « $name » supprimé.';
  }

  @override
  String failedToDeleteAccount(String error) {
    return 'Échec de la suppression du compte : $error';
  }

  @override
  String get budgetNameHint => 'Nom du budget';

  @override
  String budgetAmountWithSymbol(String symbol) {
    return 'Montant du budget ($symbol)';
  }

  @override
  String get chartLegendActual => 'Réel';

  @override
  String get chartLegendWorst => 'Pire';

  @override
  String get chartLegendBest => 'Meilleur';

  @override
  String get chartLegendWorstBest => 'Pire ↔ Meilleur';

  @override
  String get today => 'aujourd\'hui';

  @override
  String get mcpServer => 'Serveur MCP';

  @override
  String mcpStatusFailed(String error) {
    return 'Échec : $error';
  }

  @override
  String mcpStatusRunning(int port) {
    return 'En cours sur le port $port';
  }

  @override
  String get mcpStatusStarting => 'Démarrage…';

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
    return 'Ouvrir $section.';
  }

  @override
  String get tooltipOpenDashboard =>
      'Ouvrir le tableau de bord et les indicateurs clés.';

  @override
  String get tooltipOpenAccounts => 'Ouvrir vos comptes et soldes.';

  @override
  String get tooltipOpenTransactions =>
      'Ouvrir toutes les transactions et filtres.';

  @override
  String get tooltipOpenBudgets =>
      'Ouvrir vos budgets et la progression des dépenses.';

  @override
  String get tooltipOpenPiggyBanks =>
      'Ouvrir vos objectifs d\'épargne et tirelires.';

  @override
  String get tooltipOpenExpenses => 'Ouvrir les analyses des dépenses.';

  @override
  String get tooltipOpenIncome => 'Ouvrir les analyses des revenus.';

  @override
  String get tooltipOpenTransfers =>
      'Ouvrir l\'historique et les analyses des virements.';

  @override
  String get tooltipOpenLiabilities => 'Ouvrir la vue des dettes et passifs.';

  @override
  String get tooltipOpenProjection => 'Ouvrir les scénarios et prévisions.';

  @override
  String get tooltipOpenPrognosis =>
      'Ouvrir le pronostic de solde en fin de mois.';

  @override
  String get projectionTabLongTerm => 'Long-term forecast';

  @override
  String get tooltipOpenSettings =>
      'Ouvrir les paramètres et la connexion Firefly.';

  @override
  String get tooltipToggleSidebar => 'Déplier ou replier la barre latérale.';

  @override
  String get tooltipSearchTransactions =>
      'Rechercher du texte dans la page actuelle.';

  @override
  String get tooltipToggleViewMode => 'Basculer entre vue liste et grille.';

  @override
  String get viewModeCards => 'Cartes';

  @override
  String get viewModeRows => 'Lignes';

  @override
  String get viewModeTightRows => 'Lignes compactes';

  @override
  String get columnSelection => 'Sélectionner les colonnes';

  @override
  String get columnDate => 'Date';

  @override
  String get columnAccount => 'Compte';

  @override
  String get columnType => 'Mode';

  @override
  String get columnPayee => 'Bénéficiaire';

  @override
  String get columnDescription => 'Commentaire';

  @override
  String get columnCategory => 'Catégorie';

  @override
  String get columnBudget => 'Budget';

  @override
  String get columnAmount => 'Montant';

  @override
  String get columnReconciled => 'Rapproché';

  @override
  String get columnBalance => 'Solde';

  @override
  String get tooltipTransactionType => 'Choisir le type de transaction.';

  @override
  String get tooltipFieldDescription =>
      'Ce qui s\'est passé dans cette transaction.';

  @override
  String get tooltipFieldSourceAccount => 'Compte d\'où vient l\'argent.';

  @override
  String get tooltipFieldDestinationAccount => 'Compte où va l\'argent.';

  @override
  String get tooltipFieldDate => 'Date et heure de la transaction.';

  @override
  String get tooltipFieldAmount => 'Montant principal dans la devise choisie.';

  @override
  String get tooltipFieldCurrency => 'Devise principale de cette ligne.';

  @override
  String get tooltipFieldForeignAmount =>
      'Montant facultatif dans une autre devise.';

  @override
  String get tooltipFieldForeignCurrency =>
      'Devise utilisée pour le montant étranger.';

  @override
  String get tooltipFieldBudget => 'Associer cette ligne à un budget.';

  @override
  String get tooltipFieldCategory => 'Catégorie pour rapports et filtres.';

  @override
  String get tooltipFieldPiggyBank => 'Associer cette ligne à une tirelire.';

  @override
  String get tooltipFieldTags =>
      'Tags séparés par des virgules pour filtrer vite.';

  @override
  String get tooltipFieldSubscription =>
      'Associer cette ligne à un abonnement.';

  @override
  String get tooltipFieldInterestDate =>
      'Date d\'intérêt ou de comptabilisation facultative.';

  @override
  String get tooltipFieldAttachments =>
      'Pièces jointes visibles mais envoi non pris en charge.';

  @override
  String get tooltipFieldNotes => 'Détails supplémentaires pour plus tard.';

  @override
  String get tooltipAddSplit => 'Ajouter une autre ligne à la transaction.';

  @override
  String get tooltipRemoveSplit => 'Supprimer cette ligne de ventilation.';

  @override
  String get tooltipCancelTransaction => 'Annuler les modifications et fermer.';

  @override
  String get tooltipSaveTransaction => 'Enregistrer cette transaction.';

  @override
  String get tooltipCancel =>
      'Annuler les modifications et fermer sans enregistrer.';

  @override
  String get tooltipSave => 'Enregistrer vos modifications.';

  @override
  String get tooltipCreate => 'Créer le nouvel élément.';

  @override
  String get tooltipConfirmDelete => 'Supprimer définitivement cet élément.';

  @override
  String get tooltipConfirmChallenge =>
      'Saisissez le mot demandé pour confirmer la suppression.';

  @override
  String get tooltipExpandDetails => 'Afficher plus de détails.';

  @override
  String get tooltipCollapseDetails => 'Masquer les détails supplémentaires.';

  @override
  String get tooltipClearDate => 'Supprimer la date sélectionnée.';

  @override
  String get tooltipAccountName => 'Nom affiché dans les listes et rapports.';

  @override
  String get tooltipAccountCurrentBalance =>
      'Solde actuel dans Firefly à ce jour.';

  @override
  String get tooltipAccountEndOfMonthBalance =>
      'Solde prévu en fin de mois, incluant transactions programmées, récurrences et factures.';

  @override
  String get tooltipBudgetName => 'Nom de ce budget de dépenses.';

  @override
  String get tooltipBudgetAmount =>
      'Montant limite pour cette période de budget.';

  @override
  String get tooltipSubscriptionName =>
      'Nom de la facture ou abonnement récurrent.';

  @override
  String get tooltipSubscriptionCurrency =>
      'Devise utilisée pour les montants prévus.';

  @override
  String get tooltipSubscriptionAmountMin =>
      'Montant minimum prévu par période.';

  @override
  String get tooltipSubscriptionAmountMax =>
      'Montant maximum prévu par période.';

  @override
  String get tooltipSubscriptionStartDate =>
      'Date de début ou de première saisie de l\'abonnement.';

  @override
  String get tooltipSubscriptionRepeats =>
      'Fréquence de répétition de cet abonnement.';

  @override
  String get tooltipSubscriptionSkip =>
      'Ignorer les N prochaines occurrences avant facturation.';

  @override
  String get tooltipSubscriptionEndDate =>
      'Date facultative de fin de l\'abonnement.';

  @override
  String get tooltipSubscriptionExtensionDate =>
      'Date facultative de prolongation ou pause.';

  @override
  String get tooltipSubscriptionGroup =>
      'Libellé de groupe facultatif pour organiser les abonnements.';

  @override
  String get tooltipSubscriptionActive =>
      'Indique si cet abonnement est actuellement actif.';

  @override
  String get tooltipPiggyBankName => 'Nom de cet objectif d\'épargne.';

  @override
  String get tooltipPiggyBankTargetAmount =>
      'Montant total que vous souhaitez épargner.';

  @override
  String get tooltipPiggyBankCurrency =>
      'Devise de l\'objectif et de l\'épargne suivie.';

  @override
  String get tooltipPiggyBankAccounts =>
      'Comptes dont les soldes comptent pour cet objectif.';

  @override
  String tooltipPiggyBankAccount(String name) {
    return 'Inclure $name dans cette tirelire.';
  }

  @override
  String get tooltipPiggyBankStartDate =>
      'Date de début du suivi de cet objectif.';

  @override
  String get tooltipPiggyBankTargetDate =>
      'Échéance facultative pour atteindre l\'objectif.';

  @override
  String get tooltipPiggyBankGroup =>
      'Libellé de groupe facultatif pour organiser les tirelires.';

  @override
  String get tooltipThemeLight => 'Utiliser le thème clair.';

  @override
  String get tooltipThemeDark => 'Utiliser le thème sombre.';

  @override
  String get tooltipThemePaletteClassic =>
      'Palette classique inspirée de Firefly.';

  @override
  String get tooltipThemePaletteSpectrum =>
      'Palette multicolore vive pour les catégories.';

  @override
  String get tooltipThemePaletteRaccoon =>
      'Palette ludique sur le thème du raton laveur.';

  @override
  String get tooltipThemeAccent =>
      'Couleur d\'accent pour boutons, liens et surbrillances.';

  @override
  String tooltipThemeAccentOption(String name) {
    return 'Utiliser $name comme couleur d\'accent.';
  }

  @override
  String get tooltipThemeDone => 'Fermer et conserver le thème sélectionné.';

  @override
  String get repeatIntervalLabel => 'Intervalle';

  @override
  String get repeatIntervalHelp =>
      'Fréquence de répétition, p. ex. tous les 3 mois.';

  @override
  String repeatEveryNDays(int count) {
    return 'Tous les $count jours';
  }

  @override
  String repeatEveryNWeeks(int count) {
    return 'Toutes les $count semaines';
  }

  @override
  String repeatEveryNMonths(int count) {
    return 'Tous les $count mois';
  }

  @override
  String repeatEveryNYears(int count) {
    return 'Tous les $count ans';
  }

  @override
  String get writeAheadDays =>
      'Écrire les transactions récurrentes à l\'avance';

  @override
  String get writeAheadDaysDescription =>
      'Créer les transactions récurrentes à venir avec cette avance.';

  @override
  String get writeAheadOff => 'Désactivé';

  @override
  String writeAheadNDays(int count) {
    return '$count jours';
  }

  @override
  String get plannedLabel => 'Prévu';

  @override
  String get navHistory => 'Historique';

  @override
  String get navHistoryRacoon => 'Replay de coups';

  @override
  String get tooltipOpenHistory =>
      'Ouvrir l\'historique d\'annulation/rétablissement.';

  @override
  String get tooltipUndo => 'Annuler la dernière action.';

  @override
  String get tooltipRedo => 'Rétablir la dernière action annulée.';

  @override
  String get undo => 'Annuler';

  @override
  String get redo => 'Rétablir';

  @override
  String get clear => 'Effacer';

  @override
  String get advanced => 'Avancé';

  @override
  String get undoHistorySize => 'Taille de l\'historique Annuler/Rétablir';

  @override
  String undoHistoryStoredEntries(int count, int limit) {
    return 'Entrées enregistrées : $count / $limit';
  }

  @override
  String get openHistoryScreen => 'Ouvrir l\'écran Historique';

  @override
  String undoHistoryLimitRange(int min, int defaultValue, int max) {
    return 'Min $min  •  Défaut $defaultValue  •  Max $max';
  }

  @override
  String get searchHistory => 'Rechercher dans l\'historique';

  @override
  String get allActions => 'Toutes les actions';

  @override
  String get noHistoryEntriesMatchFilters =>
      'Aucune entrée ne correspond à vos filtres.';

  @override
  String historyExportedTo(String path) {
    return 'Historique exporté vers $path';
  }

  @override
  String get historyExportedAndShared =>
      'Historique exporté et feuille de partage ouverte';

  @override
  String get exportJson => 'Exporter JSON';

  @override
  String get exportAndShare => 'Exporter et partager';

  @override
  String get jumpToCurrent => 'Aller à l\'entrée actuelle';

  @override
  String get historyExportSubject => 'Export de l\'historique';

  @override
  String get historyExportText => 'Export historique FireRacoon';

  @override
  String get historySectionToday => 'Aujourd\'hui';

  @override
  String get historySectionYesterday => 'Hier';

  @override
  String get historySectionOlder => 'Plus ancien';

  @override
  String historyEntriesCount(int count, int limit) {
    return '$count / $limit';
  }

  @override
  String get undoActionTypeThemeMode => 'Mode du thème';

  @override
  String get undoActionTypeThemePalette => 'Palette du thème';

  @override
  String get undoActionTypeThemeAccent => 'Couleur d\'accent';

  @override
  String get undoActionTypeThemeFunMode => 'Mode Racoon';

  @override
  String get undoActionTypeLocale => 'Langue';

  @override
  String get undoActionTypeViewMode => 'Mode d\'affichage';

  @override
  String get undoActionTypeTransactionPageSize => 'Transactions par page';

  @override
  String get undoActionTypePrognosisMode => 'Mode de vue projection';

  @override
  String get undoActionTypePrognosisHorizon => 'Horizon de projection';

  @override
  String get undoActionTypePrognosisInclusion => 'Inclusions de projection';

  @override
  String get undoActionTypePrognosisMarginPercent => 'Marge de projection';

  @override
  String get undoActionTypeAccountCreate => 'Compte créé';

  @override
  String get undoActionTypeAccountUpdate => 'Compte mis à jour';

  @override
  String get undoActionTypeAccountDelete => 'Compte supprimé';

  @override
  String get undoActionTypeBudgetCreate => 'Budget créé';

  @override
  String get undoActionTypeBudgetUpdate => 'Budget mis à jour';

  @override
  String get undoActionTypeBudgetDelete => 'Budget supprimé';

  @override
  String get undoActionTypeTransactionCreate => 'Transaction créée';

  @override
  String get undoActionTypeTransactionUpdate => 'Transaction mise à jour';

  @override
  String get undoActionTypeTransactionDelete => 'Transaction supprimée';

  @override
  String get undoActionTypeBillCreate => 'Abonnement créé';

  @override
  String get undoActionTypeBillUpdate => 'Abonnement mis à jour';

  @override
  String get undoActionTypeBillDelete => 'Abonnement supprimé';

  @override
  String get undoActionTypeRecurrenceCreate => 'Transaction récurrente créée';

  @override
  String get undoActionTypeRecurrenceUpdate =>
      'Transaction récurrente mise à jour';

  @override
  String get undoActionTypeRecurrenceDelete =>
      'Transaction récurrente supprimée';

  @override
  String get undoActionTypePiggyBankCreate => 'Tirelire créée';

  @override
  String get undoActionTypePiggyBankUpdate => 'Tirelire mise à jour';

  @override
  String get undoActionTypePiggyBankDelete => 'Tirelire supprimée';

  @override
  String get undoActionTypeLiabilityCreate => 'Passif créé';

  @override
  String get searchHintTitle => 'Tapez pour rechercher';

  @override
  String get searchHintSubtitle =>
      'Recherchez par description, compte, catégorie, tag, note ou montant.';

  @override
  String get noSuggestions => 'Aucune suggestion correspondante';

  @override
  String get invalidAmount =>
      'Le montant doit être un nombre valide supérieur à 0.';

  @override
  String get invalidForeignAmount =>
      'Le montant en devise étrangère doit être un nombre valide supérieur à 0.';

  @override
  String get missingDescription => 'Veuillez saisir une description.';

  @override
  String get missingAmount => 'Veuillez saisir un montant.';

  @override
  String get missingAccounts =>
      'Veuillez sélectionner les comptes source et destination.';

  @override
  String get appUsers => 'Utilisateurs de l\'application';

  @override
  String get enableAppUsers => 'Activer les utilisateurs de l\'application';

  @override
  String get enableAppUsersDescription =>
      'Add password-protected profiles for the people who use this app. Everyone still shares the same Firefly III data.';

  @override
  String get createAdmin => 'Créer un compte administrateur';

  @override
  String get createAdminDescription =>
      'You will be the first admin. You can add more accounts afterwards.';

  @override
  String get addUser => 'Ajouter un utilisateur';

  @override
  String get editUser => 'Modifier l\'utilisateur';

  @override
  String get deleteUser => 'Supprimer l\'utilisateur';

  @override
  String get role => 'Rôle';

  @override
  String get roleAdmin => 'Administrateur';

  @override
  String get roleUser => 'Utilisateur';

  @override
  String get roleViewer => 'Lecteur';

  @override
  String get roleAdminDescription =>
      'Full access, including Firefly settings and user management.';

  @override
  String get roleUserDescription => 'Can add and edit financial data.';

  @override
  String get roleViewerDescription => 'Read-only access.';

  @override
  String get requireLogin => 'Exiger la connexion à chaque lancement';

  @override
  String get requireLoginDescription =>
      'When off, signed-in users stay signed in between launches.';

  @override
  String get switchUser => 'Changer d\'utilisateur';

  @override
  String get selectUserSubtitle =>
      'Choisissez le profil à utiliser. Aucun mot de passe tant que la connexion n\'est pas exigée.';

  @override
  String get assignPerson => 'Personne liée';

  @override
  String get noPersonAssigned => 'Aucune';

  @override
  String get myAccount => 'Mon compte';

  @override
  String get changePassword => 'Changer le mot de passe';

  @override
  String get setPassword => 'Set password';

  @override
  String get clearPassword => 'Remove password';

  @override
  String get passwordOptionalHint =>
      'Optional. Leave blank to skip. Required only if login with password is enabled.';

  @override
  String get currentPassword => 'Mot de passe actuel';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get confirmNewPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get logout => 'Se déconnecter';

  @override
  String get login => 'Se connecter';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get password => 'Mot de passe';

  @override
  String get loginSubtitle => 'Connectez-vous pour continuer vers FireRacoon.';

  @override
  String get loginMissingFields =>
      'Saisissez votre nom d\'utilisateur et votre mot de passe.';

  @override
  String get loginInvalidCredentials =>
      'Nom d\'utilisateur ou mot de passe incorrect.';

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
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas.';

  @override
  String get usernameTaken => 'Ce nom d\'utilisateur est déjà utilisé.';

  @override
  String get currentPasswordIncorrect =>
      'Le mot de passe actuel est incorrect.';

  @override
  String get userCreated => 'Utilisateur créé.';

  @override
  String get userUpdated => 'Utilisateur mis à jour.';

  @override
  String get userDeleted => 'Utilisateur supprimé.';

  @override
  String get passwordChanged => 'Mot de passe mis à jour.';

  @override
  String get passwordCleared => 'Password removed.';

  @override
  String get deleteUserConfirmTitle => 'Supprimer l\'utilisateur';

  @override
  String deleteUserConfirmMessage(String username) {
    return 'This removes $username\'s app profile. Their Firefly III data is not affected.';
  }

  @override
  String signedInAs(String username) {
    return 'Connecté en tant que $username';
  }

  @override
  String get usernameRequired => 'Veuillez saisir un nom d\'utilisateur.';

  @override
  String get unlockWithBiometrics => 'Déverrouiller avec la biométrie';

  @override
  String get unlockWithBiometricsDescription =>
      'Utilisez Face ID, Touch ID, une empreinte ou le code de l’appareil sur l’écran de connexion.';

  @override
  String get biometricUnlockReason => 'Déverrouiller FireRacoon';

  @override
  String get biometricEnableReason =>
      'Confirmez pour activer le déverrouillage biométrique';

  @override
  String get biometricUnlockFailed =>
      'Le déverrouillage biométrique a été annulé ou a échoué.';

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
  String get exportSettings => 'Export settings';

  @override
  String get exportSettingsDescription =>
      'Save people, preferences, and layout to a JSON file. Passwords, Firefly tokens, and uploaded photos are not included.';

  @override
  String get importSettings => 'Import settings';

  @override
  String get importSettingsDescription =>
      'Replace settings on this device with a previously exported file.';

  @override
  String get importSettingsConfirmTitle => 'Overwrite settings?';

  @override
  String get importSettingsConfirmMessage =>
      'This replaces people, preferences, ownership, and layout on this device. Passwords and the Firefly connection are left unchanged. Custom profile photos are cleared.';

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
}
