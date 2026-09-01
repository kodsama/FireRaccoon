// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'FireRaccoon';

  @override
  String get appTagline => 'O bandido mais brilhante para o seu orçamento.';

  @override
  String get appNameFire => 'Fire';

  @override
  String get appNameRaccoon => 'Raccoon';

  @override
  String get navDashboard => 'Painel';

  @override
  String get navDashboardShort => 'Painel';

  @override
  String get navAccounts => 'Contas';

  @override
  String get navTransactions => 'Transações';

  @override
  String get navBudgets => 'Orçamentos';

  @override
  String get navSubscriptions => 'Subscriptions & Recurring';

  @override
  String get navPiggyBanks => 'Piggy banks';

  @override
  String get navExpenses => 'Despesas';

  @override
  String get navIncome => 'Income';

  @override
  String get navTransfers => 'Transfers';

  @override
  String get navLiabilities => 'Liabilities';

  @override
  String get navProjection => 'Projeção';

  @override
  String get navPrognosis => 'Prognosis';

  @override
  String get navSettings => 'Definições';

  @override
  String get netWorth => 'Património líquido';

  @override
  String get search => 'Pesquisar...';

  @override
  String get loading => 'A carregar…';

  @override
  String get fireflyUser => 'Utilizador Firefly';

  @override
  String get fireflyConnected => 'Firefly III · ligado';

  @override
  String get fireflyDisconnected => 'Firefly III · desligado';

  @override
  String get fireflyConnectionChecking => 'Firefly III · a verificar…';

  @override
  String get settingsTitle => 'Definições';

  @override
  String appVersion(String version) {
    return 'Versão $version';
  }

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Selecionar idioma';

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
  String get defaultCurrency => 'Moeda predefinida';

  @override
  String get selectCurrency => 'Selecionar moeda';

  @override
  String get primaryCurrencyChangeWarning =>
      'O Firefly III pode recalcular valores armazenados quando a moeda predefinida muda.';

  @override
  String primaryCurrencyChanged(String code) {
    return 'Moeda predefinida definida como $code';
  }

  @override
  String failedToSetPrimaryCurrency(String error) {
    return 'Falha ao definir a moeda predefinida: $error';
  }

  @override
  String get primaryCurrencyCurrent => 'Atual';

  @override
  String get changePrimaryCurrencyTitle => 'Alterar moeda predefinida';

  @override
  String changePrimaryCurrencyMessage(String code, String warning) {
    return 'Alterar a moeda predefinida para $code? $warning';
  }

  @override
  String get changePrimaryCurrencyConfirm => 'Alterar';

  @override
  String get connectToFireflyToLoad => 'Ligue o Firefly III para carregar';

  @override
  String get managedInFirefly => 'Gerido no Firefly III';

  @override
  String get appearance => 'Aparência';

  @override
  String get raccoonMode => 'Modo Raccoon';

  @override
  String get themeStyle => 'Estilo do tema';

  @override
  String get themeStyleSubtitle =>
      'Escolha uma paleta, cor de destaque e brilho. As alterações aplicam-se de imediato.';

  @override
  String get systemDefault => 'Predefinição do sistema';

  @override
  String get themeBrightness => 'Brilho';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themePalette => 'Paleta';

  @override
  String get paletteClassic => 'Clássica';

  @override
  String get paletteSpectrum => 'Espectro';

  @override
  String get paletteRaccoon => 'Guaxinim';

  @override
  String get themeAccentColor => 'Cor de destaque';

  @override
  String get themePreview => 'Pré-visualização';

  @override
  String get done => 'Concluído';

  @override
  String get accentGreen => 'Verde';

  @override
  String get accentTeal => 'Azul-petróleo';

  @override
  String get accentBlue => 'Azul';

  @override
  String get accentOrange => 'Laranja';

  @override
  String get accentRed => 'Vermelho';

  @override
  String get accentViolet => 'Violeta';

  @override
  String get accentLime => 'Lima';

  @override
  String get accentSky => 'Céu';

  @override
  String get accentCharcoal => 'Carvão';

  @override
  String get accentSilver => 'Prata';

  @override
  String get accentTan => 'Bege';

  @override
  String get accentAmber => 'Âmbar';

  @override
  String get accentSlate => 'Ardósia';

  @override
  String get accentMidnight => 'Meia-noite';

  @override
  String get accentSmoke => 'Fumaça';

  @override
  String get accentPearl => 'Pérola';

  @override
  String get backendConnection => 'Ligação ao backend (Firefly III)';

  @override
  String get serverUrl => 'URL do servidor';

  @override
  String get notConnected => 'Não ligado';

  @override
  String get oauth2Connection => 'Ligação OAuth2';

  @override
  String get personalAccessToken => 'Token de acesso pessoal';

  @override
  String get notSet => 'Não definido';

  @override
  String get disconnect => 'Desligar';

  @override
  String get fireflyConnectionTitle => 'Ligação Firefly III';

  @override
  String get serverUrlLabel =>
      'URL do servidor (ex. https://firefly.o-meu-dominio.com)';

  @override
  String get allowHttpConnections => 'Permitir ligações HTTP';

  @override
  String get authenticationMethod => 'Método de autenticação';

  @override
  String get oauth2 => 'OAuth2';

  @override
  String get oauthClientId => 'ID do cliente OAuth';

  @override
  String get testConnection => 'Testar ligação';

  @override
  String get connectionSuccessful => 'Ligação bem-sucedida!';

  @override
  String get connectionFailed => 'Falha na ligação. Verifique o URL e o token.';

  @override
  String get loginViaBrowser => 'Iniciar sessão no navegador';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String errorGeneric(String error) {
    return 'Erro: $error';
  }

  @override
  String errorLoadingData(String error) {
    return 'Erro ao carregar dados: $error';
  }

  @override
  String get tabInsights => 'Resumo';

  @override
  String get tabAccounts => 'Contas';

  @override
  String get tabFocus => 'Foco';

  @override
  String get totalBalance => 'Saldo total';

  @override
  String incomeMonth(String month) {
    return 'Receitas · $month';
  }

  @override
  String spendingMonth(String month) {
    return 'Despesas · $month';
  }

  @override
  String savedMonth(String month) {
    return 'Poupado · $month';
  }

  @override
  String get snatchedFunds => 'Fundos apanhados';

  @override
  String get burntCash => 'Dinheiro queimado';

  @override
  String get stash => 'Esconderijo';

  @override
  String get snatched => 'Apanhado';

  @override
  String get burnt => 'Queimado';

  @override
  String get navDashboardRaccoon => 'O Esconderijo';

  @override
  String get navDashboardShortRaccoon => 'Ninho';

  @override
  String get navAccountsRaccoon => 'Esconderijos';

  @override
  String get navTransactionsRaccoon => 'Diário de golpes';

  @override
  String get navBudgetsRaccoon => 'Planos de tesouro';

  @override
  String get navSubscriptionsRaccoon => 'Recurring Raids';

  @override
  String get navPiggyBanksRaccoon => 'Mini Stashes';

  @override
  String get navExpensesRaccoon => 'Relatório de queima';

  @override
  String get navProjectionRaccoon => 'Tesouro de cristal';

  @override
  String get navPrognosisRaccoon => 'Month-end loot';

  @override
  String get navSettingsRaccoon => 'Regras do ninho';

  @override
  String get netWorthRaccoon => 'Tesouro total';

  @override
  String get searchRaccoon => 'Farejar…';

  @override
  String get accountsTitleRaccoon => 'Esconderijos';

  @override
  String get transactionsTitleRaccoon => 'Diário de golpes';

  @override
  String get budgetsTitleRaccoon => 'Planos de tesouro';

  @override
  String get expensesTitleRaccoon => 'Relatório de queima';

  @override
  String get projectionTitleRaccoon => 'Tesouro de cristal';

  @override
  String get settingsTitleRaccoon => 'Regras do ninho';

  @override
  String get tabInsightsRaccoon => 'Intel de saque';

  @override
  String get tabAccountsRaccoon => 'Esconderijos';

  @override
  String get tabFocusRaccoon => 'QG dos golpes';

  @override
  String get totalBalanceRaccoon => 'Esconderijo cheio';

  @override
  String incomeMonthRaccoon(String month) {
    return 'Apanhado · $month';
  }

  @override
  String spendingMonthRaccoon(String month) {
    return 'Queimado · $month';
  }

  @override
  String savedMonthRaccoon(String month) {
    return 'Guardado · $month';
  }

  @override
  String get cashFlowRaccoon => 'Fluxo de saque';

  @override
  String get whereMoneyGoesRaccoon => 'Para onde vai o saque';

  @override
  String get recentActivityRaccoon => 'Golpes recentes';

  @override
  String get yourAccountsRaccoon => 'Os teus esconderijos';

  @override
  String get budgetsAtGlanceRaccoon => 'Tesouro num relance';

  @override
  String get viewAllAccountsRaccoon => 'Todos os esconderijos';

  @override
  String get assetAccountsRaccoon => 'Esconderijos de tesouro';

  @override
  String get liabilityAccountsRaccoon => 'Dívidas & IOU';

  @override
  String get stocksAndFundsAccountsRaccoon => 'Esconderijos de mercado';

  @override
  String get allAccountsRaccoon => 'Todos os esconderijos';

  @override
  String get accountsRaccoon => 'Esconderijos';

  @override
  String get newTransactionRaccoon => 'Planear um golpe';

  @override
  String get editTransactionRaccoon => 'Editar golpe';

  @override
  String transactionsCountRaccoon(int count) {
    return '$count golpes';
  }

  @override
  String get oneTransactionRaccoon => '1 golpe';

  @override
  String get transactionTypeDepositRaccoon => 'Saque';

  @override
  String get transactionTypeWithdrawalRaccoon => 'Queima';

  @override
  String get transactionTypeTransferRaccoon => 'Troca de esconderijo';

  @override
  String get expenseLabelRaccoon => 'Queima';

  @override
  String get spentRaccoon => 'Queimado';

  @override
  String get newBudgetRaccoon => 'Novo plano de tesouro';

  @override
  String get projectedBalanceRaccoon => 'Tesouro futuro';

  @override
  String get piggyBankRaccoon => 'Mini-esconderijo';

  @override
  String get transfersRaccoon => 'Trocas de esconderijo';

  @override
  String get expensesFilterRaccoon => 'Queimas';

  @override
  String get noTransactionsYetRaccoon => 'Nenhum golpe ainda';

  @override
  String get lookingAheadRaccoon => 'Espiar o futuro';

  @override
  String get openProjectionRaccoon => 'Ver o futuro';

  @override
  String get editAccountRaccoon => 'Editar esconderijo';

  @override
  String get accountNameRaccoon => 'Nome do esconderijo';

  @override
  String get filterAccountRaccoon => 'Filtrar esconderijo';

  @override
  String get sourceAccountRaccoon => 'Do esconderijo';

  @override
  String get destinationAccountRaccoon => 'Para o esconderijo';

  @override
  String get totalSpentPeriodRaccoon => 'Total queimado no período';

  @override
  String get totalIncomePeriodRaccoon => 'Total apanhado no período';

  @override
  String get totalTransferredPeriodRaccoon => 'Total shuffled this period';

  @override
  String get newAccount => 'New Account';

  @override
  String get newLiability => 'New Liability';

  @override
  String get newExpense => 'New Expense';

  @override
  String get newAccountRaccoon => 'Novo esconderijo';

  @override
  String get newLiabilityRaccoon => 'Nova dívida';

  @override
  String get newExpenseRaccoon => 'Planear uma queima';

  @override
  String get income => 'Receitas';

  @override
  String get spending => 'Despesas';

  @override
  String get saved => 'Poupado';

  @override
  String get cashFlow => 'Fluxo de caixa';

  @override
  String get whereMoneyGoes => 'Para onde vai o dinheiro';

  @override
  String get noSpendingThisMonth => 'Ainda sem despesas este mês';

  @override
  String get recentActivity => 'Atividade recente';

  @override
  String get viewAll => 'Ver tudo';

  @override
  String get noTransactionsYet => 'Ainda sem transações';

  @override
  String get lookingAhead => 'Perspetiva';

  @override
  String get spendingPaceWarning =>
      'O ritmo de despesas pode exceder as receitas este mês';

  @override
  String get openProjection => 'Abrir projeção';

  @override
  String get yourAccounts => 'As suas contas';

  @override
  String get budgetsAtGlance => 'Orçamentos em resumo';

  @override
  String get viewAllAccounts => 'Ver todas as contas';

  @override
  String get thirtyDayOutlook => 'Perspetiva de 30 dias';

  @override
  String get monthEndPrognosis => 'Prognóstico de fim de mês';

  @override
  String get projectedEndOfMonth => 'Fim do mês';

  @override
  String get includeCreditCardPayments =>
      'Incluir pagamentos de cartão de crédito';

  @override
  String prognosisDeltaPositive(String amount) {
    return '+$amount previsto';
  }

  @override
  String prognosisDeltaNegative(String amount) {
    return '$amount previsto';
  }

  @override
  String get prognosisLowBalanceWarning =>
      'O saldo previsto pode ficar negativo';

  @override
  String get prognosisDebtWarning => 'A dívida prevista pode aumentar';

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
  String get todaysTimeline => 'Linha do tempo de hoje';

  @override
  String get noActivityToday => 'Sem atividade hoje';

  @override
  String get noChangeVsLastMonth => 'Sem alteração face ao mês passado';

  @override
  String get newActivityThisMonth => 'Nova atividade este mês';

  @override
  String percentVsLastMonth(String arrow, String percent) {
    return '$arrow$percent% face ao mês passado';
  }

  @override
  String projectedSavingsHeadline(String amount) {
    return '$amount de poupança projetada este mês';
  }

  @override
  String onPaceDetail(String amount) {
    return 'No ritmo para $amount poupados no fim do mês';
  }

  @override
  String spendingOutpacingDetail(String amount) {
    return 'As despesas excedem as receitas em $amount';
  }

  @override
  String get accountsTitle => 'Contas';

  @override
  String get assetAccounts => 'Contas de ativos';

  @override
  String get stocksAndFundsAccounts => 'Contas de ações e fundos';

  @override
  String get liabilityAccounts => 'Contas de passivos';

  @override
  String get noAccountsFound => 'Nenhuma conta encontrada.';

  @override
  String get allAccounts => 'Todas as contas';

  @override
  String get assetsOnly => 'Apenas ativos';

  @override
  String get liabilitiesOnly => 'Apenas passivos';

  @override
  String get accountName => 'Nome da conta';

  @override
  String get accountRoleDefault => 'Conta corrente';

  @override
  String get accountRoleShared => 'Conta partilhada';

  @override
  String get accountRoleSaving => 'Conta poupança';

  @override
  String get accountRoleCreditCard => 'Cartão de crédito';

  @override
  String get holdingAccountFundLabel => '(Fundo)';

  @override
  String get holdingAccountStockLabel => '(Ação)';

  @override
  String failedToUpdate(String error) {
    return 'Falha ao atualizar: $error';
  }

  @override
  String get name => 'Nome';

  @override
  String get transactionsTitle => 'Transações';

  @override
  String filteredBy(String account) {
    return 'Filtrado por: $account';
  }

  @override
  String get balance => 'Saldo:';

  @override
  String get balanceCheckMode => 'Verificar saldo';

  @override
  String get balanceCheckExpected => 'Saldo esperado';

  @override
  String get balanceCheckStatement => 'O seu saldo';

  @override
  String get balanceCheckStatementHint => 'Introduza o saldo do extrato';

  @override
  String get balanceCheckMatch => 'Os saldos coincidem';

  @override
  String balanceCheckDifference(String amount) {
    return 'Diferença: $amount';
  }

  @override
  String get balanceCheckEnterBalance => 'Introduza um saldo para comparar';

  @override
  String get balanceCheckInvalidAmount => 'Introduza um montante válido';

  @override
  String get balanceCheckSelectedBalance => 'Saldo das transações selecionadas';

  @override
  String get balanceCheckReconcile => 'Reconciliar selecionadas';

  @override
  String get balanceCheckReconciled => 'Transações selecionadas reconciliadas';

  @override
  String get balanceCheckNothingToReconcile =>
      'Nada a reconciliar. Selecione transações não reconciliadas para as incluir.';

  @override
  String get balanceCheckPaymentAccount => 'Conta de pagamento';

  @override
  String get balanceCheckPaybackDate => 'Data de reembolso';

  @override
  String get balanceCheckSelectPaymentAccount =>
      'Selecionar conta de pagamento';

  @override
  String get balanceCheckNoPaymentAccounts =>
      'Nenhuma conta de pagamento elegível';

  @override
  String balanceCheckPaybackSummary(
    String amount,
    String account,
    String date,
  ) {
    return 'Reembolso: $amount de $account em $date';
  }

  @override
  String get balanceCheckPaybackReconciled =>
      'Compras reconciliadas e transferência de reembolso criada';

  @override
  String get balanceCheckNoEligiblePurchases =>
      'Selecione pelo menos uma compra no cartão';

  @override
  String get tooltipBalanceCheckMode =>
      'Compare o saldo do extrato com o Firefly';

  @override
  String get tooltipBalanceCheckIncludePending =>
      'Incluir na verificação de saldo';

  @override
  String get tooltipBalanceCheckExcludeReconciled =>
      'Excluir da verificação de saldo';

  @override
  String get transactionReconciled => 'Reconciliada';

  @override
  String get partiallyReconciled => 'Parcialmente reconciliada';

  @override
  String get tooltipTransactionReconciled =>
      'Verificada com o extrato bancário';

  @override
  String get transactionReconciledUpdated => 'Reconciliação atualizada';

  @override
  String failedToUpdateReconciliation(String error) {
    return 'Falha ao atualizar reconciliação: $error';
  }

  @override
  String get reconciledFilter => 'Reconciliação';

  @override
  String get reconciledFilterAll => 'Todas as transações';

  @override
  String get reconciledFilterReconciled => 'Apenas reconciliadas';

  @override
  String get reconciledFilterUnreconciled => 'Apenas não reconciliadas';

  @override
  String get reconcile => 'Reconciliar';

  @override
  String reconcileExpectedBalance(String amount) {
    return 'Saldo esperado: $amount';
  }

  @override
  String get reconcileClickHint => 'Clique para reconciliar';

  @override
  String get reconciliationTitle => 'Reconciliar conta';

  @override
  String get reconciliationSubtitle => 'Compare o extrato com o Firefly III';

  @override
  String get reconciliationAccount => 'Conta';

  @override
  String get reconciliationStartDate => 'Data inicial';

  @override
  String get reconciliationEndDate => 'Data final';

  @override
  String get reconciliationStartBalance => 'Saldo inicial';

  @override
  String get reconciliationEndBalance => 'Saldo final';

  @override
  String get reconciliationStart => 'Iniciar reconciliação';

  @override
  String get reconciliationRestart => 'Reiniciar';

  @override
  String get reconciliationOptions => 'Opções de reconciliação';

  @override
  String get reconciliationGapZero =>
      'As transações assinaladas coincidem com o extrato.';

  @override
  String reconciliationGapPositive(String amount) {
    return 'O Firefly tem $amount a menos que o extrato.';
  }

  @override
  String reconciliationGapNegative(String amount) {
    return 'O Firefly tem $amount a mais que o extrato.';
  }

  @override
  String get reconciliationStore => 'Guardar reconciliação';

  @override
  String get reconciliationStoreTitle => 'Guardar reconciliação?';

  @override
  String reconciliationStoreBody(int count) {
    return 'Marcar $count transações como reconciliadas.';
  }

  @override
  String get reconciliationCreateCorrectionTitle =>
      'Criar transação de correção?';

  @override
  String reconciliationCreateCorrectionBody(String amount) {
    return 'Resta uma diferença de $amount. O FireRaccoon criará uma transação de reconciliação.';
  }

  @override
  String get reconciliationStored => 'Reconciliação guardada';

  @override
  String reconciliationStoreFailed(String error) {
    return 'Falha ao guardar reconciliação: $error';
  }

  @override
  String get reconciliationSelectAccount => 'Selecione uma conta de ativo';

  @override
  String get reconciliationInvalidBalances =>
      'Introduza saldos inicial e final válidos';

  @override
  String get reconciliationInvalidDateRange =>
      'A data final deve ser igual ou posterior à inicial';

  @override
  String get reconciliationSelectTransactions =>
      'Assinale pelo menos uma transação do extrato';

  @override
  String get reconciliationNoTransactions =>
      'Nenhuma transação encontrada para este período';

  @override
  String get reconciliationUnreconciled => 'Não reconciliada';

  @override
  String get reconciliationFutureTransaction => 'Após o fim do período';

  @override
  String get futureTransactions => 'Transações futuras';

  @override
  String get reconciliationOpenWizard => 'Reconciliar conta';

  @override
  String get tooltipReconciliationWizard =>
      'Comparar transações com o extrato bancário';

  @override
  String get reconciliationUseFireflyBalances => 'Usar saldos do Firefly';

  @override
  String get reconciliationLoadingBalances => 'A carregar saldos do Firefly…';

  @override
  String get reconciliationBalancesFilled =>
      'Saldos preenchidos a partir do Firefly';

  @override
  String reconciliationBalancesFailed(String error) {
    return 'Não foi possível carregar os saldos: $error';
  }

  @override
  String get notAvailable => 'N/D';

  @override
  String get groupBy => 'Agrupar por';

  @override
  String get groupByDate => 'Agrupar por data';

  @override
  String get groupByAccount => 'Agrupar por conta';

  @override
  String get groupByPayee => 'Agrupar por beneficiário';

  @override
  String get groupByType => 'Agrupar por tipo';

  @override
  String get groupByCategory => 'Agrupar por categoria';

  @override
  String get filterAccount => 'Filtrar conta';

  @override
  String get amount => 'Montante';

  @override
  String get accounts => 'Contas';

  @override
  String get description => 'Descrição';

  @override
  String get sourceAccount => 'Conta de origem';

  @override
  String get destinationAccount => 'Conta de destino';

  @override
  String get payee => 'Entidade';

  @override
  String get savingNotSupported =>
      'Guardar não é suportado em modo só de leitura.';

  @override
  String transactionDateCategory(String category, String date) {
    return '$category · $date';
  }

  @override
  String foreignAmount(String amount) {
    return '($amount)';
  }

  @override
  String get budgetsTitle => 'Orçamentos';

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
      'Abrir subscrições e faturas recorrentes.';

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
  String get newBudget => 'Novo orçamento';

  @override
  String get deleteBudget => 'Eliminar orçamento';

  @override
  String deleteBudgetMessage(String name) {
    return 'Tem a certeza de que quer eliminar \"$name\"?';
  }

  @override
  String budgetDeleted(String name) {
    return 'Orçamento \"$name\" eliminado.';
  }

  @override
  String failedToDeleteBudget(String error) {
    return 'Falha ao eliminar orçamento: $error';
  }

  @override
  String get spent => 'Gasto';

  @override
  String ofAmount(String amount) {
    return 'de $amount';
  }

  @override
  String overBudget(String amount) {
    return '$amount acima do orçamento';
  }

  @override
  String leftInBudget(String amount) {
    return '$amount restantes';
  }

  @override
  String budgetPerPeriod(String amount, String period) {
    return '$amount por $period';
  }

  @override
  String budgetLimitForPeriod(String amount, String period) {
    return '$amount para $period';
  }

  @override
  String get budgetCadenceDaily => 'dia';

  @override
  String get budgetCadenceWeekly => 'semana';

  @override
  String get budgetCadenceMonthly => 'mês';

  @override
  String get budgetCadenceQuarterly => 'trimestre';

  @override
  String get budgetCadenceHalfYear => 'semestre';

  @override
  String get budgetCadenceYearly => 'ano';

  @override
  String get viewPeriod => 'Período de visualização';

  @override
  String get budgetAmount => 'Montante do orçamento';

  @override
  String get editBudget => 'Editar orçamento';

  @override
  String get createBudget => 'Criar orçamento';

  @override
  String get createPayee => 'Criar entidade';

  @override
  String get createCategory => 'Criar categoria';

  @override
  String get budgetLimit => 'Limite do orçamento';

  @override
  String get autoBudget => 'Montante de auto-orçamento';

  @override
  String get budgetAmountMode => 'Tipo de limite';

  @override
  String get budgetAmountModeAuto => 'Período recorrente';

  @override
  String get budgetAmountModeDateRange => 'Intervalo de datas fixo';

  @override
  String get budgetAmountModeNone => 'Sem montante';

  @override
  String get budgetRepeatPeriod => 'Repete a cada';

  @override
  String get budgetAutoType => 'Comportamento do auto-orçamento';

  @override
  String get budgetAutoTypeReset => 'Repor a cada período';

  @override
  String get budgetAutoTypeRollover => 'Transferir o não usado';

  @override
  String get budgetAutoTypeAdjusted => 'Ajustar às despesas';

  @override
  String get budgetAutoTypeNone => 'Nenhum';

  @override
  String get budgetActive => 'Ativo';

  @override
  String get budgetPeriodDaily => 'Diário';

  @override
  String get budgetPeriodWeekly => 'Semanal';

  @override
  String get budgetPeriodMonthly => 'Mensal';

  @override
  String get budgetPeriodQuarterly => 'Trimestral';

  @override
  String get budgetPeriodHalfYear => 'Semestral';

  @override
  String get budgetPeriodYearly => 'Anual';

  @override
  String get tooltipBudgetAmountMode =>
      'Auto-orçamento recorrente, intervalo fixo ou sem limite';

  @override
  String get tooltipBudgetRepeatPeriod =>
      'Frequência do orçamento (ex. mensal)';

  @override
  String get tooltipBudgetAutoType =>
      'O que acontece no início de cada período';

  @override
  String get tooltipBudgetStartDate => 'Primeiro dia da limite';

  @override
  String get tooltipBudgetEndDate => 'Último dia da limite';

  @override
  String get tooltipBudgetActive =>
      'Orçamentos inativos ficam ocultos por defeito no Firefly';

  @override
  String get tooltipBudgetNotes => 'Notas opcionais do orçamento';

  @override
  String get tooltipBudgetCurrency => 'Moeda do montante do orçamento';

  @override
  String get expensesTitle => 'Despesas';

  @override
  String get clearFilters => 'Limpar filtros';

  @override
  String get overview => 'Resumo';

  @override
  String get byCategory => 'Por categoria';

  @override
  String get allCategories => 'Todas as categorias';

  @override
  String get allTypes => 'Todos os tipos';

  @override
  String get expensesFilter => 'Despesas';

  @override
  String get transfers => 'Transferências';

  @override
  String get expensePeriodWeek => 'Esta semana';

  @override
  String get expensePeriodMonth => 'Este mês';

  @override
  String get expensePeriodQuarter => 'Este trimestre';

  @override
  String get expensePeriodSemester => 'Este semestre';

  @override
  String get expensePeriodYear => 'Este ano';

  @override
  String get expensePeriodAll => 'Todo o período';

  @override
  String get dashboardPeriodThisWeek => 'Esta semana';

  @override
  String get dashboardPeriodLastWeek => 'Semana passada';

  @override
  String get dashboardPeriodThisMonth => 'Este mês';

  @override
  String get dashboardPeriodLastMonth => 'Mês passado';

  @override
  String get dashboardPeriodThisQuarter => 'Este trimestre';

  @override
  String get dashboardPeriodLastQuarter => 'Trimestre passado';

  @override
  String get dashboardPeriodThisYear => 'Este ano';

  @override
  String get dashboardPeriodLastYear => 'Ano passado';

  @override
  String get dashboardPeriodLast2Years => 'Últimos 2 anos';

  @override
  String get dashboardPeriodLast5Years => 'Últimos 5 anos';

  @override
  String get dashboardPeriodLast10Years => 'Últimos 10 anos';

  @override
  String get dashboardPeriodAll => 'Tudo';

  @override
  String get deltaComparisonPreviousWeek => 'semana anterior';

  @override
  String get deltaComparisonPreviousMonth => 'mês anterior';

  @override
  String get deltaComparisonPreviousQuarter => 'trimestre anterior';

  @override
  String get deltaComparisonPreviousYear => 'ano anterior';

  @override
  String get deltaComparisonPrevious2Years => '2 anos anteriores';

  @override
  String get deltaComparisonPrevious5Years => '5 anos anteriores';

  @override
  String get deltaComparisonPrevious10Years => '10 anos anteriores';

  @override
  String get deltaComparisonCustomPeriod => 'período anterior';

  @override
  String noChangeVsComparisonPeriod(String period) {
    return 'Sem alteração vs $period';
  }

  @override
  String newActivityVsComparisonPeriod(String period) {
    return 'Nova atividade vs $period';
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
  String get projectionTitle => 'Projeção';

  @override
  String get projectedBalance => 'Saldo projetado';

  @override
  String get visualization => 'Visualização';

  @override
  String get parameters => 'Parâmetros';

  @override
  String predictedBalances(String period) {
    return 'Saldos previstos · $period';
  }

  @override
  String get noAccountsLoaded => 'Nenhuma conta carregada';

  @override
  String get scenarioSummary => 'Resumo do cenário';

  @override
  String nowAmount(String amount) {
    return 'agora $amount';
  }

  @override
  String get worstCase => 'Pior caso';

  @override
  String get expected => 'Esperado';

  @override
  String get bestCase => 'Melhor caso';

  @override
  String get moveSliderToSeeImpact => 'Mova o cursor para ver o impacto';

  @override
  String whatIfImpact(String amount, String period) {
    return '+$amount em $period';
  }

  @override
  String get projectionPeriod3Months => '3 meses';

  @override
  String get projectionPeriod6Months => '6 meses';

  @override
  String get projectionPeriod1Year => '1 ano';

  @override
  String get projectionPeriod3Years => '3 anos';

  @override
  String get projectionTypeSavings => 'Taxa de poupança';

  @override
  String get projectionTypeCompound => 'Crescimento composto';

  @override
  String get projectionTypePortfolio => 'Carteira (volátil)';

  @override
  String get projectionTypeCashflow => 'Fluxo de caixa';

  @override
  String get projectionTypeSavingsDesc =>
      'Projeção linear com base na sua poupança líquida histórica';

  @override
  String get projectionTypeCompoundDesc =>
      'O saldo cresce com juros compostos mais contribuições';

  @override
  String get projectionTypePortfolioDesc =>
      'Retorno esperado com bandas pior/melhor conforme a volatilidade';

  @override
  String get projectionTypeCashflowDesc =>
      'Receitas menos despesas com ajustes discricionários';

  @override
  String get chartStyleFan => 'Gráfico em leque';

  @override
  String get chartStyleLines => 'Três linhas';

  @override
  String get chartStyleScenarios => 'Cartões de cenário';

  @override
  String get whatIfSpending => 'Despesas hipotéticas';

  @override
  String get annualReturn => 'Retorno anual';

  @override
  String get volatility => 'Volatilidade';

  @override
  String projectionAlertLiability(String name, String balance) {
    return 'No pior caso, $name pode atingir $balance mais cedo do que o esperado.';
  }

  @override
  String get projectionAlertBelowZero =>
      'A projeção pessimista desce abaixo de zero no período selecionado.';

  @override
  String get projectionAlertActionLiability =>
      'Considere transferir fundos de uma conta poupança.';

  @override
  String get projectionAlertActionSpending =>
      'Reveja despesas discricionárias ou aumente a poupança.';

  @override
  String get confirmTypeWord => 'Escreva ';

  @override
  String get confirmToConfirm => ' para confirmar:';

  @override
  String get confirmHint => 'Escreva a palavra acima…';

  @override
  String currencyPair(String name, String symbol) {
    return '$name ($symbol)';
  }

  @override
  String budgetSpentFraction(String spent, String total) {
    return '$spent / $total';
  }

  @override
  String get editAccount => 'Editar conta';

  @override
  String get editAction => 'Editar';

  @override
  String get filterAllShort => 'Todas';

  @override
  String get filterAssetsShort => 'Ativos';

  @override
  String get filterLiabilitiesShort => 'Passivos';

  @override
  String get showInactiveAccounts => 'Mostrar contas inativas';

  @override
  String get showInactiveAccountsShort => 'Inativas';

  @override
  String get accountInactive => 'Inativa';

  @override
  String get unknown => 'Desconhecido';

  @override
  String showingTransactionsOfTotal(int loaded, int total) {
    return 'A mostrar $loaded de $total transações';
  }

  @override
  String transactionsCount(int count) {
    return '$count transações';
  }

  @override
  String get oneTransaction => '1 transação';

  @override
  String deleteBudgetConfirmBody(String name) {
    return 'Tem a certeza de que quer eliminar o orçamento \"$name\"? Esta ação não pode ser desfeita.';
  }

  @override
  String get scrollForMore => 'Deslize para ver mais…';

  @override
  String get noTransactionsMatchFilters =>
      'Nenhuma transação corresponde aos filtros atuais.';

  @override
  String get category => 'Categoria';

  @override
  String get totalSpentPeriod => 'Total gasto neste período';

  @override
  String get totalIncomePeriod => 'Total de rendimentos neste período';

  @override
  String get totalTransferredPeriod => 'Total transferido neste período';

  @override
  String get totalPeriod => 'Total neste período';

  @override
  String get volatilityUncertainty => 'Volatilidade / incerteza';

  @override
  String get editTransaction => 'Editar transação';

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
  String get expenseLabel => 'Despesa';

  @override
  String get transactionTypeDeposit => 'Depósito';

  @override
  String get transactionTypeWithdrawal => 'Levantamento';

  @override
  String get transactionTypeTransfer => 'Transferência';

  @override
  String get dataAndLoading => 'Dados e carregamento';

  @override
  String get transactionPageSize => 'Transações por página';

  @override
  String get transactionPageSizeDescription =>
      'Quantas transações carregar em cada scroll. Aplica-se à lista de transações.';

  @override
  String transactionPageSizeValue(int count) {
    return '$count por página';
  }

  @override
  String get defaultPeriod => 'Default period';

  @override
  String get defaultPeriodDescription =>
      'Applied when opening the dashboard, expenses, income, transfers, and transactions.';

  @override
  String get customDateRange => 'Intervalo personalizado';

  @override
  String get pickDates => 'Escolher datas';

  @override
  String get budgetStatusOnTrack => 'Dentro do orçamento';

  @override
  String get budgetStatusOver => 'Acima do orçamento';

  @override
  String whatIfCutSpending(int percent) {
    return 'E se reduzisse as despesas discricionárias em $percent%?';
  }

  @override
  String get usesAveragePatterns =>
      'Usa os seus padrões médios de rendimentos e despesas das transações.';

  @override
  String get historicalNetSavingsNote =>
      'Com base na poupança líquida histórica. Ajuste a incerteza para alargar ou estreitar a faixa.';

  @override
  String get accountFilterLabel => 'Conta';

  @override
  String get noTransactionsForBudget => 'Sem transações para este orçamento.';

  @override
  String get noTransactionsForAccount => 'Sem transações para esta conta.';

  @override
  String get deleteAccount => 'Eliminar conta';

  @override
  String deleteAccountConfirmBody(String name) {
    return 'Tem a certeza de que pretende eliminar a conta \"$name\"? Esta ação não pode ser anulada.';
  }

  @override
  String accountDeleted(String name) {
    return 'Conta \"$name\" eliminada.';
  }

  @override
  String failedToDeleteAccount(String error) {
    return 'Falha ao eliminar conta: $error';
  }

  @override
  String get budgetNameHint => 'Nome do orçamento';

  @override
  String budgetAmountWithSymbol(String symbol) {
    return 'Valor do orçamento ($symbol)';
  }

  @override
  String get chartLegendActual => 'Real';

  @override
  String get chartLegendWorst => 'Pior';

  @override
  String get chartLegendBest => 'Melhor';

  @override
  String get chartLegendWorstBest => 'Pior ↔ Melhor';

  @override
  String get today => 'hoje';

  @override
  String get mcpServer => 'Servidor MCP';

  @override
  String mcpStatusFailed(String error) {
    return 'Falhou: $error';
  }

  @override
  String mcpStatusRunning(int port) {
    return 'A correr na porta $port';
  }

  @override
  String get mcpStatusStarting => 'A iniciar…';

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
  String get splitMainAmount => 'Valor total';

  @override
  String get tooltipSplitMainAmount =>
      'Total da transação. Os valores das linhas devem somar este montante antes de guardar.';

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
    return 'Abrir $section.';
  }

  @override
  String get tooltipOpenDashboard =>
      'Abrir o painel com os principais indicadores.';

  @override
  String get tooltipOpenAccounts => 'Abrir as suas contas e saldos.';

  @override
  String get tooltipOpenTransactions => 'Abrir todas as transações e filtros.';

  @override
  String get tooltipOpenBudgets => 'Abrir os orçamentos e progresso de gastos.';

  @override
  String get tooltipOpenPiggyBanks =>
      'Abrir objetivos de poupança e mealheiros.';

  @override
  String get tooltipOpenExpenses => 'Abrir análises de despesas.';

  @override
  String get tooltipOpenIncome => 'Abrir análises de receitas.';

  @override
  String get tooltipOpenTransfers =>
      'Abrir histórico e análises de transferências.';

  @override
  String get tooltipOpenLiabilities => 'Abrir visão de passivos e dívidas.';

  @override
  String get tooltipOpenProjection => 'Abrir cenários e previsões.';

  @override
  String get tooltipOpenPrognosis =>
      'Abrir o prognóstico de saldo no fim do mês.';

  @override
  String get projectionTabLongTerm => 'Long-term forecast';

  @override
  String get tooltipOpenSettings => 'Abrir definições e ligação ao Firefly.';

  @override
  String get tooltipToggleSidebar => 'Expandir ou recolher a barra lateral.';

  @override
  String get tooltipSearchTransactions => 'Pesquisar texto na página atual.';

  @override
  String get tooltipToggleViewMode => 'Alternar entre vista de lista e grelha.';

  @override
  String get refreshFromFirefly => 'Atualizar';

  @override
  String get tooltipRefreshFromFirefly => 'Recarregar dados do Firefly III';

  @override
  String get viewModeCards => 'Cartões';

  @override
  String get viewModeRows => 'Linhas';

  @override
  String get viewModeTightRows => 'Linhas compactas';

  @override
  String get columnSelection => 'Selecionar colunas';

  @override
  String get columnDate => 'Data';

  @override
  String get columnAccount => 'Conta';

  @override
  String get columnType => 'Modo';

  @override
  String get columnPayee => 'Entidade';

  @override
  String get columnDescription => 'Comentário';

  @override
  String get columnCategory => 'Categoria';

  @override
  String get columnBudget => 'Orçamento';

  @override
  String get columnAmount => 'Montante';

  @override
  String get columnReconciled => 'Reconciliado';

  @override
  String get columnBalance => 'Saldo';

  @override
  String get tooltipTransactionType => 'Escolher o tipo de transação.';

  @override
  String get tooltipFieldDescription => 'O que aconteceu nesta transação.';

  @override
  String get tooltipFieldSourceAccount => 'Conta de onde sai o dinheiro.';

  @override
  String get tooltipFieldDestinationAccount =>
      'Conta para onde vai o dinheiro.';

  @override
  String get tooltipSwapTransferAccounts => 'Trocar as duas contas.';

  @override
  String get disconnectConfirmTitle => 'Desconectar o Firefly III';

  @override
  String get connectionFailedNotFirefly =>
      'Esse endereço respondeu, mas não com a API do Firefly III. Verifique o URL do servidor: um endereço de interface, ou um atrás de uma página de início de sessão, responde a todos os caminhos com uma página web.';

  @override
  String get connectionFailedUnauthorized =>
      'O servidor respondeu e recusou o token. Verifique o token de acesso pessoal.';

  @override
  String get connectionFailedUnreachable =>
      'Não foi possível alcançar esse servidor. Verifique o endereço e se está a funcionar.';

  @override
  String get connectionFailedInsecure =>
      'Esse é um endereço http:// simples. Ative Permitir ligações HTTP se for intencional.';

  @override
  String get disconnectConfirmMessage =>
      'Isto apaga o URL do servidor e o token de acesso pessoal do porta-chaves deste dispositivo. Terá de os introduzir novamente para reconectar.';

  @override
  String get tooltipFieldDate => 'Data e hora da transação.';

  @override
  String get tooltipFieldAmount => 'Montante principal na moeda selecionada.';

  @override
  String get tooltipFieldCurrency => 'Moeda principal desta linha.';

  @override
  String get tooltipFieldForeignAmount => 'Montante opcional noutra moeda.';

  @override
  String get tooltipFieldForeignCurrency =>
      'Moeda usada no montante estrangeiro.';

  @override
  String get tooltipFieldBudget => 'Associar esta linha a um orçamento.';

  @override
  String get tooltipFieldCategory => 'Categoria para relatórios e filtros.';

  @override
  String get tooltipFieldPiggyBank => 'Associar esta linha a um mealheiro.';

  @override
  String get tooltipFieldTags =>
      'Etiquetas separadas por vírgulas para filtrar rápido.';

  @override
  String get tooltipFieldSubscription =>
      'Associar esta linha a uma subscrição.';

  @override
  String get tooltipFieldInterestDate => 'Data opcional de juro ou lançamento.';

  @override
  String get tooltipFieldAttachments =>
      'Anexos visíveis, mas envio ainda não suportado.';

  @override
  String get tooltipFieldNotes => 'Detalhes extra para referência futura.';

  @override
  String get tooltipAddSplit => 'Adicionar outra divisão a esta transação.';

  @override
  String get tooltipRemoveSplit => 'Remover esta linha de divisão.';

  @override
  String get tooltipCancelTransaction => 'Descartar alterações e fechar.';

  @override
  String get tooltipSaveTransaction => 'Guardar esta transação.';

  @override
  String get tooltipCancel => 'Descartar alterações e fechar sem guardar.';

  @override
  String get tooltipSave => 'Guardar as suas alterações.';

  @override
  String get tooltipCreate => 'Criar o novo item.';

  @override
  String get tooltipConfirmDelete => 'Eliminar permanentemente este item.';

  @override
  String get tooltipConfirmChallenge =>
      'Escreva a palavra pedida para confirmar a eliminação.';

  @override
  String get tooltipExpandDetails => 'Mostrar mais detalhes.';

  @override
  String get tooltipCollapseDetails => 'Ocultar detalhes extra.';

  @override
  String get tooltipClearDate => 'Remover a data selecionada.';

  @override
  String get tooltipAccountName => 'Nome mostrado em listas e relatórios.';

  @override
  String get tooltipAccountCurrentBalance => 'Saldo atual no Firefly até hoje.';

  @override
  String get tooltipAccountEndOfMonthBalance =>
      'Saldo previsto na data selecionada, incluindo transações agendadas, recorrências e faturas.';

  @override
  String get tooltipBalanceDatePick => 'Mostrar saldos noutra data';

  @override
  String get tooltipBalanceDateReset => 'Voltar ao fim deste mês';

  @override
  String get tooltipBalanceBeyondForecast =>
      'A previsão não vai tão longe, por isso este é o último valor projetado.';

  @override
  String get tooltipRecordedBalance =>
      'Saldo registado no livro até esta data, incluindo transações já datadas à frente.';

  @override
  String get tooltipBudgetName => 'Nome deste orçamento de despesas.';

  @override
  String get tooltipBudgetAmount =>
      'Valor limite para este período de orçamento.';

  @override
  String get tooltipSubscriptionName =>
      'Nome da fatura ou subscrição recorrente.';

  @override
  String get tooltipSubscriptionCurrency =>
      'Moeda usada para os montantes previstos.';

  @override
  String get tooltipSubscriptionAmountMin =>
      'Cobrança mínima prevista por período.';

  @override
  String get tooltipSubscriptionAmountMax =>
      'Cobrança máxima prevista por período.';

  @override
  String get tooltipSubscriptionStartDate =>
      'Data em que a subscrição começa ou foi registada.';

  @override
  String get tooltipSubscriptionRepeats =>
      'Com que frequência esta subscrição se repete.';

  @override
  String get tooltipSubscriptionSkip =>
      'Ignorar as próximas N ocorrências antes de cobrar.';

  @override
  String get tooltipSubscriptionEndDate =>
      'Data opcional em que a subscrição termina.';

  @override
  String get tooltipSubscriptionExtensionDate =>
      'Data opcional para prolongar ou pausar a cobrança.';

  @override
  String get tooltipSubscriptionGroup =>
      'Etiqueta de grupo opcional para organizar subscrições.';

  @override
  String get tooltipSubscriptionActive =>
      'Se esta subscrição está atualmente ativa.';

  @override
  String get tooltipPiggyBankName => 'Nome deste objetivo de poupança.';

  @override
  String get tooltipPiggyBankTargetAmount =>
      'Montante total que pretende poupar.';

  @override
  String get tooltipPiggyBankCurrency =>
      'Moeda do objetivo e da poupança acompanhada.';

  @override
  String get tooltipPiggyBankAccounts =>
      'Contas cujos saldos contam para este objetivo.';

  @override
  String tooltipPiggyBankAccount(String name) {
    return 'Incluir $name neste mealheiro.';
  }

  @override
  String get tooltipPiggyBankStartDate =>
      'Quando começou a acompanhar este objetivo.';

  @override
  String get tooltipPiggyBankTargetDate =>
      'Prazo opcional para atingir o objetivo.';

  @override
  String get tooltipPiggyBankGroup =>
      'Etiqueta de grupo opcional para organizar mealheiros.';

  @override
  String get tooltipThemeLight => 'Usar o esquema de cores claro.';

  @override
  String get tooltipThemeDark => 'Usar o esquema de cores escuro.';

  @override
  String get tooltipThemePaletteClassic =>
      'Paleta clássica inspirada no Firefly.';

  @override
  String get tooltipThemePaletteSpectrum =>
      'Paleta multicolorida vívida para categorias.';

  @override
  String get tooltipThemePaletteRaccoon =>
      'Paleta divertida com tema guaxinim.';

  @override
  String get tooltipThemeAccent =>
      'Cor de destaque para botões, ligações e realces.';

  @override
  String tooltipThemeAccentOption(String name) {
    return 'Usar $name como cor de destaque.';
  }

  @override
  String get tooltipThemeDone => 'Fechar e manter o tema selecionado.';

  @override
  String get repeatIntervalLabel => 'Intervalo';

  @override
  String get repeatIntervalHelp =>
      'Com que frequência se repete, p. ex. a cada 3 meses.';

  @override
  String repeatEveryNDays(int count) {
    return 'A cada $count dias';
  }

  @override
  String repeatEveryNWeeks(int count) {
    return 'A cada $count semanas';
  }

  @override
  String repeatEveryNMonths(int count) {
    return 'A cada $count meses';
  }

  @override
  String repeatEveryNYears(int count) {
    return 'A cada $count anos';
  }

  @override
  String get writeAheadDays =>
      'Escrever transações recorrentes com antecedência';

  @override
  String get writeAheadDaysDescription =>
      'Criar as próximas transações recorrentes com esta antecedência.';

  @override
  String get writeAheadOff => 'Desligado';

  @override
  String writeAheadNDays(int count) {
    return '$count dias';
  }

  @override
  String get plannedLabel => 'Planeado';

  @override
  String get navHistory => 'Histórico';

  @override
  String get navHistoryRaccoon => 'Replay de assaltos';

  @override
  String get tooltipOpenHistory => 'Abrir o histórico de anular/refazer.';

  @override
  String get tooltipUndo => 'Anular a última ação.';

  @override
  String get tooltipRedo => 'Refazer a última ação anulada.';

  @override
  String get undo => 'Anular';

  @override
  String get redo => 'Refazer';

  @override
  String get clear => 'Limpar';

  @override
  String get advanced => 'Avançado';

  @override
  String get undoHistorySize => 'Tamanho do histórico Anular/Refazer';

  @override
  String undoHistoryStoredEntries(int count, int limit) {
    return 'Entradas guardadas: $count / $limit';
  }

  @override
  String get openHistoryScreen => 'Abrir ecrã de histórico';

  @override
  String undoHistoryLimitRange(int min, int defaultValue, int max) {
    return 'Mín $min  •  Predef. $defaultValue  •  Máx $max';
  }

  @override
  String get searchHistory => 'Pesquisar no histórico';

  @override
  String get allActions => 'Todas as ações';

  @override
  String get noHistoryEntriesMatchFilters =>
      'Nenhuma entrada corresponde aos filtros.';

  @override
  String historyExportedTo(String path) {
    return 'Histórico exportado para $path';
  }

  @override
  String get historyExportedAndShared =>
      'Histórico exportado e folha de partilha aberta';

  @override
  String get exportJson => 'Exportar JSON';

  @override
  String get exportAndShare => 'Exportar e partilhar';

  @override
  String get jumpToCurrent => 'Ir para a entrada atual';

  @override
  String get historyExportSubject => 'Exportação do histórico';

  @override
  String get historyExportText => 'Exportação de histórico FireRaccoon';

  @override
  String get historySectionToday => 'Hoje';

  @override
  String get historySectionYesterday => 'Ontem';

  @override
  String get historySectionOlder => 'Mais antigo';

  @override
  String historyEntriesCount(int count, int limit) {
    return '$count / $limit';
  }

  @override
  String get undoActionTypeThemeMode => 'Modo do tema';

  @override
  String get undoActionTypeThemePalette => 'Paleta do tema';

  @override
  String get undoActionTypeThemeAccent => 'Cor de destaque';

  @override
  String get undoActionTypeThemeFunMode => 'Modo Raccoon';

  @override
  String get undoActionTypeLocale => 'Idioma';

  @override
  String get undoActionTypeViewMode => 'Modo de visualização';

  @override
  String get undoActionTypeTransactionPageSize => 'Transações por página';

  @override
  String get undoActionTypePrognosisMode => 'Modo de vista da projeção';

  @override
  String get undoActionTypePrognosisHorizon => 'Horizonte da projeção';

  @override
  String get undoActionTypePrognosisInclusion => 'Inclusões da projeção';

  @override
  String get undoActionTypePrognosisMarginPercent => 'Margem da projeção';

  @override
  String get undoActionTypeAccountCreate => 'Conta criada';

  @override
  String get undoActionTypeAccountUpdate => 'Conta atualizada';

  @override
  String get undoActionTypeAccountDelete => 'Conta eliminada';

  @override
  String get undoActionTypeBudgetCreate => 'Orçamento criado';

  @override
  String get undoActionTypeBudgetUpdate => 'Orçamento atualizado';

  @override
  String get undoActionTypeBudgetDelete => 'Orçamento eliminado';

  @override
  String get undoActionTypeTransactionCreate => 'Transação criada';

  @override
  String get undoActionTypeTransactionUpdate => 'Transação atualizada';

  @override
  String get undoActionTypeTransactionDelete => 'Transação eliminada';

  @override
  String get undoActionTypeBillCreate => 'Subscrição criada';

  @override
  String get undoActionTypeBillUpdate => 'Subscrição atualizada';

  @override
  String get undoActionTypeBillDelete => 'Subscrição eliminada';

  @override
  String get undoActionTypeRecurrenceCreate => 'Transação recorrente criada';

  @override
  String get undoActionTypeRecurrenceUpdate =>
      'Transação recorrente atualizada';

  @override
  String get undoActionTypeRecurrenceDelete => 'Transação recorrente eliminada';

  @override
  String get undoActionTypePiggyBankCreate => 'Mealheiro criado';

  @override
  String get undoActionTypePiggyBankUpdate => 'Mealheiro atualizado';

  @override
  String get undoActionTypePiggyBankDelete => 'Mealheiro eliminado';

  @override
  String get undoActionTypeLiabilityCreate => 'Passivo criado';

  @override
  String get searchHintTitle => 'Comece a digitar para pesquisar';

  @override
  String get searchHintSubtitle =>
      'Pesquise por descrição, conta, categoria, tag, nota ou valor.';

  @override
  String get noSuggestions => 'Nenhuma sugestão encontrada';

  @override
  String get invalidAmount =>
      'O montante deve ser um número válido superior a 0.';

  @override
  String get invalidForeignAmount =>
      'O montante em moeda estrangeira deve ser um número válido superior a 0.';

  @override
  String get exportFireflyData => 'Copiar dados do Firefly';

  @override
  String get exportFireflyDataDescription =>
      'Guarda um instantâneo dos seus dados do Firefly num ficheiro JSON: contas, transações com cada divisão, orçamentos, categorias, etiquetas, faturas, mealheiros, regras recorrentes e moedas.\n\nNão é uma cópia de segurança completa. O Firefly III não tem função de cópia de segurança, e uma aplicação que usa a sua API não consegue alcançar a base de dados, os anexos carregados nem a chave da instância. Restaurar um Firefly funcional exige um arquivo de volumes feito no servidor; consulte o guia de implantação.';

  @override
  String fireflyDataExportedTo(String path) {
    return 'Dados do Firefly exportados para $path';
  }

  @override
  String get missingInformation => 'Informação em falta';

  @override
  String get missingDescription => 'Por favor insira uma descrição.';

  @override
  String get missingAmount => 'Por favor insira um montante.';

  @override
  String get numberFormat => 'Number format';

  @override
  String get dateFormat => 'Date format';

  @override
  String get followsLanguage => 'Follows the language';

  @override
  String get formattingDescription =>
      'How amounts and dates are written, which is a separate choice from the language the app is in.';

  @override
  String get selectNumberFormat => 'Number format';

  @override
  String get selectDateFormat => 'Date format';

  @override
  String get recentProblems => 'Recent problems';

  @override
  String get recentProblemsDescription =>
      'What has failed since this app started, newest last. Nothing here leaves the device until you copy it.';

  @override
  String get noRecentProblems => 'Nothing has failed since this app started.';

  @override
  String get copyProblems => 'Copy';

  @override
  String get clearProblems => 'Clear';

  @override
  String problemsCopied(int count) {
    return 'Copied $count lines.';
  }

  @override
  String get missingForeignAmount => 'Please enter the foreign amount.';

  @override
  String get missingAccounts =>
      'Por favor selecione a conta de origem e destino.';

  @override
  String get appUsers => 'Usuários do aplicativo';

  @override
  String get enableAppUsers => 'Ativar usuários do aplicativo';

  @override
  String get enableAppUsersDescription =>
      'Add password-protected profiles for the people who use this app. Everyone still shares the same Firefly III data.';

  @override
  String get createAdmin => 'Criar conta de administrador';

  @override
  String get createAdminDescription =>
      'You will be the first admin. You can add more accounts afterwards.';

  @override
  String get addUser => 'Adicionar usuário';

  @override
  String get editUser => 'Editar usuário';

  @override
  String get deleteUser => 'Excluir usuário';

  @override
  String get role => 'Função';

  @override
  String get roleAdmin => 'Administrador';

  @override
  String get roleUser => 'Usuário';

  @override
  String get roleViewer => 'Visualizador';

  @override
  String get roleAdminDescription =>
      'Full access, including Firefly settings and user management.';

  @override
  String get roleUserDescription => 'Can add and edit financial data.';

  @override
  String get roleViewerDescription => 'Read-only access.';

  @override
  String get requireLogin => 'Exigir login a cada inicialização';

  @override
  String get requireLoginDescription =>
      'When off, signed-in users stay signed in between launches.';

  @override
  String get switchUser => 'Switch user';

  @override
  String get selectUserSubtitle =>
      'Choose whose profile to use. No password needed while login is not required.';

  @override
  String get assignPerson => 'Pessoa vinculada';

  @override
  String get noPersonAssigned => 'Nenhuma';

  @override
  String get myAccount => 'Minha conta';

  @override
  String get changePassword => 'Alterar senha';

  @override
  String get setPassword => 'Set password';

  @override
  String get clearPassword => 'Remove password';

  @override
  String get passwordOptionalHint =>
      'Optional. Leave blank to skip. Required only if login with password is enabled.';

  @override
  String get currentPassword => 'Senha atual';

  @override
  String get newPassword => 'Nova senha';

  @override
  String get confirmNewPassword => 'Confirmar nova senha';

  @override
  String get logout => 'Sair';

  @override
  String get login => 'Entrar';

  @override
  String get username => 'Nome de usuário';

  @override
  String get password => 'Senha';

  @override
  String get loginSubtitle => 'Entre para continuar no FireRaccoon.';

  @override
  String get loginMissingFields => 'Informe seu nome de usuário e senha.';

  @override
  String get loginInvalidCredentials => 'Nome de usuário ou senha incorretos.';

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
  String get passwordsDoNotMatch => 'As senhas não coincidem.';

  @override
  String get usernameTaken => 'Esse nome de usuário já está em uso.';

  @override
  String get currentPasswordIncorrect => 'A senha atual está incorreta.';

  @override
  String get userCreated => 'Usuário criado.';

  @override
  String get userUpdated => 'Usuário atualizado.';

  @override
  String get userDeleted => 'Usuário excluído.';

  @override
  String get passwordChanged => 'Senha atualizada.';

  @override
  String get passwordCleared => 'Password removed.';

  @override
  String get deleteUserConfirmTitle => 'Excluir usuário';

  @override
  String deleteUserConfirmMessage(String username) {
    return 'This removes $username\'s app profile. Their Firefly III data is not affected.';
  }

  @override
  String signedInAs(String username) {
    return 'Conectado como $username';
  }

  @override
  String get usernameRequired => 'Informe um nome de usuário.';

  @override
  String get unlockWithBiometrics => 'Desbloquear com biometria';

  @override
  String get unlockWithBiometricsDescription =>
      'Use Face ID, Touch ID, impressão digital ou o PIN do dispositivo no ecrã de login.';

  @override
  String get biometricUnlockReason => 'Desbloquear o FireRaccoon';

  @override
  String get biometricEnableReason =>
      'Confirme para ativar o desbloqueio biométrico';

  @override
  String get biometricUnlockFailed =>
      'O desbloqueio biométrico foi cancelado ou falhou.';

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
  String get recordedBalance => 'Registado';

  @override
  String get upcoming => 'Próximas';

  @override
  String get fireflyBackups => 'Cópias de segurança do Firefly';

  @override
  String get fireflyBackupsHint =>
      'Uma cópia de segurança leva o que a API do Firefly entrega: contas, transações, orçamentos, faturas, mealheiros e recorrências, mais a exportação do próprio Firefly, que é a única cópia das regras e dos limites de orçamento. Não chega à base de dados, aos anexos nem à chave da instância, por isso uma instância destruída continua a precisar do arquivo do volume.';

  @override
  String get backupTakeNow => 'Criar cópia de segurança';

  @override
  String backupReading(String stage) {
    return 'A ler $stage…';
  }

  @override
  String get backupNone => 'Ainda sem cópias de segurança';

  @override
  String get backupUnavailableHere =>
      'Esta versão não tem onde guardar uma cópia de segurança, por isso não é possível criar nenhuma aqui.';

  @override
  String get backupIncomplete => 'Faltam partes';

  @override
  String backupSize(int files, String kilobytes) {
    return '$files ficheiros, $kilobytes kB';
  }

  @override
  String backupCountsSummary(int transactions, int accounts) {
    return '$transactions transações, $accounts contas';
  }

  @override
  String get backupDeleteTitle => 'Eliminar esta cópia de segurança?';

  @override
  String backupDeleteBody(String id) {
    return '$id desaparece com tudo o que tem dentro, e mais nada guarda uma cópia.';
  }

  @override
  String backupTaken(String id) {
    return 'Cópia de segurança $id criada';
  }

  @override
  String backupFailed(String error) {
    return 'Não foi possível criar a cópia de segurança: $error';
  }

  @override
  String get backupSaveSnapshot => 'Guardar instantâneo';

  @override
  String backupSavedTo(String path) {
    return 'Instantâneo guardado em $path';
  }

  @override
  String get backupRestore => 'Restaurar';

  @override
  String get backupRestoreTitle =>
      'Restaurar a partir desta cópia de segurança?';

  @override
  String get backupRestorePlanning => 'A calcular o que mudaria…';

  @override
  String get backupRestoreNothing =>
      'Nada para repor: o registo já corresponde a esta cópia de segurança.';

  @override
  String backupRestoreSummary(int creates, int updates, int deletes) {
    return '$creates para repor, $updates para reescrever, $deletes para remover.';
  }

  @override
  String get backupRestoreDeletes =>
      'Remover também linhas acrescentadas desde esta cópia';

  @override
  String get backupRestoreNote =>
      'As linhas repostas voltam com identificadores novos, e é criada uma cópia de segurança antes de qualquer escrita. Regras, limites de orçamento, anexos e moedas não podem ser reescritos pela API.';

  @override
  String backupRestoreDone(int applied, int failed) {
    return '$applied linhas restauradas, $failed falharam';
  }

  @override
  String backupRestoreFailed(String error) {
    return 'Não foi possível restaurar: $error';
  }

  @override
  String get backupRestoreWrongLedger =>
      'Esta cópia de segurança foi criada por outro utilizador do Firefly, por isso não pode ser restaurada aqui.';

  @override
  String backupRestoring(int done, int total) {
    return 'A restaurar $done de $total';
  }
}
