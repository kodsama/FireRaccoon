// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'FireRacoon';

  @override
  String get appTagline => '您预算中最聪明的伙伴。';

  @override
  String get appNameFire => 'Fire';

  @override
  String get appNameRacoon => 'Racoon';

  @override
  String get navDashboard => '仪表盘';

  @override
  String get navDashboardShort => '概览';

  @override
  String get navAccounts => '账户';

  @override
  String get navTransactions => '交易';

  @override
  String get navBudgets => '预算';

  @override
  String get navSubscriptions => '订阅与定期';

  @override
  String get navPiggyBanks => '存钱罐';

  @override
  String get navExpenses => '支出';

  @override
  String get navIncome => '收入';

  @override
  String get navTransfers => '转账';

  @override
  String get navLiabilities => '负债';

  @override
  String get navProjection => '预测';

  @override
  String get navPrognosis => '预后';

  @override
  String get navSettings => '设置';

  @override
  String get netWorth => '净资产';

  @override
  String get search => '搜索...';

  @override
  String get loading => '加载中…';

  @override
  String get fireflyUser => 'Firefly 用户';

  @override
  String get fireflyConnected => 'Firefly III · 已连接';

  @override
  String get fireflyDisconnected => 'Firefly III · 未连接';

  @override
  String get fireflyConnectionChecking => 'Firefly III · 检查中…';

  @override
  String get settingsTitle => '设置';

  @override
  String appVersion(String version) {
    return '版本 $version';
  }

  @override
  String get language => '语言';

  @override
  String get selectLanguage => '选择语言';

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
  String get defaultCurrency => '默认货币';

  @override
  String get selectCurrency => '选择货币';

  @override
  String get primaryCurrencyChangeWarning =>
      '更改默认货币时，Firefly III 可能会重新计算已存储的金额。';

  @override
  String primaryCurrencyChanged(String code) {
    return '默认货币已设为 $code';
  }

  @override
  String failedToSetPrimaryCurrency(String error) {
    return '无法设置默认货币：$error';
  }

  @override
  String get primaryCurrencyCurrent => '当前';

  @override
  String get changePrimaryCurrencyTitle => '更改默认货币';

  @override
  String changePrimaryCurrencyMessage(String code, String warning) {
    return '将默认货币更改为 $code？$warning';
  }

  @override
  String get changePrimaryCurrencyConfirm => '更改';

  @override
  String get connectToFireflyToLoad => '连接 Firefly III 以加载';

  @override
  String get managedInFirefly => '在 Firefly III 中管理';

  @override
  String get appearance => '外观';

  @override
  String get racoonMode => '浣熊模式';

  @override
  String get themeStyle => '主题样式';

  @override
  String get themeStyleSubtitle => '选择调色板、强调色和亮度。更改立即生效。';

  @override
  String get systemDefault => '系统默认';

  @override
  String get themeBrightness => '亮度';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themePalette => '调色板';

  @override
  String get paletteClassic => '经典';

  @override
  String get paletteSpectrum => '光谱';

  @override
  String get paletteRaccoon => '浣熊';

  @override
  String get themeAccentColor => '强调色';

  @override
  String get themePreview => '预览';

  @override
  String get done => '完成';

  @override
  String get accentGreen => '绿色';

  @override
  String get accentTeal => '青色';

  @override
  String get accentBlue => '蓝色';

  @override
  String get accentOrange => '橙色';

  @override
  String get accentRed => '红色';

  @override
  String get accentViolet => '紫色';

  @override
  String get accentLime => '青柠';

  @override
  String get accentSky => '天蓝';

  @override
  String get accentCharcoal => '炭灰';

  @override
  String get accentSilver => '银色';

  @override
  String get accentTan => '棕褐';

  @override
  String get accentAmber => '琥珀';

  @override
  String get accentSlate => '石板';

  @override
  String get accentMidnight => '午夜';

  @override
  String get accentSmoke => '烟灰';

  @override
  String get accentPearl => '珍珠';

  @override
  String get backendConnection => '后端连接（Firefly III）';

  @override
  String get serverUrl => '服务器 URL';

  @override
  String get notConnected => '未连接';

  @override
  String get oauth2Connection => 'OAuth2 连接';

  @override
  String get personalAccessToken => '个人访问令牌';

  @override
  String get notSet => '未设置';

  @override
  String get disconnect => '断开连接';

  @override
  String get fireflyConnectionTitle => 'Firefly III 连接';

  @override
  String get serverUrlLabel => '服务器 URL（例如 https://firefly.my-domain.com）';

  @override
  String get allowHttpConnections => '允许 HTTP 连接';

  @override
  String get authenticationMethod => '认证方式';

  @override
  String get oauth2 => 'OAuth2';

  @override
  String get oauthClientId => 'OAuth 客户端 ID';

  @override
  String get testConnection => '测试连接';

  @override
  String get connectionSuccessful => '连接成功！';

  @override
  String get connectionFailed => '连接失败。请检查 URL 和令牌。';

  @override
  String get loginViaBrowser => '通过浏览器登录';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String errorGeneric(String error) {
    return '错误：$error';
  }

  @override
  String errorLoadingData(String error) {
    return '加载数据出错：$error';
  }

  @override
  String get tabInsights => '洞察';

  @override
  String get tabAccounts => '账户';

  @override
  String get tabFocus => '焦点';

  @override
  String get totalBalance => '总余额';

  @override
  String incomeMonth(String month) {
    return '收入 · $month';
  }

  @override
  String spendingMonth(String month) {
    return '支出 · $month';
  }

  @override
  String savedMonth(String month) {
    return '储蓄 · $month';
  }

  @override
  String get snatchedFunds => '截获资金';

  @override
  String get burntCash => '燃烧现金';

  @override
  String get stash => '藏匿';

  @override
  String get snatched => '截获';

  @override
  String get burnt => '燃烧';

  @override
  String get navDashboardRacoon => '浣熊窝';

  @override
  String get navDashboardShortRacoon => '窝';

  @override
  String get navAccountsRacoon => '藏匿处';

  @override
  String get navTransactionsRacoon => '打劫记录';

  @override
  String get navBudgetsRacoon => '囤积计划';

  @override
  String get navSubscriptionsRacoon => '定期突袭';

  @override
  String get navPiggyBanksRacoon => '迷你藏匿处';

  @override
  String get navExpensesRacoon => '燃烧报告';

  @override
  String get navProjectionRacoon => '水晶宝藏';

  @override
  String get navPrognosisRacoon => '月末战利品';

  @override
  String get navSettingsRacoon => '窝规';

  @override
  String get netWorthRacoon => '总宝藏';

  @override
  String get searchRacoon => '嗅一嗅…';

  @override
  String get accountsTitleRacoon => '藏匿处';

  @override
  String get transactionsTitleRacoon => '打劫记录';

  @override
  String get budgetsTitleRacoon => '囤积计划';

  @override
  String get expensesTitleRacoon => '燃烧报告';

  @override
  String get projectionTitleRacoon => '水晶宝藏';

  @override
  String get settingsTitleRacoon => '窝规';

  @override
  String get tabInsightsRacoon => '赃物情报';

  @override
  String get tabAccountsRacoon => '藏匿处';

  @override
  String get tabFocusRacoon => '打劫总部';

  @override
  String get totalBalanceRacoon => '满藏宝库';

  @override
  String incomeMonthRacoon(String month) {
    return '截获 · $month';
  }

  @override
  String spendingMonthRacoon(String month) {
    return '燃烧 · $month';
  }

  @override
  String savedMonthRacoon(String month) {
    return '藏匿 · $month';
  }

  @override
  String get cashFlowRacoon => '赃物流';

  @override
  String get whereMoneyGoesRacoon => '赃物去向';

  @override
  String get recentActivityRacoon => '近期打劫';

  @override
  String get yourAccountsRacoon => '你的藏匿处';

  @override
  String get budgetsAtGlanceRacoon => '囤积一览';

  @override
  String get viewAllAccountsRacoon => '全部藏匿处';

  @override
  String get assetAccountsRacoon => '宝藏藏匿处';

  @override
  String get liabilityAccountsRacoon => '欠债 & IOU';

  @override
  String get stocksAndFundsAccountsRacoon => '市场藏匿处';

  @override
  String get allAccountsRacoon => '全部藏匿处';

  @override
  String get accountsRacoon => '藏匿处';

  @override
  String get newTransactionRacoon => '策划打劫';

  @override
  String get editTransactionRacoon => '编辑打劫';

  @override
  String transactionsCountRacoon(int count) {
    return '$count 次打劫';
  }

  @override
  String get oneTransactionRacoon => '1 次打劫';

  @override
  String get transactionTypeDepositRacoon => '截获';

  @override
  String get transactionTypeWithdrawalRacoon => '燃烧';

  @override
  String get transactionTypeTransferRacoon => '藏匿转移';

  @override
  String get expenseLabelRacoon => '燃烧';

  @override
  String get spentRacoon => '已燃烧';

  @override
  String get newBudgetRacoon => '新囤积计划';

  @override
  String get projectedBalanceRacoon => '未来宝藏';

  @override
  String get piggyBankRacoon => '迷你藏匿处';

  @override
  String get transfersRacoon => '藏匿转移';

  @override
  String get expensesFilterRacoon => '燃烧';

  @override
  String get noTransactionsYetRacoon => '还没有打劫';

  @override
  String get lookingAheadRacoon => '窥探未来';

  @override
  String get openProjectionRacoon => '展望未来';

  @override
  String get editAccountRacoon => '编辑藏匿处';

  @override
  String get accountNameRacoon => '藏匿处名称';

  @override
  String get filterAccountRacoon => '筛选藏匿处';

  @override
  String get sourceAccountRacoon => '来源藏匿处';

  @override
  String get destinationAccountRacoon => '目标藏匿处';

  @override
  String get totalSpentPeriodRacoon => '本期总燃烧';

  @override
  String get totalIncomePeriodRacoon => '本期总截获';

  @override
  String get totalTransferredPeriodRacoon => '本期总转移';

  @override
  String get newAccount => '新建账户';

  @override
  String get newLiability => '新建负债';

  @override
  String get newExpense => '新建支出';

  @override
  String get newAccountRacoon => '新藏匿处';

  @override
  String get newLiabilityRacoon => '新欠债';

  @override
  String get newExpenseRacoon => '策划燃烧';

  @override
  String get income => '收入';

  @override
  String get spending => '支出';

  @override
  String get saved => '储蓄';

  @override
  String get cashFlow => '现金流';

  @override
  String get whereMoneyGoes => '资金流向';

  @override
  String get noSpendingThisMonth => '本月尚无支出';

  @override
  String get recentActivity => '最近活动';

  @override
  String get viewAll => '查看全部';

  @override
  String get noTransactionsYet => '暂无交易';

  @override
  String get lookingAhead => '展望未来';

  @override
  String get spendingPaceWarning => '本月支出速度可能超过收入';

  @override
  String get openProjection => '打开预测';

  @override
  String get yourAccounts => '您的账户';

  @override
  String get budgetsAtGlance => '预算一览';

  @override
  String get viewAllAccounts => '查看所有账户';

  @override
  String get thirtyDayOutlook => '30 天展望';

  @override
  String get monthEndPrognosis => '月末预测';

  @override
  String get projectedEndOfMonth => '月末';

  @override
  String get includeCreditCardPayments => '包含信用卡还款';

  @override
  String prognosisDeltaPositive(String amount) {
    return '预计 +$amount';
  }

  @override
  String prognosisDeltaNegative(String amount) {
    return '预计 $amount';
  }

  @override
  String get prognosisLowBalanceWarning => '预计余额可能为负';

  @override
  String get prognosisDebtWarning => '预计负债可能增加';

  @override
  String get openPrognosis => '打开预后';

  @override
  String get prognosisMarginLabel => '安全边际';

  @override
  String prognosisMarginDetail(String percent) {
    return '在预测余额中保留的缓冲金额。';
  }

  @override
  String get prognosisIncludeScheduled => '包含计划交易';

  @override
  String get prognosisIncludeRecurring => '包含定期交易';

  @override
  String get prognosisIncludeBills => '包含账单';

  @override
  String get prognosisIncludeIncome => '包含收入';

  @override
  String get prognosisIncludeExpenses => '包含支出';

  @override
  String get prognosisIncludeTransfers => '包含转账';

  @override
  String get prognosisIncludeCreditCards => '包含信用卡';

  @override
  String get prognosisEndOfNextMonth => '下月末';

  @override
  String get prognosisMinBalance => '最低余额';

  @override
  String get prognosisMaxBalance => '最高余额';

  @override
  String get prognosisExpectedBalance => '预期余额';

  @override
  String get prognosisSelectAccount => '选择账户';

  @override
  String get prognosisBandLegend => '余额区间';

  @override
  String get prognosisModeExpected => '预期';

  @override
  String get prognosisModeProjected => '预测';

  @override
  String get prognosisModeExpectedHint => '基于已记录交易和定期规则。';

  @override
  String get prognosisModeProjectedHint => '包含计划与预测的未来现金流。';

  @override
  String get prognosisHorizonLabel => '时间范围';

  @override
  String get prognosisHorizonEndOfMonth => '本月末';

  @override
  String get prognosisHorizonEndOfNextMonth => '下月末';

  @override
  String get prognosisHorizonTwoMonths => '两个月';

  @override
  String get prognosisHorizonThreeMonths => '三个月';

  @override
  String get prognosisHorizonSixMonths => '六个月';

  @override
  String get prognosisHorizonOneYear => '一年';

  @override
  String get prognosisHorizonThreeYears => '三年';

  @override
  String get prognosisHorizonFiveYears => '五年';

  @override
  String get prognosisHorizonTenYears => '十年';

  @override
  String get prognosisMilestoneThreeMonths => '三个月里程碑';

  @override
  String get prognosisMilestoneSixMonths => '六个月里程碑';

  @override
  String get prognosisMilestoneOneYear => '一年里程碑';

  @override
  String get prognosisIncludeSources => '包含来源账户';

  @override
  String get prognosisIncludeLiabilities => '包含负债';

  @override
  String prognosisNegativeOn(String date) {
    return '负余额日期';
  }

  @override
  String get prognosisCurrentBalance => '当前余额';

  @override
  String get prognosisPredictedBalances => '预测余额';

  @override
  String get todaysTimeline => '今日时间线';

  @override
  String get noActivityToday => '今日无活动';

  @override
  String get noChangeVsLastMonth => '与上月相比无变化';

  @override
  String get newActivityThisMonth => '本月新活动';

  @override
  String percentVsLastMonth(String arrow, String percent) {
    return '较上月 $arrow$percent%';
  }

  @override
  String projectedSavingsHeadline(String amount) {
    return '本月预计储蓄 $amount';
  }

  @override
  String onPaceDetail(String amount) {
    return '按当前速度，月底预计储蓄 $amount';
  }

  @override
  String spendingOutpacingDetail(String amount) {
    return '支出超出收入 $amount';
  }

  @override
  String get accountsTitle => '账户';

  @override
  String get assetAccounts => '资产账户';

  @override
  String get stocksAndFundsAccounts => '股票和基金账户';

  @override
  String get liabilityAccounts => '负债账户';

  @override
  String get noAccountsFound => '未找到账户。';

  @override
  String get allAccounts => '所有账户';

  @override
  String get assetsOnly => '仅资产';

  @override
  String get liabilitiesOnly => '仅负债';

  @override
  String get accountName => '账户名称';

  @override
  String get accountRoleDefault => '支票账户';

  @override
  String get accountRoleShared => '共享账户';

  @override
  String get accountRoleSaving => '储蓄账户';

  @override
  String get accountRoleCreditCard => '信用卡';

  @override
  String get holdingAccountFundLabel => '(基金)';

  @override
  String get holdingAccountStockLabel => '(股票)';

  @override
  String failedToUpdate(String error) {
    return '更新失败：$error';
  }

  @override
  String get name => '名称';

  @override
  String get transactionsTitle => '交易';

  @override
  String filteredBy(String account) {
    return '筛选条件：$account';
  }

  @override
  String get balance => '余额：';

  @override
  String get balanceCheckMode => '核对余额';

  @override
  String get balanceCheckExpected => '预期余额';

  @override
  String get balanceCheckStatement => '您的余额';

  @override
  String get balanceCheckStatementHint => '输入账单上的余额';

  @override
  String get balanceCheckMatch => '余额一致';

  @override
  String balanceCheckDifference(String amount) {
    return '差额：$amount';
  }

  @override
  String get balanceCheckEnterBalance => '输入余额以进行比较';

  @override
  String get balanceCheckInvalidAmount => '请输入有效金额';

  @override
  String get balanceCheckSelectedBalance => '所选交易余额';

  @override
  String get balanceCheckReconcile => '对账所选';

  @override
  String get balanceCheckReconciled => '所选交易已对账';

  @override
  String get balanceCheckNothingToReconcile => '没有需要对账的交易。请选择未对账的交易以将其包含在内。';

  @override
  String get balanceCheckPaymentAccount => '付款账户';

  @override
  String get balanceCheckPaybackDate => '还款日期';

  @override
  String get balanceCheckSelectPaymentAccount => '选择付款账户';

  @override
  String get balanceCheckNoPaymentAccounts => '没有可用的付款账户';

  @override
  String balanceCheckPaybackSummary(
    String amount,
    String account,
    String date,
  ) {
    return '还款：$amount，从 $account，日期 $date';
  }

  @override
  String get balanceCheckPaybackReconciled => '已对账消费并创建还款转账';

  @override
  String get balanceCheckNoEligiblePurchases => '请至少选择一笔信用卡消费';

  @override
  String get tooltipBalanceCheckMode => '将账单余额与 Firefly 进行比较';

  @override
  String get tooltipBalanceCheckIncludePending => '包含在余额核对中';

  @override
  String get tooltipBalanceCheckExcludeReconciled => '从余额核对中排除';

  @override
  String get transactionReconciled => '已对账';

  @override
  String get partiallyReconciled => '部分对账';

  @override
  String get tooltipTransactionReconciled => '已与银行账单核对';

  @override
  String get transactionReconciledUpdated => '对账状态已更新';

  @override
  String failedToUpdateReconciliation(String error) {
    return '更新对账状态失败：$error';
  }

  @override
  String get reconciledFilter => '对账';

  @override
  String get reconciledFilterAll => '全部交易';

  @override
  String get reconciledFilterReconciled => '仅已对账';

  @override
  String get reconciledFilterUnreconciled => '仅未对账';

  @override
  String get reconcile => '对账';

  @override
  String reconcileExpectedBalance(String amount) {
    return '预期余额：$amount';
  }

  @override
  String get reconcileClickHint => '点击对账';

  @override
  String get reconciliationTitle => '对账';

  @override
  String get reconciliationSubtitle => '将账单与 Firefly III 核对';

  @override
  String get reconciliationAccount => '账户';

  @override
  String get reconciliationStartDate => '开始日期';

  @override
  String get reconciliationEndDate => '结束日期';

  @override
  String get reconciliationStartBalance => '期初余额';

  @override
  String get reconciliationEndBalance => '期末余额';

  @override
  String get reconciliationStart => '开始对账';

  @override
  String get reconciliationRestart => '重新开始';

  @override
  String get reconciliationOptions => '对账选项';

  @override
  String get reconciliationGapZero => '已勾选交易与账单一致。';

  @override
  String reconciliationGapPositive(String amount) {
    return 'Firefly 比账单少 $amount。';
  }

  @override
  String reconciliationGapNegative(String amount) {
    return 'Firefly 比账单多 $amount。';
  }

  @override
  String get reconciliationStore => '保存对账';

  @override
  String get reconciliationStoreTitle => '保存对账？';

  @override
  String reconciliationStoreBody(int count) {
    return '将 $count 笔交易标记为已对账。';
  }

  @override
  String get reconciliationCreateCorrectionTitle => '创建调整交易？';

  @override
  String reconciliationCreateCorrectionBody(String amount) {
    return '仍有 $amount 差额。FireRacoon 将创建一笔对账调整交易。';
  }

  @override
  String get reconciliationStored => '对账已保存';

  @override
  String reconciliationStoreFailed(String error) {
    return '保存对账失败：$error';
  }

  @override
  String get reconciliationSelectAccount => '请选择资产账户';

  @override
  String get reconciliationInvalidBalances => '请输入有效的期初和期末余额';

  @override
  String get reconciliationInvalidDateRange => '结束日期必须不早于开始日期';

  @override
  String get reconciliationSelectTransactions => '请至少勾选账单上的一笔交易';

  @override
  String get reconciliationNoTransactions => '该期间没有交易';

  @override
  String get reconciliationUnreconciled => '未对账';

  @override
  String get reconciliationFutureTransaction => '期间结束之后';

  @override
  String get futureTransactions => '未来交易';

  @override
  String get reconciliationOpenWizard => '对账';

  @override
  String get tooltipReconciliationWizard => '将交易与银行账单核对';

  @override
  String get reconciliationUseFireflyBalances => '使用 Firefly 余额';

  @override
  String get reconciliationLoadingBalances => '正在从 Firefly 加载余额…';

  @override
  String get reconciliationBalancesFilled => '已从 Firefly 填入余额';

  @override
  String reconciliationBalancesFailed(String error) {
    return '无法加载余额：$error';
  }

  @override
  String get notAvailable => '不可用';

  @override
  String get groupBy => '分组方式';

  @override
  String get groupByDate => '按日期分组';

  @override
  String get groupByAccount => '按账户分组';

  @override
  String get groupByPayee => '按收款方分组';

  @override
  String get groupByType => '按类型分组';

  @override
  String get groupByCategory => '按类别分组';

  @override
  String get filterAccount => '筛选账户';

  @override
  String get amount => '金额';

  @override
  String get accounts => '账户';

  @override
  String get description => '描述';

  @override
  String get sourceAccount => '来源账户';

  @override
  String get destinationAccount => '目标账户';

  @override
  String get payee => '收款人';

  @override
  String get savingNotSupported => '只读模式下不支持保存。';

  @override
  String transactionDateCategory(String category, String date) {
    return '日期 / 类别';
  }

  @override
  String foreignAmount(String amount) {
    return '（$amount）';
  }

  @override
  String get budgetsTitle => '预算';

  @override
  String get subscriptionsTitle => '订阅与定期';

  @override
  String get newSubscription => '新建订阅';

  @override
  String get createSubscription => '创建订阅';

  @override
  String get editSubscription => '编辑订阅';

  @override
  String get subscriptionCreated => '订阅已创建。';

  @override
  String subscriptionDeleted(String name) {
    return '订阅「$name」已删除。';
  }

  @override
  String failedToCreateSubscription(String error) {
    return '创建订阅失败：$error';
  }

  @override
  String failedToUpdateSubscription(String error) {
    return '更新订阅失败：$error';
  }

  @override
  String failedToDeleteSubscription(String error) {
    return '删除订阅失败：$error';
  }

  @override
  String get deleteSubscription => '删除订阅';

  @override
  String deleteSubscriptionConfirmBody(String name) {
    return '确定要删除订阅「$name」吗？此操作无法撤销。';
  }

  @override
  String get noSubscriptionsFound => '未找到订阅。';

  @override
  String get subscriptionInactive => '未激活';

  @override
  String get subscriptionActive => '已激活';

  @override
  String get mandatoryFields => '必填信息';

  @override
  String get optionalFields => '选填信息';

  @override
  String get minimumAmount => '最低金额';

  @override
  String get maximumAmount => '最高金额';

  @override
  String get startDate => '开始日期';

  @override
  String get repeats => '重复';

  @override
  String get skip => '跳过';

  @override
  String get skipHelp => '使用跳过可创建双月（skip = 1）或其他自定义间隔。';

  @override
  String get endDate => '结束日期';

  @override
  String get endDateHelp => '选填。订阅预计在此日期结束。';

  @override
  String get extensionDate => '延期日期';

  @override
  String get extensionDateHelp => '选填。订阅须在此日期前延期（或取消）。';

  @override
  String get group => '分组';

  @override
  String get notesMarkdownHint => '此字段支持 Markdown。';

  @override
  String get repeatWeekly => '每周';

  @override
  String get repeatMonthly => '每月';

  @override
  String get repeatQuarterly => '每季度';

  @override
  String get repeatHalfYear => '每半年';

  @override
  String get repeatYearly => '每年';

  @override
  String subscriptionAmountRange(String min, String max) {
    return '$min – $max';
  }

  @override
  String get tabSubscriptions => '订阅';

  @override
  String get tabRecurringTransactions => '定期交易';

  @override
  String get badgeSubscription => '订阅';

  @override
  String get badgeRecurringTransaction => '定期交易';

  @override
  String get addSubscription => '订阅';

  @override
  String get addRecurringTransaction => '定期';

  @override
  String get noSubscriptionsOrRecurrencesFound => '未找到订阅或定期交易。';

  @override
  String get newRecurringTransaction => '新建定期交易';

  @override
  String get createRecurringTransaction => '创建定期交易';

  @override
  String get editRecurringTransaction => '编辑定期交易';

  @override
  String get recurringTransactionCreated => '定期交易已创建。';

  @override
  String recurringTransactionDeleted(String name) {
    return '定期交易「$name」已删除。';
  }

  @override
  String failedToCreateRecurringTransaction(String error) {
    return '创建定期交易失败：$error';
  }

  @override
  String failedToUpdateRecurringTransaction(String error) {
    return '更新定期交易失败：$error';
  }

  @override
  String failedToDeleteRecurringTransaction(String error) {
    return '删除定期交易失败：$error';
  }

  @override
  String get deleteRecurringTransaction => '删除定期交易';

  @override
  String deleteRecurringTransactionConfirmBody(String name) {
    return '确定要删除定期交易「$name」吗？此操作无法撤销。';
  }

  @override
  String get noRecurringTransactionsFound => '未找到定期交易。';

  @override
  String get recurringTransactionInactive => '未激活';

  @override
  String get mandatoryRecurrenceFields => '必填定期信息';

  @override
  String get optionalRecurrenceFields => '选填定期信息';

  @override
  String get mandatoryTransactionFields => '必填交易信息';

  @override
  String get optionalTransactionFields => '选填交易信息';

  @override
  String get recurrenceTitle => '标题';

  @override
  String get firstDate => '首次日期';

  @override
  String get firstDateHelp => '填写首次预计重复日期，须为未来日期。';

  @override
  String get typeOfRepetition => '重复类型';

  @override
  String get typeOfRepetitionHelp => '更改首次日期以查看更多选项。';

  @override
  String get weekendHandling => '周末';

  @override
  String get weekendCreateAnyway => '照常创建交易';

  @override
  String get weekendSkip => '不创建交易';

  @override
  String get weekendPreviousFriday => '提前至上周五';

  @override
  String get weekendNextMonday => '推迟至下周一';

  @override
  String get weekendHelp => '当定期交易落在周六或周日时，Firefly III 应如何处理？';

  @override
  String get repetitionEnds => '重复结束';

  @override
  String get repeatForever => '永久重复';

  @override
  String get repeatUntilDate => '重复至指定日期';

  @override
  String get repeatCount => '重复固定次数';

  @override
  String get numberOfRepetitions => '重复次数';

  @override
  String get applyRules => '应用规则';

  @override
  String get applyRulesHelp => '是否在每次创建交易后触发规则。';

  @override
  String get recurrenceDescription => '定期交易描述';

  @override
  String get repeatDaily => '每天';

  @override
  String get repeatNdom => '每月第 N 个工作日';

  @override
  String recurrenceAmount(String amount) {
    return '$amount';
  }

  @override
  String get tooltipOpenSubscriptions => '打开周期订阅和账单。';

  @override
  String get subscriptionsTitleRacoon => '定期突袭与计划';

  @override
  String get newSubscriptionRacoon => '新建定期突袭';

  @override
  String get piggyBanksTitle => '存钱罐';

  @override
  String get newPiggyBank => '新建存钱罐';

  @override
  String get createPiggyBank => '创建存钱罐';

  @override
  String get editPiggyBank => '编辑存钱罐';

  @override
  String get piggyBankCreated => '存钱罐已创建。';

  @override
  String piggyBankDeleted(String name) {
    return '存钱罐「$name」已删除。';
  }

  @override
  String failedToCreatePiggyBank(String error) {
    return '创建存钱罐失败：$error';
  }

  @override
  String failedToUpdatePiggyBank(String error) {
    return '更新存钱罐失败：$error';
  }

  @override
  String failedToDeletePiggyBank(String error) {
    return '删除存钱罐失败：$error';
  }

  @override
  String get deletePiggyBank => '删除存钱罐';

  @override
  String deletePiggyBankConfirmBody(String name) {
    return '确定要删除存钱罐「$name」吗？此操作无法撤销。';
  }

  @override
  String get noPiggyBanksFound => '未找到存钱罐。';

  @override
  String get targetAmount => '目标金额';

  @override
  String get piggyBankCurrencyHelp => '存钱罐只能以单一货币储蓄。';

  @override
  String get saveOnAccounts => '存入账户';

  @override
  String get piggyBankAccountsHelp => '仅接受使用所选货币的账户。';

  @override
  String get targetDate => '目标日期';

  @override
  String get targetDateHelp => '您计划完成储蓄的日期。';

  @override
  String get accountGroupDefaultAssets => '默认资产账户';

  @override
  String get accountGroupSavings => '储蓄账户';

  @override
  String get accountGroupCash => '现金钱包';

  @override
  String get accountGroupLiabilities => '负债';

  @override
  String get selectAtLeastOneAccount => '请至少选择一个账户。';

  @override
  String piggyBankProgress(String current, String target) {
    return '$current / $target';
  }

  @override
  String get piggyBanksTitleRacoon => '迷你藏匿处';

  @override
  String get newPiggyBankRacoon => '新建迷你藏匿处';

  @override
  String get newBudget => '新建预算';

  @override
  String get deleteBudget => '删除预算';

  @override
  String deleteBudgetMessage(String name) {
    return '确定要删除「$name」吗？';
  }

  @override
  String budgetDeleted(String name) {
    return '预算「$name」已删除。';
  }

  @override
  String failedToDeleteBudget(String error) {
    return '删除预算失败：$error';
  }

  @override
  String get spent => '已花费';

  @override
  String ofAmount(String amount) {
    return '共 $amount';
  }

  @override
  String overBudget(String amount) {
    return '超出预算 $amount';
  }

  @override
  String leftInBudget(String amount) {
    return '剩余 $amount';
  }

  @override
  String budgetPerPeriod(String amount, String period) {
    return '每$period $amount';
  }

  @override
  String budgetLimitForPeriod(String amount, String period) {
    return '$period $amount';
  }

  @override
  String get budgetCadenceDaily => '天';

  @override
  String get budgetCadenceWeekly => '周';

  @override
  String get budgetCadenceMonthly => '月';

  @override
  String get budgetCadenceQuarterly => '季度';

  @override
  String get budgetCadenceHalfYear => '半年';

  @override
  String get budgetCadenceYearly => '年';

  @override
  String get viewPeriod => '查看周期';

  @override
  String get budgetAmount => '预算金额';

  @override
  String get editBudget => '编辑预算';

  @override
  String get createBudget => '创建预算';

  @override
  String get createPayee => '创建收款人';

  @override
  String get createCategory => '创建类别';

  @override
  String get budgetLimit => '预算限额';

  @override
  String get autoBudget => '自动预算金额';

  @override
  String get budgetAmountMode => '限额类型';

  @override
  String get budgetAmountModeAuto => '重复周期';

  @override
  String get budgetAmountModeDateRange => '固定日期范围';

  @override
  String get budgetAmountModeNone => '无金额';

  @override
  String get budgetRepeatPeriod => '重复周期';

  @override
  String get budgetAutoType => '自动预算行为';

  @override
  String get budgetAutoTypeReset => '每期重置';

  @override
  String get budgetAutoTypeRollover => '结转未用金额';

  @override
  String get budgetAutoTypeAdjusted => '按支出调整';

  @override
  String get budgetAutoTypeNone => '无';

  @override
  String get budgetActive => '启用';

  @override
  String get budgetPeriodDaily => '每天';

  @override
  String get budgetPeriodWeekly => '每周';

  @override
  String get budgetPeriodMonthly => '每月';

  @override
  String get budgetPeriodQuarterly => '每季度';

  @override
  String get budgetPeriodHalfYear => '每半年';

  @override
  String get budgetPeriodYearly => '每年';

  @override
  String get tooltipBudgetAmountMode => '重复自动预算、固定日期范围或不设限额';

  @override
  String get tooltipBudgetRepeatPeriod => '预算金额的适用频率（如每月）';

  @override
  String get tooltipBudgetAutoType => '每个预算周期开始时的行为';

  @override
  String get tooltipBudgetStartDate => '此预算限额的起始日';

  @override
  String get tooltipBudgetEndDate => '此预算限额的结束日';

  @override
  String get tooltipBudgetActive => 'Firefly 默认隐藏未启用的预算';

  @override
  String get tooltipBudgetNotes => '预算的可选备注';

  @override
  String get tooltipBudgetCurrency => '预算金额的货币';

  @override
  String get expensesTitle => '支出';

  @override
  String get clearFilters => '清除筛选';

  @override
  String get overview => '概览';

  @override
  String get byCategory => '按类别';

  @override
  String get allCategories => '所有类别';

  @override
  String get allTypes => '所有类型';

  @override
  String get expensesFilter => '支出';

  @override
  String get transfers => '转账';

  @override
  String get expensePeriodWeek => '本周';

  @override
  String get expensePeriodMonth => '本月';

  @override
  String get expensePeriodQuarter => '本季度';

  @override
  String get expensePeriodSemester => '本学期';

  @override
  String get expensePeriodYear => '今年';

  @override
  String get expensePeriodAll => '全部';

  @override
  String get dashboardPeriodThisWeek => '本周';

  @override
  String get dashboardPeriodLastWeek => '上周';

  @override
  String get dashboardPeriodThisMonth => '本月';

  @override
  String get dashboardPeriodLastMonth => '上月';

  @override
  String get dashboardPeriodThisQuarter => '本季度';

  @override
  String get dashboardPeriodLastQuarter => '上季度';

  @override
  String get dashboardPeriodThisYear => '今年';

  @override
  String get dashboardPeriodLastYear => '去年';

  @override
  String get dashboardPeriodLast2Years => '过去 2 年';

  @override
  String get dashboardPeriodLast5Years => '过去 5 年';

  @override
  String get dashboardPeriodLast10Years => '过去 10 年';

  @override
  String get dashboardPeriodAll => '全部';

  @override
  String get deltaComparisonPreviousWeek => '上周';

  @override
  String get deltaComparisonPreviousMonth => '上月';

  @override
  String get deltaComparisonPreviousQuarter => '上季度';

  @override
  String get deltaComparisonPreviousYear => '去年';

  @override
  String get deltaComparisonPrevious2Years => '前 2 年';

  @override
  String get deltaComparisonPrevious5Years => '前 5 年';

  @override
  String get deltaComparisonPrevious10Years => '前 10 年';

  @override
  String get deltaComparisonCustomPeriod => '上一时段';

  @override
  String noChangeVsComparisonPeriod(String period) {
    return '与$period相比无变化';
  }

  @override
  String newActivityVsComparisonPeriod(String period) {
    return '与$period相比为新活动';
  }

  @override
  String percentVsComparisonPeriod(
    String arrow,
    String percent,
    String period,
  ) {
    return '较$period $arrow$percent%';
  }

  @override
  String get dateRangeSeparator => '–';

  @override
  String get dateEllipsis => '…';

  @override
  String get projectionTitle => '预测';

  @override
  String get projectedBalance => '预计余额';

  @override
  String get visualization => '可视化';

  @override
  String get parameters => '参数';

  @override
  String predictedBalances(String period) {
    return '预计余额 · $period';
  }

  @override
  String get noAccountsLoaded => '未加载账户';

  @override
  String get scenarioSummary => '情景摘要';

  @override
  String nowAmount(String amount) {
    return '当前 $amount';
  }

  @override
  String get worstCase => '最坏情况';

  @override
  String get expected => '预期';

  @override
  String get bestCase => '最好情况';

  @override
  String get moveSliderToSeeImpact => '拖动滑块查看影响';

  @override
  String whatIfImpact(String amount, String period) {
    return '$period 内 +$amount';
  }

  @override
  String get projectionPeriod3Months => '3 个月';

  @override
  String get projectionPeriod6Months => '6 个月';

  @override
  String get projectionPeriod1Year => '1 年';

  @override
  String get projectionPeriod3Years => '3 年';

  @override
  String get projectionTypeSavings => '储蓄率';

  @override
  String get projectionTypeCompound => '复利增长';

  @override
  String get projectionTypePortfolio => '投资组合（波动）';

  @override
  String get projectionTypeCashflow => '现金流';

  @override
  String get projectionTypeSavingsDesc => '基于历史净储蓄的线性预测';

  @override
  String get projectionTypeCompoundDesc => '余额随复利和投入增长';

  @override
  String get projectionTypePortfolioDesc => '预期回报及基于波动性的最差/最好区间';

  @override
  String get projectionTypeCashflowDesc => '收入减去支出，含可自由支配调整';

  @override
  String get chartStyleFan => '扇形图';

  @override
  String get chartStyleLines => '三条线';

  @override
  String get chartStyleScenarios => '情景卡片';

  @override
  String get whatIfSpending => '假设支出';

  @override
  String get annualReturn => '年回报率';

  @override
  String get volatility => '波动性';

  @override
  String projectionAlertLiability(String name, String balance) {
    return '在最坏情况下，$name 可能早于预期达到 $balance。';
  }

  @override
  String get projectionAlertBelowZero => '最坏情况预测在所选时段内降至零以下。';

  @override
  String get projectionAlertActionLiability => '考虑从储蓄账户转移资金。';

  @override
  String get projectionAlertActionSpending => '审查可自由支配支出或增加储蓄。';

  @override
  String get confirmTypeWord => '输入 ';

  @override
  String get confirmToConfirm => ' 以确认：';

  @override
  String get confirmHint => '输入上方词语…';

  @override
  String currencyPair(String name, String symbol) {
    return '$name（$symbol）';
  }

  @override
  String budgetSpentFraction(String spent, String total) {
    return '$spent / $total';
  }

  @override
  String get editAccount => '编辑账户';

  @override
  String get editAction => '编辑';

  @override
  String get filterAllShort => '全部';

  @override
  String get filterAssetsShort => '资产';

  @override
  String get filterLiabilitiesShort => '负债';

  @override
  String get showInactiveAccounts => '显示已停用账户';

  @override
  String get showInactiveAccountsShort => '已停用';

  @override
  String get accountInactive => '已停用';

  @override
  String get unknown => '未知';

  @override
  String showingTransactionsOfTotal(int loaded, int total) {
    return '显示 $loaded / $total 笔交易';
  }

  @override
  String transactionsCount(int count) {
    return '$count 笔交易';
  }

  @override
  String get oneTransaction => '1 笔交易';

  @override
  String deleteBudgetConfirmBody(String name) {
    return '确定要删除预算「$name」吗？此操作无法撤销。';
  }

  @override
  String get scrollForMore => '向下滚动查看更多…';

  @override
  String get noTransactionsMatchFilters => '没有符合当前筛选条件的交易。';

  @override
  String get category => '类别';

  @override
  String get totalSpentPeriod => '本时段总支出';

  @override
  String get totalIncomePeriod => '本时段总收入';

  @override
  String get totalTransferredPeriod => '本时段总转账';

  @override
  String get totalPeriod => '本时段总计';

  @override
  String get volatilityUncertainty => '波动性 / 不确定性';

  @override
  String get editTransaction => '编辑交易';

  @override
  String get newDeposit => '新建存入';

  @override
  String get editDeposit => '编辑存入';

  @override
  String get newWithdrawal => '新建支出';

  @override
  String get editWithdrawal => '编辑支出';

  @override
  String get newTransfer => '新建转账';

  @override
  String get editTransfer => '编辑转账';

  @override
  String get revenueAccount => '收入账户';

  @override
  String get assetAccount => '资产账户';

  @override
  String get expenseAccount => '支出账户';

  @override
  String get expenseLabel => '支出';

  @override
  String get transactionTypeDeposit => '存款';

  @override
  String get transactionTypeWithdrawal => '取款';

  @override
  String get transactionTypeTransfer => '转账';

  @override
  String get dataAndLoading => '数据与加载';

  @override
  String get transactionPageSize => '每页交易数';

  @override
  String get transactionPageSizeDescription => '每次滚动加载的交易数量。适用于交易列表。';

  @override
  String transactionPageSizeValue(int count) {
    return '每页 $count 笔';
  }

  @override
  String get defaultPeriod => '默认期间';

  @override
  String get defaultPeriodDescription => '打开仪表盘、支出、收入、转账和交易页面时应用。';

  @override
  String get customDateRange => '自定义范围';

  @override
  String get pickDates => '选择日期';

  @override
  String get budgetStatusOnTrack => '正常';

  @override
  String get budgetStatusOver => '超出预算';

  @override
  String whatIfCutSpending(int percent) {
    return '如果我将可自由支配支出减少 $percent% 会怎样？';
  }

  @override
  String get usesAveragePatterns => '使用交易中的平均收入和支出模式。';

  @override
  String get historicalNetSavingsNote => '基于历史净储蓄。调整不确定性以扩大或缩小区间。';

  @override
  String get accountFilterLabel => '账户';

  @override
  String get noTransactionsForBudget => '此预算暂无交易。';

  @override
  String get noTransactionsForAccount => '此账户暂无交易。';

  @override
  String get deleteAccount => '删除账户';

  @override
  String deleteAccountConfirmBody(String name) {
    return '确定要删除账户“$name”吗？此操作无法撤销。';
  }

  @override
  String accountDeleted(String name) {
    return '账户“$name”已删除。';
  }

  @override
  String failedToDeleteAccount(String error) {
    return '删除账户失败：$error';
  }

  @override
  String get budgetNameHint => '预算名称';

  @override
  String budgetAmountWithSymbol(String symbol) {
    return '预算金额（$symbol）';
  }

  @override
  String get chartLegendActual => '实际';

  @override
  String get chartLegendWorst => '最差';

  @override
  String get chartLegendBest => '最好';

  @override
  String get chartLegendWorstBest => '最差 ↔ 最好';

  @override
  String get today => '今天';

  @override
  String get mcpServer => 'MCP 服务器';

  @override
  String mcpStatusFailed(String error) {
    return '失败：$error';
  }

  @override
  String mcpStatusRunning(int port) {
    return '运行于端口 $port';
  }

  @override
  String get mcpStatusStarting => '启动中…';

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
  String get transactionDate => '日期';

  @override
  String get moreOptions => '更多';

  @override
  String get foreignAmountLabel => '外币金额';

  @override
  String get budgetLabel => '预算';

  @override
  String get piggyBank => '存钱罐';

  @override
  String get noPiggyBank => '（无存钱罐）';

  @override
  String get tags => '标签';

  @override
  String get subscription => '订阅';

  @override
  String get interestDate => '利息日期';

  @override
  String get attachments => '附件';

  @override
  String get notes => '备注';

  @override
  String get none => '（无）';

  @override
  String get attachmentsNotSupported => '此应用尚不支持附件。';

  @override
  String get deleteTransaction => '删除交易';

  @override
  String deleteTransactionConfirmBody(String description) {
    return '确定要删除「$description」吗？此操作无法撤销。';
  }

  @override
  String get transactionDeleted => '交易已删除。';

  @override
  String failedToDeleteTransaction(String error) {
    return '删除交易失败：$error';
  }

  @override
  String get transactionSaved => '交易已保存。';

  @override
  String failedToSaveTransaction(String error) {
    return '保存交易失败：$error';
  }

  @override
  String get transactionDuplicated => '交易已复制。';

  @override
  String failedToDuplicateTransaction(String error) {
    return '复制交易失败：$error';
  }

  @override
  String get duplicate => '复制';

  @override
  String get newTransaction => '新建交易';

  @override
  String get transactionCreated => '交易已创建。';

  @override
  String failedToCreateTransaction(String error) {
    return '创建交易失败：$error';
  }

  @override
  String get transactionFormIncomplete => '请填写描述、金额和两个账户。';

  @override
  String get transactionInformation => '交易信息';

  @override
  String get addAnotherSplit => '添加分拆';

  @override
  String splitLabel(int number) {
    return 'Split $number';
  }

  @override
  String get removeSplit => '移除分拆';

  @override
  String splitCount(int count) {
    return '$count splits';
  }

  @override
  String splitCategoriesCount(int count) {
    return '$count categories';
  }

  @override
  String get splitMainAmount => '总金额';

  @override
  String get tooltipSplitMainAmount => '交易总金额。保存前各分拆金额之和必须与此一致。';

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
    return '分拆金额合计须为 $expected。';
  }

  @override
  String get splitOptionalFields => '选填字段';

  @override
  String get foreignCurrency => '外币';

  @override
  String get noSubscriptionsHint => '您还没有订阅。请在订阅页面创建以关联定期支出。';

  @override
  String get incomeTitle => '收入';

  @override
  String get transfersTitle => '转账';

  @override
  String get newTransferAction => '新建转账';

  @override
  String get liabilitiesTitle => '负债';

  @override
  String get newIncome => '新建收入';

  @override
  String get newIncomeRacoon => '新建截获';

  @override
  String get create => '创建';

  @override
  String get accountCreated => '账户已创建。';

  @override
  String get liabilityCreated => '负债已创建。';

  @override
  String get budgetCreated => '预算已创建。';

  @override
  String failedToCreateAccount(String error) {
    return '创建账户失败：$error';
  }

  @override
  String failedToCreateBudget(String error) {
    return '创建预算失败：$error';
  }

  @override
  String get noLiabilitiesFound => '未找到负债。';

  @override
  String get liabilityType => '负债类型';

  @override
  String get liabilityTypeDebt => '债务';

  @override
  String get liabilityTypeLoan => '贷款';

  @override
  String get liabilityTypeMortgage => '抵押';

  @override
  String get liabilityDirection => '负债方向';

  @override
  String get liabilityDirectionOwe => '我欠他人';

  @override
  String get liabilityDirectionOwed => '他人欠我';

  @override
  String get amountOwed => '欠款金额';

  @override
  String get debtStartDate => '债务开始日期';

  @override
  String get interestRate => '利率';

  @override
  String get interestPeriod => '计息周期';

  @override
  String get interestPeriodDaily => '每日';

  @override
  String get includeInNetWorth => '计入净资产';

  @override
  String get accountNumber => '账号';

  @override
  String get iban => 'IBAN';

  @override
  String get bic => 'BIC';

  @override
  String get liabilityCurrencyHelp => '此负债账户的默认货币。';

  @override
  String get interestPeriodHelp => '仅作展示 — Firefly III 不会自动计算利息。';

  @override
  String failedToCreateLiability(String error) {
    return '创建负债失败：$error';
  }

  @override
  String get navIncomeRacoon => '截获';

  @override
  String get navTransfersRacoon => '藏匿转移';

  @override
  String get navLiabilitiesRacoon => '欠债';

  @override
  String get incomeTitleRacoon => '截获资金';

  @override
  String get transfersTitleRacoon => '藏匿转移';

  @override
  String get newTransferActionRacoon => '新建藏匿转移';

  @override
  String get liabilitiesTitleRacoon => '所欠债务';

  @override
  String tooltipOpenSection(String section) {
    return '打开$section。';
  }

  @override
  String get tooltipOpenDashboard => '打开仪表盘与关键指标。';

  @override
  String get tooltipOpenAccounts => '打开您的账户和余额。';

  @override
  String get tooltipOpenTransactions => '打开全部交易和筛选条件。';

  @override
  String get tooltipOpenBudgets => '打开预算与支出进度。';

  @override
  String get tooltipOpenPiggyBanks => '打开储蓄目标和存钱罐。';

  @override
  String get tooltipOpenExpenses => '打开支出分析。';

  @override
  String get tooltipOpenIncome => '打开收入分析。';

  @override
  String get tooltipOpenTransfers => '打开转账历史与分析。';

  @override
  String get tooltipOpenLiabilities => '打开负债和债务概览。';

  @override
  String get tooltipOpenProjection => '打开预测场景和预估。';

  @override
  String get tooltipOpenPrognosis => '打开月末账户余额预测。';

  @override
  String get projectionTabLongTerm => '长期预测';

  @override
  String get tooltipOpenSettings => '打开应用设置和 Firefly 连接。';

  @override
  String get tooltipToggleSidebar => '展开或收起侧边栏。';

  @override
  String get tooltipSearchTransactions => '在当前页面按文本搜索。';

  @override
  String get tooltipToggleViewMode => '在列表视图和网格视图间切换。';

  @override
  String get refreshFromFirefly => '刷新';

  @override
  String get tooltipRefreshFromFirefly => '从 Firefly III 重新拉取数据';

  @override
  String get viewModeCards => '卡片';

  @override
  String get viewModeRows => '行';

  @override
  String get viewModeTightRows => '紧凑行';

  @override
  String get columnSelection => '选择列';

  @override
  String get columnDate => '日期';

  @override
  String get columnAccount => '账户';

  @override
  String get columnType => '类型';

  @override
  String get columnPayee => '收款人';

  @override
  String get columnDescription => '备注';

  @override
  String get columnCategory => '分类';

  @override
  String get columnBudget => '预算';

  @override
  String get columnAmount => '金额';

  @override
  String get columnReconciled => '已对账';

  @override
  String get columnBalance => '余额';

  @override
  String get tooltipTransactionType => '选择交易类型。';

  @override
  String get tooltipFieldDescription => '这笔交易发生了什么。';

  @override
  String get tooltipFieldSourceAccount => '资金来源账户。';

  @override
  String get tooltipFieldDestinationAccount => '资金去向账户。';

  @override
  String get tooltipFieldDate => '交易日期和时间。';

  @override
  String get tooltipFieldAmount => '所选货币下的主金额。';

  @override
  String get tooltipFieldCurrency => '该分录的主货币。';

  @override
  String get tooltipFieldForeignAmount => '可选的外币金额。';

  @override
  String get tooltipFieldForeignCurrency => '外币金额使用的货币。';

  @override
  String get tooltipFieldBudget => '将该分录关联到预算。';

  @override
  String get tooltipFieldCategory => '用于报表和筛选的分类。';

  @override
  String get tooltipFieldPiggyBank => '将该分录关联到存钱罐。';

  @override
  String get tooltipFieldTags => '用逗号分隔标签，便于快速筛选。';

  @override
  String get tooltipFieldSubscription => '将该分录关联到订阅。';

  @override
  String get tooltipFieldInterestDate => '可选的计息或入账日期。';

  @override
  String get tooltipFieldAttachments => '可显示附件，但暂不支持上传。';

  @override
  String get tooltipFieldNotes => '补充备注，便于后续查看。';

  @override
  String get tooltipAddSplit => '为该交易新增一个分录。';

  @override
  String get tooltipRemoveSplit => '移除此分录行。';

  @override
  String get tooltipCancelTransaction => '放弃更改并关闭。';

  @override
  String get tooltipSaveTransaction => '保存这笔交易。';

  @override
  String get tooltipCancel => '放弃更改并关闭，不保存。';

  @override
  String get tooltipSave => '保存您的更改。';

  @override
  String get tooltipCreate => '创建新项目。';

  @override
  String get tooltipConfirmDelete => '永久删除此项目。';

  @override
  String get tooltipConfirmChallenge => '输入挑战词以确认删除。';

  @override
  String get tooltipExpandDetails => '显示更多详情。';

  @override
  String get tooltipCollapseDetails => '隐藏额外详情。';

  @override
  String get tooltipClearDate => '移除所选日期。';

  @override
  String get tooltipAccountName => '在列表和报表中显示的名称。';

  @override
  String get tooltipAccountCurrentBalance => '截至今天的 Firefly 当前余额。';

  @override
  String get tooltipAccountEndOfMonthBalance => '所选日期的预计余额，包含计划交易、周期性交易和账单。';

  @override
  String get tooltipBalanceDatePick => '显示其他日期的余额';

  @override
  String get tooltipBalanceDateReset => '回到本月末';

  @override
  String get tooltipBalanceBeyondForecast => '预测未覆盖到这么远，因此这是最后一个预测数值。';

  @override
  String get tooltipRecordedBalance => '账簿截至该日期的余额，包含已提前记日期的交易。';

  @override
  String get tooltipBudgetName => '此支出预算的名称。';

  @override
  String get tooltipBudgetAmount => '此预算周期的限额金额。';

  @override
  String get tooltipSubscriptionName => '定期账单或订阅的名称。';

  @override
  String get tooltipSubscriptionCurrency => '预期金额使用的货币。';

  @override
  String get tooltipSubscriptionAmountMin => '每周期最低预期费用。';

  @override
  String get tooltipSubscriptionAmountMax => '每周期最高预期费用。';

  @override
  String get tooltipSubscriptionStartDate => '订阅开始或首次记录的日期。';

  @override
  String get tooltipSubscriptionRepeats => '此订阅重复的频率。';

  @override
  String get tooltipSubscriptionSkip => '在再次扣款前跳过接下来 N 次。';

  @override
  String get tooltipSubscriptionEndDate => '订阅结束的可选日期。';

  @override
  String get tooltipSubscriptionExtensionDate => '延长或暂停计费的可选日期。';

  @override
  String get tooltipSubscriptionGroup => '用于整理订阅的可选分组标签。';

  @override
  String get tooltipSubscriptionActive => '此订阅当前是否处于活动状态。';

  @override
  String get tooltipPiggyBankName => '此储蓄目标的名称。';

  @override
  String get tooltipPiggyBankTargetAmount => '您希望储蓄的总金额。';

  @override
  String get tooltipPiggyBankCurrency => '目标和跟踪储蓄使用的货币。';

  @override
  String get tooltipPiggyBankAccounts => '余额计入此目标的账户。';

  @override
  String tooltipPiggyBankAccount(String name) {
    return '将 $name 纳入此存钱罐。';
  }

  @override
  String get tooltipPiggyBankStartDate => '开始跟踪此目标的日期。';

  @override
  String get tooltipPiggyBankTargetDate => '达成目标的可选截止日期。';

  @override
  String get tooltipPiggyBankGroup => '用于整理存钱罐的可选分组标签。';

  @override
  String get tooltipThemeLight => '使用浅色配色方案。';

  @override
  String get tooltipThemeDark => '使用深色配色方案。';

  @override
  String get tooltipThemePaletteClassic => '受 Firefly 启发的经典调色板。';

  @override
  String get tooltipThemePaletteSpectrum => '鲜艳的多色分类调色板。';

  @override
  String get tooltipThemePaletteRaccoon => '有趣的浣熊主题调色板。';

  @override
  String get tooltipThemeAccent => '按钮、链接和高亮的强调色。';

  @override
  String tooltipThemeAccentOption(String name) {
    return '将 $name 设为强调色。';
  }

  @override
  String get tooltipThemeDone => '关闭并保留所选主题。';

  @override
  String get repeatIntervalLabel => '间隔';

  @override
  String get repeatIntervalHelp => '重复频率，例如每 3 个月一次。';

  @override
  String repeatEveryNDays(int count) {
    return '每 $count 天';
  }

  @override
  String repeatEveryNWeeks(int count) {
    return '每 $count 周';
  }

  @override
  String repeatEveryNMonths(int count) {
    return '每 $count 个月';
  }

  @override
  String repeatEveryNYears(int count) {
    return '每 $count 年';
  }

  @override
  String get writeAheadDays => '提前写入定期交易';

  @override
  String get writeAheadDaysDescription => '提前这么多天创建即将发生的定期交易。';

  @override
  String get writeAheadOff => '关闭';

  @override
  String writeAheadNDays(int count) {
    return '$count 天';
  }

  @override
  String get plannedLabel => '计划中';

  @override
  String get navHistory => '历史';

  @override
  String get navHistoryRacoon => '行动回放';

  @override
  String get tooltipOpenHistory => '打开撤销/重做历史。';

  @override
  String get tooltipUndo => '撤销上一步操作。';

  @override
  String get tooltipRedo => '重做上一步撤销的操作。';

  @override
  String get undo => '撤销';

  @override
  String get redo => '重做';

  @override
  String get clear => '清除';

  @override
  String get advanced => '高级';

  @override
  String get undoHistorySize => '撤销/重做历史大小';

  @override
  String undoHistoryStoredEntries(int count, int limit) {
    return '已存储条目：$count / $limit';
  }

  @override
  String get openHistoryScreen => '打开历史页面';

  @override
  String undoHistoryLimitRange(int min, int defaultValue, int max) {
    return '最小 $min  •  默认 $defaultValue  •  最大 $max';
  }

  @override
  String get searchHistory => '搜索历史';

  @override
  String get allActions => '全部操作';

  @override
  String get noHistoryEntriesMatchFilters => '没有符合筛选条件的历史条目。';

  @override
  String historyExportedTo(String path) {
    return '历史已导出至 $path';
  }

  @override
  String get historyExportedAndShared => '历史已导出并打开分享面板';

  @override
  String get exportJson => '导出 JSON';

  @override
  String get exportAndShare => '导出并分享';

  @override
  String get jumpToCurrent => '跳转到当前项';

  @override
  String get historyExportSubject => '历史导出';

  @override
  String get historyExportText => 'FireRacoon 历史导出';

  @override
  String get historySectionToday => '今天';

  @override
  String get historySectionYesterday => '昨天';

  @override
  String get historySectionOlder => '更早';

  @override
  String historyEntriesCount(int count, int limit) {
    return '$count / $limit';
  }

  @override
  String get undoActionTypeThemeMode => '主题模式';

  @override
  String get undoActionTypeThemePalette => '主题调色板';

  @override
  String get undoActionTypeThemeAccent => '主题强调色';

  @override
  String get undoActionTypeThemeFunMode => '趣味模式';

  @override
  String get undoActionTypeLocale => '语言';

  @override
  String get undoActionTypeViewMode => '视图模式';

  @override
  String get undoActionTypeTransactionPageSize => '每页交易数';

  @override
  String get undoActionTypePrognosisMode => '预测视图模式';

  @override
  String get undoActionTypePrognosisHorizon => '预测时间范围';

  @override
  String get undoActionTypePrognosisInclusion => '预测包含项';

  @override
  String get undoActionTypePrognosisMarginPercent => '预测余量';

  @override
  String get undoActionTypeAccountCreate => '账户已创建';

  @override
  String get undoActionTypeAccountUpdate => '账户已更新';

  @override
  String get undoActionTypeAccountDelete => '账户已删除';

  @override
  String get undoActionTypeBudgetCreate => '预算已创建';

  @override
  String get undoActionTypeBudgetUpdate => '预算已更新';

  @override
  String get undoActionTypeBudgetDelete => '预算已删除';

  @override
  String get undoActionTypeTransactionCreate => '交易已创建';

  @override
  String get undoActionTypeTransactionUpdate => '交易已更新';

  @override
  String get undoActionTypeTransactionDelete => '交易已删除';

  @override
  String get undoActionTypeBillCreate => '订阅已创建';

  @override
  String get undoActionTypeBillUpdate => '订阅已更新';

  @override
  String get undoActionTypeBillDelete => '订阅已删除';

  @override
  String get undoActionTypeRecurrenceCreate => '周期交易已创建';

  @override
  String get undoActionTypeRecurrenceUpdate => '周期交易已更新';

  @override
  String get undoActionTypeRecurrenceDelete => '周期交易已删除';

  @override
  String get undoActionTypePiggyBankCreate => '存钱罐已创建';

  @override
  String get undoActionTypePiggyBankUpdate => '存钱罐已更新';

  @override
  String get undoActionTypePiggyBankDelete => '存钱罐已删除';

  @override
  String get undoActionTypeLiabilityCreate => '负债已创建';

  @override
  String get searchHintTitle => '输入以开始搜索';

  @override
  String get searchHintSubtitle => '按描述、账户、分类、标签、备注或金额搜索。';

  @override
  String get noSuggestions => '无匹配建议';

  @override
  String get invalidAmount => '金额必须是大于0的有效数字。';

  @override
  String get invalidForeignAmount => '外币金额必须是大于0的有效数字。';

  @override
  String get exportFireflyData => '备份 Firefly 数据';

  @override
  String get exportFireflyDataDescription =>
      '将您的 Firefly 数据快照保存为 JSON 文件：账户、包含每个拆分的交易、预算、分类、标签、账单、存钱罐、周期规则和货币。\n\n这不是完整备份。Firefly III 没有备份功能，通过其 API 通信的应用无法访问数据库、已上传的附件或实例密钥。恢复可用的 Firefly 需要在服务器上制作的卷归档；请参阅部署指南。';

  @override
  String fireflyDataExportedTo(String path) {
    return 'Firefly 数据已导出到 $path';
  }

  @override
  String get missingInformation => '缺失信息';

  @override
  String get missingDescription => '请输入描述。';

  @override
  String get missingAmount => '请输入金额。';

  @override
  String get missingAccounts => '请同时选择来源账户和目标账户。';

  @override
  String get appUsers => '应用用户';

  @override
  String get enableAppUsers => '启用应用用户';

  @override
  String get enableAppUsersDescription =>
      'Add password-protected profiles for the people who use this app. Everyone still shares the same Firefly III data.';

  @override
  String get createAdmin => '创建管理员账户';

  @override
  String get createAdminDescription =>
      'You will be the first admin. You can add more accounts afterwards.';

  @override
  String get addUser => '添加用户';

  @override
  String get editUser => '编辑用户';

  @override
  String get deleteUser => '删除用户';

  @override
  String get role => '角色';

  @override
  String get roleAdmin => '管理员';

  @override
  String get roleUser => '用户';

  @override
  String get roleViewer => '查看者';

  @override
  String get roleAdminDescription =>
      'Full access, including Firefly settings and user management.';

  @override
  String get roleUserDescription => 'Can add and edit financial data.';

  @override
  String get roleViewerDescription => 'Read-only access.';

  @override
  String get requireLogin => '每次启动都需要登录';

  @override
  String get requireLoginDescription =>
      'When off, signed-in users stay signed in between launches.';

  @override
  String get switchUser => 'Switch user';

  @override
  String get selectUserSubtitle =>
      'Choose whose profile to use. No password needed while login is not required.';

  @override
  String get assignPerson => '关联的人';

  @override
  String get noPersonAssigned => '无';

  @override
  String get myAccount => '我的账户';

  @override
  String get changePassword => '修改密码';

  @override
  String get setPassword => 'Set password';

  @override
  String get clearPassword => 'Remove password';

  @override
  String get passwordOptionalHint =>
      'Optional. Leave blank to skip. Required only if login with password is enabled.';

  @override
  String get currentPassword => '当前密码';

  @override
  String get newPassword => '新密码';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get logout => '退出登录';

  @override
  String get login => '登录';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get loginSubtitle => '登录以继续使用 FireRacoon。';

  @override
  String get loginMissingFields => '请输入用户名和密码。';

  @override
  String get loginInvalidCredentials => '用户名或密码不正确。';

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
  String get passwordsDoNotMatch => '两次输入的密码不一致。';

  @override
  String get usernameTaken => '该用户名已被使用。';

  @override
  String get currentPasswordIncorrect => '当前密码不正确。';

  @override
  String get userCreated => '用户已创建。';

  @override
  String get userUpdated => '用户已更新。';

  @override
  String get userDeleted => '用户已删除。';

  @override
  String get passwordChanged => '密码已更新。';

  @override
  String get passwordCleared => 'Password removed.';

  @override
  String get deleteUserConfirmTitle => '删除用户';

  @override
  String deleteUserConfirmMessage(String username) {
    return 'This removes $username\'s app profile. Their Firefly III data is not affected.';
  }

  @override
  String signedInAs(String username) {
    return '已登录：$username';
  }

  @override
  String get usernameRequired => '请输入用户名。';

  @override
  String get unlockWithBiometrics => '使用生物识别解锁';

  @override
  String get unlockWithBiometricsDescription => '在登录界面使用面容、指纹或设备 PIN。';

  @override
  String get biometricUnlockReason => '解锁 FireRacoon';

  @override
  String get biometricEnableReason => '确认以启用生物识别解锁';

  @override
  String get biometricUnlockFailed => '生物识别解锁已取消或失败。';

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
  String get recordedBalance => '已记账';
}
