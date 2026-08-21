// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'FireRacoon';

  @override
  String get appTagline => '予算を守る、いちばん賢い仲間。';

  @override
  String get appNameFire => 'Fire';

  @override
  String get appNameRacoon => 'Racoon';

  @override
  String get navDashboard => 'ダッシュボード';

  @override
  String get navDashboardShort => '概要';

  @override
  String get navAccounts => '口座';

  @override
  String get navTransactions => '取引';

  @override
  String get navBudgets => '予算';

  @override
  String get navSubscriptions => 'サブスクリプションと定期取引';

  @override
  String get navPiggyBanks => '貯金箱';

  @override
  String get navExpenses => '支出';

  @override
  String get navIncome => '収入';

  @override
  String get navTransfers => '振替';

  @override
  String get navLiabilities => '負債';

  @override
  String get navProjection => '予測';

  @override
  String get navPrognosis => '見通し';

  @override
  String get navSettings => '設定';

  @override
  String get netWorth => '純資産';

  @override
  String get search => '検索...';

  @override
  String get loading => '読み込み中…';

  @override
  String get fireflyUser => 'Firefly ユーザー';

  @override
  String get fireflyConnected => 'Firefly III · 接続済み';

  @override
  String get fireflyDisconnected => 'Firefly III · 未接続';

  @override
  String get fireflyConnectionChecking => 'Firefly III · 確認中…';

  @override
  String get settingsTitle => '設定';

  @override
  String appVersion(String version) {
    return 'バージョン $version';
  }

  @override
  String get language => '言語';

  @override
  String get selectLanguage => '言語を選択';

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
  String get defaultCurrency => 'デフォルト通貨';

  @override
  String get selectCurrency => '通貨を選択';

  @override
  String get primaryCurrencyChangeWarning =>
      'デフォルト通貨を変更すると、Firefly III が保存済みの金額を再計算する場合があります。';

  @override
  String primaryCurrencyChanged(String code) {
    return 'デフォルト通貨を $code に設定しました';
  }

  @override
  String failedToSetPrimaryCurrency(String error) {
    return 'デフォルト通貨の設定に失敗しました: $error';
  }

  @override
  String get primaryCurrencyCurrent => '現在';

  @override
  String get changePrimaryCurrencyTitle => 'デフォルト通貨を変更';

  @override
  String changePrimaryCurrencyMessage(String code, String warning) {
    return 'デフォルト通貨を $code に変更しますか？$warning';
  }

  @override
  String get changePrimaryCurrencyConfirm => '変更';

  @override
  String get connectToFireflyToLoad => 'Firefly III に接続して読み込み';

  @override
  String get managedInFirefly => 'Firefly III で管理';

  @override
  String get appearance => '外観';

  @override
  String get racoonMode => 'アライグマモード';

  @override
  String get themeStyle => 'テーマスタイル';

  @override
  String get themeStyleSubtitle => 'パレット、アクセントカラー、明るさを選択します。変更はすぐに反映されます。';

  @override
  String get systemDefault => 'システムのデフォルト';

  @override
  String get themeBrightness => '明るさ';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get themePalette => 'パレット';

  @override
  String get paletteClassic => 'クラシック';

  @override
  String get paletteSpectrum => 'スペクトラム';

  @override
  String get paletteRaccoon => 'アライグマ';

  @override
  String get themeAccentColor => 'アクセントカラー';

  @override
  String get themePreview => 'プレビュー';

  @override
  String get done => '完了';

  @override
  String get accentGreen => 'グリーン';

  @override
  String get accentTeal => 'ティール';

  @override
  String get accentBlue => 'ブルー';

  @override
  String get accentOrange => 'オレンジ';

  @override
  String get accentRed => 'レッド';

  @override
  String get accentViolet => 'バイオレット';

  @override
  String get accentLime => 'ライム';

  @override
  String get accentSky => 'スカイ';

  @override
  String get accentCharcoal => 'チャコール';

  @override
  String get accentSilver => 'シルバー';

  @override
  String get accentTan => 'タン';

  @override
  String get accentAmber => 'アンバー';

  @override
  String get accentSlate => 'スレート';

  @override
  String get accentMidnight => 'ミッドナイト';

  @override
  String get accentSmoke => 'スモーク';

  @override
  String get accentPearl => 'パール';

  @override
  String get backendConnection => 'バックエンド接続（Firefly III）';

  @override
  String get serverUrl => 'サーバー URL';

  @override
  String get notConnected => '未接続';

  @override
  String get oauth2Connection => 'OAuth2 接続';

  @override
  String get personalAccessToken => 'パーソナルアクセストークン';

  @override
  String get notSet => '未設定';

  @override
  String get disconnect => '切断';

  @override
  String get fireflyConnectionTitle => 'Firefly III 接続';

  @override
  String get serverUrlLabel => 'サーバー URL（例: https://firefly.my-domain.com）';

  @override
  String get allowHttpConnections => 'HTTP 接続を許可';

  @override
  String get authenticationMethod => '認証方法';

  @override
  String get oauth2 => 'OAuth2';

  @override
  String get oauthClientId => 'OAuth クライアント ID';

  @override
  String get testConnection => '接続をテスト';

  @override
  String get connectionSuccessful => '接続に成功しました！';

  @override
  String get connectionFailed => '接続に失敗しました。URL とトークンを確認してください。';

  @override
  String get loginViaBrowser => 'ブラウザでログイン';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String errorGeneric(String error) {
    return 'エラー: $error';
  }

  @override
  String errorLoadingData(String error) {
    return 'データの読み込みエラー: $error';
  }

  @override
  String get tabInsights => 'インサイト';

  @override
  String get tabAccounts => '口座';

  @override
  String get tabFocus => 'フォーカス';

  @override
  String get totalBalance => '合計残高';

  @override
  String incomeMonth(String month) {
    return '収入 · $month';
  }

  @override
  String spendingMonth(String month) {
    return '支出 · $month';
  }

  @override
  String savedMonth(String month) {
    return '貯蓄 · $month';
  }

  @override
  String get snatchedFunds => 'ゲットした資金';

  @override
  String get burntCash => '使い切った現金';

  @override
  String get stash => '隠し場所';

  @override
  String get snatched => 'ゲット';

  @override
  String get burnt => '消費';

  @override
  String get navDashboardRacoon => 'アジト';

  @override
  String get navDashboardShortRacoon => 'アジト';

  @override
  String get navAccountsRacoon => '隠し場所';

  @override
  String get navTransactionsRacoon => '作戦ログ';

  @override
  String get navBudgetsRacoon => '宝物計画';

  @override
  String get navSubscriptionsRacoon => '定期レイド';

  @override
  String get navPiggyBanksRacoon => 'ミニ隠し場所';

  @override
  String get navExpensesRacoon => '消費レポート';

  @override
  String get navProjectionRacoon => '水晶の宝物庫';

  @override
  String get navPrognosisRacoon => '月末の戦利品';

  @override
  String get navSettingsRacoon => 'アジトのルール';

  @override
  String get netWorthRacoon => '総宝物';

  @override
  String get searchRacoon => '嗅ぎ回る…';

  @override
  String get accountsTitleRacoon => '隠し場所';

  @override
  String get transactionsTitleRacoon => '作戦ログ';

  @override
  String get budgetsTitleRacoon => '宝物計画';

  @override
  String get expensesTitleRacoon => '消費レポート';

  @override
  String get projectionTitleRacoon => '水晶の宝物庫';

  @override
  String get settingsTitleRacoon => 'アジトのルール';

  @override
  String get tabInsightsRacoon => '戦利品情報';

  @override
  String get tabAccountsRacoon => '隠し場所';

  @override
  String get tabFocusRacoon => '作戦本部';

  @override
  String get totalBalanceRacoon => '全隠し場所';

  @override
  String incomeMonthRacoon(String month) {
    return 'ゲット · $month';
  }

  @override
  String spendingMonthRacoon(String month) {
    return '消費 · $month';
  }

  @override
  String savedMonthRacoon(String month) {
    return '隠匿 · $month';
  }

  @override
  String get cashFlowRacoon => '戦利品の流れ';

  @override
  String get whereMoneyGoesRacoon => '戦利品の行き先';

  @override
  String get recentActivityRacoon => '最近のレイド';

  @override
  String get yourAccountsRacoon => 'あなたの隠し場所';

  @override
  String get budgetsAtGlanceRacoon => '宝物の概要';

  @override
  String get viewAllAccountsRacoon => 'すべての隠し場所';

  @override
  String get assetAccountsRacoon => '宝物の隠し場所';

  @override
  String get liabilityAccountsRacoon => '借金と未払い';

  @override
  String get stocksAndFundsAccountsRacoon => '市場の隠し場所';

  @override
  String get allAccountsRacoon => 'すべての隠し場所';

  @override
  String get accountsRacoon => '隠し場所';

  @override
  String get newTransactionRacoon => '作戦を計画';

  @override
  String get editTransactionRacoon => '作戦を編集';

  @override
  String transactionsCountRacoon(int count) {
    return '$count 件の作戦';
  }

  @override
  String get oneTransactionRacoon => '1 件の作戦';

  @override
  String get transactionTypeDepositRacoon => 'ゲット';

  @override
  String get transactionTypeWithdrawalRacoon => '消費';

  @override
  String get transactionTypeTransferRacoon => '隠し場所の移動';

  @override
  String get expenseLabelRacoon => '消費';

  @override
  String get spentRacoon => '消費済み';

  @override
  String get newBudgetRacoon => '新しい宝物計画';

  @override
  String get projectedBalanceRacoon => '未来の宝物';

  @override
  String get piggyBankRacoon => 'ミニ隠し場所';

  @override
  String get transfersRacoon => '隠し場所の移動';

  @override
  String get expensesFilterRacoon => '消費';

  @override
  String get noTransactionsYetRacoon => 'まだ作戦はありません';

  @override
  String get lookingAheadRacoon => '先をのぞく';

  @override
  String get openProjectionRacoon => '未来をのぞく';

  @override
  String get editAccountRacoon => '隠し場所を編集';

  @override
  String get accountNameRacoon => '隠し場所の名前';

  @override
  String get filterAccountRacoon => '隠し場所で絞り込み';

  @override
  String get sourceAccountRacoon => '送り元の隠し場所';

  @override
  String get destinationAccountRacoon => '送り先の隠し場所';

  @override
  String get totalSpentPeriodRacoon => 'この期間の消費合計';

  @override
  String get totalIncomePeriodRacoon => 'この期間のゲット合計';

  @override
  String get totalTransferredPeriodRacoon => 'この期間の移動合計';

  @override
  String get newAccount => '新しい口座';

  @override
  String get newLiability => '新しい負債';

  @override
  String get newExpense => '新しい支出';

  @override
  String get newAccountRacoon => '新しい隠し場所';

  @override
  String get newLiabilityRacoon => '新しい借金';

  @override
  String get newExpenseRacoon => '消費を計画';

  @override
  String get income => '収入';

  @override
  String get spending => '支出';

  @override
  String get saved => '貯蓄';

  @override
  String get cashFlow => 'キャッシュフロー';

  @override
  String get whereMoneyGoes => 'お金の行き先';

  @override
  String get noSpendingThisMonth => '今月はまだ支出がありません';

  @override
  String get recentActivity => '最近のアクティビティ';

  @override
  String get viewAll => 'すべて表示';

  @override
  String get noTransactionsYet => 'まだ取引がありません';

  @override
  String get lookingAhead => '先を見る';

  @override
  String get spendingPaceWarning => '今月は支出のペースが収入を上回る可能性があります';

  @override
  String get openProjection => '予測を開く';

  @override
  String get yourAccounts => 'あなたの口座';

  @override
  String get budgetsAtGlance => '予算の概要';

  @override
  String get viewAllAccounts => 'すべての口座を表示';

  @override
  String get thirtyDayOutlook => '30 日間の見通し';

  @override
  String get monthEndPrognosis => '月末の見通し';

  @override
  String get projectedEndOfMonth => '月末';

  @override
  String get includeCreditCardPayments => 'クレジットカードの支払いを含める';

  @override
  String prognosisDeltaPositive(String amount) {
    return '+$amount 見込み';
  }

  @override
  String prognosisDeltaNegative(String amount) {
    return '$amount 見込み';
  }

  @override
  String get prognosisLowBalanceWarning => '予測残高がマイナスになる可能性があります';

  @override
  String get prognosisDebtWarning => '予測負債が増加する可能性があります';

  @override
  String get openPrognosis => '見通しを開く';

  @override
  String get prognosisMarginLabel => '誤差の範囲';

  @override
  String prognosisMarginDetail(String percent) {
    return '金額の不確実性 ±$percent%';
  }

  @override
  String get prognosisIncludeScheduled => '予定取引';

  @override
  String get prognosisIncludeRecurring => '定期取引';

  @override
  String get prognosisIncludeBills => 'サブスクリプション';

  @override
  String get prognosisIncludeIncome => '収入';

  @override
  String get prognosisIncludeExpenses => '支出';

  @override
  String get prognosisIncludeTransfers => '振替';

  @override
  String get prognosisIncludeCreditCards => 'クレジットカード';

  @override
  String get prognosisEndOfNextMonth => '翌月末';

  @override
  String get prognosisMinBalance => '最小見通し';

  @override
  String get prognosisMaxBalance => '最大見通し';

  @override
  String get prognosisExpectedBalance => '予想';

  @override
  String get prognosisSelectAccount => '口座';

  @override
  String get prognosisBandLegend => '影付きの帯は最小〜最大の範囲、線は予想値を示します';

  @override
  String get prognosisModeExpected => '実際の予測';

  @override
  String get prognosisModeProjected => '推測的な予測';

  @override
  String get prognosisModeExpectedHint => '現在残高、予定取引、定期項目、請求から算出した月末残高';

  @override
  String get prognosisModeProjectedHint => '過去の純キャッシュフローに基づくトレンド予測';

  @override
  String get prognosisHorizonLabel => '期間';

  @override
  String get prognosisHorizonEndOfMonth => '月末';

  @override
  String get prognosisHorizonEndOfNextMonth => '翌月';

  @override
  String get prognosisHorizonTwoMonths => '2 か月';

  @override
  String get prognosisHorizonThreeMonths => '3 か月';

  @override
  String get prognosisHorizonSixMonths => '6 か月';

  @override
  String get prognosisHorizonOneYear => '1 年';

  @override
  String get prognosisHorizonThreeYears => '3 年';

  @override
  String get prognosisHorizonFiveYears => '5 年';

  @override
  String get prognosisHorizonTenYears => '10 年';

  @override
  String get prognosisMilestoneThreeMonths => '3 か月後';

  @override
  String get prognosisMilestoneSixMonths => '6 か月後';

  @override
  String get prognosisMilestoneOneYear => '1 年後';

  @override
  String get prognosisIncludeSources => '予測に含める';

  @override
  String get prognosisIncludeLiabilities => '負債';

  @override
  String prognosisNegativeOn(String date) {
    return '$date にマイナス';
  }

  @override
  String get prognosisCurrentBalance => '現在残高';

  @override
  String get prognosisPredictedBalances => '予測残高';

  @override
  String get todaysTimeline => '今日のタイムライン';

  @override
  String get noActivityToday => '今日のアクティビティはありません';

  @override
  String get noChangeVsLastMonth => '先月と変化なし';

  @override
  String get newActivityThisMonth => '今月の新しいアクティビティ';

  @override
  String percentVsLastMonth(String arrow, String percent) {
    return '$arrow$percent% 先月比';
  }

  @override
  String projectedSavingsHeadline(String amount) {
    return '今月の予測貯蓄 $amount';
  }

  @override
  String onPaceDetail(String amount) {
    return '月末までに $amount 貯蓄のペース';
  }

  @override
  String spendingOutpacingDetail(String amount) {
    return '支出が収入を $amount 上回っています';
  }

  @override
  String get accountsTitle => '口座';

  @override
  String get assetAccounts => '資産口座';

  @override
  String get stocksAndFundsAccounts => '株式・投信口座';

  @override
  String get liabilityAccounts => '負債口座';

  @override
  String get noAccountsFound => '口座が見つかりません。';

  @override
  String get allAccounts => 'すべての口座';

  @override
  String get assetsOnly => '資産のみ';

  @override
  String get liabilitiesOnly => '負債のみ';

  @override
  String get accountName => '口座名';

  @override
  String get accountRoleDefault => '当座預金';

  @override
  String get accountRoleShared => '共有口座';

  @override
  String get accountRoleSaving => '普通預金';

  @override
  String get accountRoleCreditCard => 'クレジットカード';

  @override
  String get holdingAccountFundLabel => '(投信)';

  @override
  String get holdingAccountStockLabel => '(株式)';

  @override
  String failedToUpdate(String error) {
    return '更新に失敗しました: $error';
  }

  @override
  String get name => '名前';

  @override
  String get transactionsTitle => '取引';

  @override
  String filteredBy(String account) {
    return '絞り込み: $account';
  }

  @override
  String get balance => '残高:';

  @override
  String get balanceCheckMode => '残高を確認';

  @override
  String get balanceCheckExpected => '想定残高';

  @override
  String get balanceCheckStatement => 'あなたの残高';

  @override
  String get balanceCheckStatementHint => '明細書の残高を入力';

  @override
  String get balanceCheckMatch => '残高が一致しました';

  @override
  String balanceCheckDifference(String amount) {
    return '差額: $amount';
  }

  @override
  String get balanceCheckEnterBalance => '比較する残高を入力してください';

  @override
  String get balanceCheckInvalidAmount => '有効な金額を入力してください';

  @override
  String get balanceCheckSelectedBalance => '選択した残高';

  @override
  String get balanceCheckReconcile => '選択項目を照合';

  @override
  String get balanceCheckReconciled => '選択した取引を照合済みにしました';

  @override
  String get balanceCheckNothingToReconcile =>
      '照合する取引がありません。未照合の取引を選択して含めてください。';

  @override
  String get balanceCheckPaymentAccount => '支払口座';

  @override
  String get balanceCheckPaybackDate => '返済日';

  @override
  String get balanceCheckSelectPaymentAccount => '支払口座を選択';

  @override
  String get balanceCheckNoPaymentAccounts => '利用できる支払口座がありません';

  @override
  String balanceCheckPaybackSummary(
    String amount,
    String account,
    String date,
  ) {
    return '返済: $amount（$account から $date）';
  }

  @override
  String get balanceCheckPaybackReconciled => '購入を照合し、返済振替を作成しました';

  @override
  String get balanceCheckNoEligiblePurchases => 'クレジットカードの購入を1件以上選択してください';

  @override
  String get tooltipBalanceCheckMode => '明細書の残高と Firefly を比較';

  @override
  String get tooltipBalanceCheckIncludePending => '残高比較に含める';

  @override
  String get tooltipBalanceCheckExcludeReconciled => '残高比較から除外する';

  @override
  String get transactionReconciled => '照合済み';

  @override
  String get partiallyReconciled => '一部照合済み';

  @override
  String get tooltipTransactionReconciled => '銀行明細と照合済み';

  @override
  String get transactionReconciledUpdated => '照合状態を更新しました';

  @override
  String failedToUpdateReconciliation(String error) {
    return '照合の更新に失敗しました: $error';
  }

  @override
  String get reconciledFilter => '照合';

  @override
  String get reconciledFilterAll => 'すべての取引';

  @override
  String get reconciledFilterReconciled => '照合済みのみ';

  @override
  String get reconciledFilterUnreconciled => '未照合のみ';

  @override
  String get reconcile => '照合';

  @override
  String reconcileExpectedBalance(String amount) {
    return '想定残高: $amount';
  }

  @override
  String get reconcileClickHint => 'クリックして照合';

  @override
  String get reconciliationTitle => '口座を照合';

  @override
  String get reconciliationSubtitle => '明細書と Firefly III を照合';

  @override
  String get reconciliationAccount => '口座';

  @override
  String get reconciliationStartDate => '開始日';

  @override
  String get reconciliationEndDate => '終了日';

  @override
  String get reconciliationStartBalance => '期首残高';

  @override
  String get reconciliationEndBalance => '期末残高';

  @override
  String get reconciliationStart => '照合を開始';

  @override
  String get reconciliationRestart => 'やり直す';

  @override
  String get reconciliationOptions => '照合オプション';

  @override
  String get reconciliationGapZero => 'チェックした取引は明細書と一致しています。この照合を保存できます。';

  @override
  String reconciliationGapPositive(String amount) {
    return 'Firefly は明細書より $amount 少ないです。保存時に修正取引を作成できます。';
  }

  @override
  String reconciliationGapNegative(String amount) {
    return 'Firefly は明細書より $amount 多いです。保存時に修正取引を作成できます。';
  }

  @override
  String get reconciliationStore => '照合を保存';

  @override
  String get reconciliationStoreTitle => '照合を保存しますか？';

  @override
  String reconciliationStoreBody(int count) {
    return '$count 件の取引を照合済みにします。';
  }

  @override
  String get reconciliationCreateCorrectionTitle => '修正取引を作成しますか？';

  @override
  String reconciliationCreateCorrectionBody(String amount) {
    return '残りの差額は $amount です。FireRacoon が修正取引を作成します。';
  }

  @override
  String get reconciliationStored => '照合を保存しました';

  @override
  String reconciliationStoreFailed(String error) {
    return '照合の保存に失敗しました: $error';
  }

  @override
  String get reconciliationSelectAccount => '照合する資産口座を選択';

  @override
  String get reconciliationInvalidBalances => '有効な期首・期末残高を入力してください';

  @override
  String get reconciliationInvalidDateRange => '終了日は開始日以降である必要があります';

  @override
  String get reconciliationSelectTransactions => '明細書から少なくとも 1 件の取引をチェックしてください';

  @override
  String get reconciliationNoTransactions => 'この期間の取引はありません';

  @override
  String get reconciliationUnreconciled => '未照合';

  @override
  String get reconciliationFutureTransaction => '期間終了後';

  @override
  String get futureTransactions => '将来の取引';

  @override
  String get reconciliationOpenWizard => '口座を照合';

  @override
  String get tooltipReconciliationWizard => '銀行明細と取引を照合';

  @override
  String get reconciliationUseFireflyBalances => 'Firefly の残高を使用';

  @override
  String get reconciliationLoadingBalances => 'Firefly から残高を読み込み中…';

  @override
  String get reconciliationBalancesFilled => 'Firefly から残高を入力しました';

  @override
  String reconciliationBalancesFailed(String error) {
    return '残高を読み込めませんでした: $error';
  }

  @override
  String get notAvailable => 'N/A';

  @override
  String get groupBy => 'グループ化';

  @override
  String get groupByDate => '日付でグループ化';

  @override
  String get groupByAccount => '口座でグループ化';

  @override
  String get groupByPayee => '支払先でグループ化';

  @override
  String get groupByType => '種類でグループ化';

  @override
  String get groupByCategory => 'カテゴリでグループ化';

  @override
  String get filterAccount => '口座で絞り込み';

  @override
  String get amount => '金額';

  @override
  String get accounts => '口座';

  @override
  String get description => '説明';

  @override
  String get sourceAccount => '送金元口座';

  @override
  String get destinationAccount => '送金先口座';

  @override
  String get payee => '支払先';

  @override
  String get savingNotSupported => '読み取り専用モードでは保存できません。';

  @override
  String transactionDateCategory(String category, String date) {
    return '$category · $date';
  }

  @override
  String foreignAmount(String amount) {
    return '($amount)';
  }

  @override
  String get budgetsTitle => '予算';

  @override
  String get subscriptionsTitle => 'サブスクリプションと定期取引';

  @override
  String get newSubscription => '新しいサブスクリプション';

  @override
  String get createSubscription => 'サブスクリプションを作成';

  @override
  String get editSubscription => 'サブスクリプションを編集';

  @override
  String get subscriptionCreated => 'サブスクリプションを作成しました。';

  @override
  String subscriptionDeleted(String name) {
    return 'サブスクリプション「$name」を削除しました。';
  }

  @override
  String failedToCreateSubscription(String error) {
    return 'サブスクリプションの作成に失敗しました: $error';
  }

  @override
  String failedToUpdateSubscription(String error) {
    return 'サブスクリプションの更新に失敗しました: $error';
  }

  @override
  String failedToDeleteSubscription(String error) {
    return 'サブスクリプションの削除に失敗しました: $error';
  }

  @override
  String get deleteSubscription => 'サブスクリプションを削除';

  @override
  String deleteSubscriptionConfirmBody(String name) {
    return 'サブスクリプション「$name」を削除してもよろしいですか？この操作は元に戻せません。';
  }

  @override
  String get noSubscriptionsFound => 'サブスクリプションが見つかりません。';

  @override
  String get subscriptionInactive => '無効';

  @override
  String get subscriptionActive => '有効';

  @override
  String get mandatoryFields => '必須項目';

  @override
  String get optionalFields => '任意項目';

  @override
  String get minimumAmount => '最小金額';

  @override
  String get maximumAmount => '最大金額';

  @override
  String get startDate => '開始日';

  @override
  String get repeats => '繰り返し';

  @override
  String get skip => 'スキップ';

  @override
  String get skipHelp => 'スキップを使って隔月（スキップ = 1）などの間隔を設定できます。';

  @override
  String get endDate => '終了日';

  @override
  String get endDateHelp => '任意。この日付でサブスクリプションが終了する予定です。';

  @override
  String get extensionDate => '延長日';

  @override
  String get extensionDateHelp => '任意。この日付までに延長（または解約）が必要です。';

  @override
  String get group => 'グループ';

  @override
  String get notesMarkdownHint => 'このフィールドは Markdown に対応しています。';

  @override
  String get repeatWeekly => '毎週';

  @override
  String get repeatMonthly => '毎月';

  @override
  String get repeatQuarterly => '四半期ごと';

  @override
  String get repeatHalfYear => '半年ごと';

  @override
  String get repeatYearly => '毎年';

  @override
  String subscriptionAmountRange(String min, String max) {
    return '$min – $max';
  }

  @override
  String get tabSubscriptions => 'サブスクリプション';

  @override
  String get tabRecurringTransactions => '定期取引';

  @override
  String get badgeSubscription => 'サブスクリプション';

  @override
  String get badgeRecurringTransaction => '定期取引';

  @override
  String get addSubscription => 'サブスクリプション';

  @override
  String get addRecurringTransaction => '定期';

  @override
  String get noSubscriptionsOrRecurrencesFound => 'サブスクリプションまたは定期取引が見つかりません。';

  @override
  String get newRecurringTransaction => '新しい定期取引';

  @override
  String get createRecurringTransaction => '定期取引を作成';

  @override
  String get editRecurringTransaction => '定期取引を編集';

  @override
  String get recurringTransactionCreated => '定期取引を作成しました。';

  @override
  String recurringTransactionDeleted(String name) {
    return '定期取引「$name」を削除しました。';
  }

  @override
  String failedToCreateRecurringTransaction(String error) {
    return '定期取引の作成に失敗しました: $error';
  }

  @override
  String failedToUpdateRecurringTransaction(String error) {
    return '定期取引の更新に失敗しました: $error';
  }

  @override
  String failedToDeleteRecurringTransaction(String error) {
    return '定期取引の削除に失敗しました: $error';
  }

  @override
  String get deleteRecurringTransaction => '定期取引を削除';

  @override
  String deleteRecurringTransactionConfirmBody(String name) {
    return '定期取引「$name」を削除してもよろしいですか？この操作は元に戻せません。';
  }

  @override
  String get noRecurringTransactionsFound => '定期取引が見つかりません。';

  @override
  String get recurringTransactionInactive => '無効';

  @override
  String get mandatoryRecurrenceFields => '必須の繰り返し情報';

  @override
  String get optionalRecurrenceFields => '任意の繰り返し情報';

  @override
  String get mandatoryTransactionFields => '必須の取引情報';

  @override
  String get optionalTransactionFields => '任意の取引情報';

  @override
  String get recurrenceTitle => 'タイトル';

  @override
  String get firstDate => '最初の日付';

  @override
  String get firstDateHelp => '最初の繰り返し予定日を指定します。未来の日付である必要があります。';

  @override
  String get typeOfRepetition => '繰り返しの種類';

  @override
  String get typeOfRepetitionHelp => '最初の日付を変更すると、より多くのオプションが表示されます。';

  @override
  String get weekendHandling => '週末';

  @override
  String get weekendCreateAnyway => 'そのまま取引を作成';

  @override
  String get weekendSkip => '取引を作成しない';

  @override
  String get weekendPreviousFriday => '前の金曜日にずらす';

  @override
  String get weekendNextMonday => '次の月曜日にずらす';

  @override
  String get weekendHelp => '定期取引が土曜日または日曜日に当たる場合、Firefly III はどうしますか？';

  @override
  String get repetitionEnds => '繰り返しの終了';

  @override
  String get repeatForever => '無期限に繰り返す';

  @override
  String get repeatUntilDate => '日付まで繰り返す';

  @override
  String get repeatCount => '固定回数繰り返す';

  @override
  String get numberOfRepetitions => '繰り返し回数';

  @override
  String get applyRules => 'ルールを適用';

  @override
  String get applyRulesHelp => '各取引作成後にルールを実行するかどうか。';

  @override
  String get recurrenceDescription => '定期取引の説明';

  @override
  String get repeatDaily => '毎日';

  @override
  String get repeatNdom => '毎月第 n 曜日';

  @override
  String recurrenceAmount(String amount) {
    return '$amount';
  }

  @override
  String get tooltipOpenSubscriptions => 'サブスクリプションと定期取引を開く。';

  @override
  String get subscriptionsTitleRacoon => '定期レイドとスケジュール';

  @override
  String get newSubscriptionRacoon => '新しい定期レイド';

  @override
  String get piggyBanksTitle => '貯金箱';

  @override
  String get newPiggyBank => '新しい貯金箱';

  @override
  String get createPiggyBank => '貯金箱を作成';

  @override
  String get editPiggyBank => '貯金箱を編集';

  @override
  String get piggyBankCreated => '貯金箱を作成しました。';

  @override
  String piggyBankDeleted(String name) {
    return '貯金箱「$name」を削除しました。';
  }

  @override
  String failedToCreatePiggyBank(String error) {
    return '貯金箱の作成に失敗しました: $error';
  }

  @override
  String failedToUpdatePiggyBank(String error) {
    return '貯金箱の更新に失敗しました: $error';
  }

  @override
  String failedToDeletePiggyBank(String error) {
    return '貯金箱の削除に失敗しました: $error';
  }

  @override
  String get deletePiggyBank => '貯金箱を削除';

  @override
  String deletePiggyBankConfirmBody(String name) {
    return '貯金箱「$name」を削除してもよろしいですか？この操作は元に戻せません。';
  }

  @override
  String get noPiggyBanksFound => '貯金箱が見つかりません。';

  @override
  String get targetAmount => '目標金額';

  @override
  String get piggyBankCurrencyHelp => '貯金箱は 1 つの通貨でのみ貯蓄できます。';

  @override
  String get saveOnAccounts => '貯蓄する口座';

  @override
  String get piggyBankAccountsHelp => '先に選択した通貨を使用する口座のみ受け付けられます。';

  @override
  String get targetDate => '目標日';

  @override
  String get targetDateHelp => '貯蓄を完了する予定日。';

  @override
  String get accountGroupDefaultAssets => 'デフォルトの資産口座';

  @override
  String get accountGroupSavings => '普通預金口座';

  @override
  String get accountGroupCash => '現金ウォレット';

  @override
  String get accountGroupLiabilities => '負債';

  @override
  String get selectAtLeastOneAccount => '少なくとも 1 つの口座を選択してください。';

  @override
  String piggyBankProgress(String current, String target) {
    return '$current / $target';
  }

  @override
  String get piggyBanksTitleRacoon => 'ミニ隠し場所';

  @override
  String get newPiggyBankRacoon => '新しいミニ隠し場所';

  @override
  String get newBudget => '新しい予算';

  @override
  String get deleteBudget => '予算を削除';

  @override
  String deleteBudgetMessage(String name) {
    return '「$name」を削除してもよろしいですか？';
  }

  @override
  String budgetDeleted(String name) {
    return '予算「$name」を削除しました。';
  }

  @override
  String failedToDeleteBudget(String error) {
    return '予算の削除に失敗しました: $error';
  }

  @override
  String get spent => '使用済み';

  @override
  String ofAmount(String amount) {
    return '$amount 中';
  }

  @override
  String overBudget(String amount) {
    return '予算超過 $amount';
  }

  @override
  String leftInBudget(String amount) {
    return '残り $amount';
  }

  @override
  String budgetPerPeriod(String amount, String period) {
    return '$period あたり $amount';
  }

  @override
  String budgetLimitForPeriod(String amount, String period) {
    return '$period で $amount';
  }

  @override
  String get budgetCadenceDaily => '日';

  @override
  String get budgetCadenceWeekly => '週';

  @override
  String get budgetCadenceMonthly => '月';

  @override
  String get budgetCadenceQuarterly => '四半期';

  @override
  String get budgetCadenceHalfYear => '半年';

  @override
  String get budgetCadenceYearly => '年';

  @override
  String get viewPeriod => '表示期間';

  @override
  String get budgetAmount => '予算額';

  @override
  String get editBudget => '予算を編集';

  @override
  String get createBudget => '予算を作成';

  @override
  String get createPayee => '支払先を作成';

  @override
  String get createCategory => 'カテゴリを作成';

  @override
  String get budgetLimit => '予算上限';

  @override
  String get autoBudget => '自動予算額';

  @override
  String get budgetAmountMode => '上限の種類';

  @override
  String get budgetAmountModeAuto => '繰り返し期間';

  @override
  String get budgetAmountModeDateRange => '固定日付範囲';

  @override
  String get budgetAmountModeNone => '金額なし';

  @override
  String get budgetRepeatPeriod => '繰り返し間隔';

  @override
  String get budgetAutoType => '自動予算の動作';

  @override
  String get budgetAutoTypeReset => '各期間でリセット';

  @override
  String get budgetAutoTypeRollover => '未使用分を繰り越し';

  @override
  String get budgetAutoTypeAdjusted => '支出に合わせて調整';

  @override
  String get budgetAutoTypeNone => 'なし';

  @override
  String get budgetActive => '有効';

  @override
  String get budgetPeriodDaily => '毎日';

  @override
  String get budgetPeriodWeekly => '毎週';

  @override
  String get budgetPeriodMonthly => '毎月';

  @override
  String get budgetPeriodQuarterly => '四半期ごと';

  @override
  String get budgetPeriodHalfYear => '半年ごと';

  @override
  String get budgetPeriodYearly => '毎年';

  @override
  String get tooltipBudgetAmountMode => '繰り返し自動予算、固定日付範囲、上限なしから選択';

  @override
  String get tooltipBudgetRepeatPeriod => '予算額が適用される頻度（例: 毎月）';

  @override
  String get tooltipBudgetAutoType => '各予算期間の開始時に何が起こるか';

  @override
  String get tooltipBudgetStartDate => 'この予算上限が適用される最初の日';

  @override
  String get tooltipBudgetEndDate => 'この予算上限が適用される最後の日';

  @override
  String get tooltipBudgetActive => '無効な予算は Firefly のデフォルト表示から非表示になります';

  @override
  String get tooltipBudgetNotes => '予算と一緒に保存されるメモ';

  @override
  String get tooltipBudgetCurrency => '予算額の通貨';

  @override
  String get expensesTitle => '支出';

  @override
  String get clearFilters => 'フィルターをクリア';

  @override
  String get overview => '概要';

  @override
  String get byCategory => 'カテゴリ別';

  @override
  String get allCategories => 'すべてのカテゴリ';

  @override
  String get allTypes => 'すべての種類';

  @override
  String get expensesFilter => '支出';

  @override
  String get transfers => '振替';

  @override
  String get expensePeriodWeek => '今週';

  @override
  String get expensePeriodMonth => '今月';

  @override
  String get expensePeriodQuarter => '今四半期';

  @override
  String get expensePeriodSemester => '今半期';

  @override
  String get expensePeriodYear => '今年';

  @override
  String get expensePeriodAll => '全期間';

  @override
  String get dashboardPeriodThisWeek => '今週';

  @override
  String get dashboardPeriodLastWeek => '先週';

  @override
  String get dashboardPeriodThisMonth => '今月';

  @override
  String get dashboardPeriodLastMonth => '先月';

  @override
  String get dashboardPeriodThisQuarter => '今四半期';

  @override
  String get dashboardPeriodLastQuarter => '前四半期';

  @override
  String get dashboardPeriodThisYear => '今年';

  @override
  String get dashboardPeriodLastYear => '昨年';

  @override
  String get dashboardPeriodLast2Years => '過去 2 年';

  @override
  String get dashboardPeriodLast5Years => '過去 5 年';

  @override
  String get dashboardPeriodLast10Years => '過去 10 年';

  @override
  String get dashboardPeriodAll => 'すべて';

  @override
  String get deltaComparisonPreviousWeek => '前週';

  @override
  String get deltaComparisonPreviousMonth => '前月';

  @override
  String get deltaComparisonPreviousQuarter => '前四半期';

  @override
  String get deltaComparisonPreviousYear => '前年';

  @override
  String get deltaComparisonPrevious2Years => '過去 2 年';

  @override
  String get deltaComparisonPrevious5Years => '過去 5 年';

  @override
  String get deltaComparisonPrevious10Years => '過去 10 年';

  @override
  String get deltaComparisonCustomPeriod => '前期間';

  @override
  String noChangeVsComparisonPeriod(String period) {
    return '$period と変化なし';
  }

  @override
  String newActivityVsComparisonPeriod(String period) {
    return '$period と比べて新しいアクティビティ';
  }

  @override
  String percentVsComparisonPeriod(
    String arrow,
    String percent,
    String period,
  ) {
    return '$arrow$percent% $period比';
  }

  @override
  String get dateRangeSeparator => '–';

  @override
  String get dateEllipsis => '…';

  @override
  String get projectionTitle => '予測';

  @override
  String get projectedBalance => '予測残高';

  @override
  String get visualization => '可視化';

  @override
  String get parameters => 'パラメーター';

  @override
  String predictedBalances(String period) {
    return '予測残高 · $period';
  }

  @override
  String get noAccountsLoaded => '口座が読み込まれていません';

  @override
  String get scenarioSummary => 'シナリオ概要';

  @override
  String nowAmount(String amount) {
    return '現在 $amount';
  }

  @override
  String get worstCase => '最悪ケース';

  @override
  String get expected => '予想';

  @override
  String get bestCase => '最良ケース';

  @override
  String get moveSliderToSeeImpact => 'スライダーを動かして影響を確認';

  @override
  String whatIfImpact(String amount, String period) {
    return '$period で +$amount';
  }

  @override
  String get projectionPeriod3Months => '3 か月';

  @override
  String get projectionPeriod6Months => '6 か月';

  @override
  String get projectionPeriod1Year => '1 年';

  @override
  String get projectionPeriod3Years => '3 年';

  @override
  String get projectionTypeSavings => '貯蓄率';

  @override
  String get projectionTypeCompound => '複利成長';

  @override
  String get projectionTypePortfolio => 'ポートフォリオ（変動あり）';

  @override
  String get projectionTypeCashflow => 'キャッシュフロー';

  @override
  String get projectionTypeSavingsDesc => '過去の純貯蓄からの線形予測';

  @override
  String get projectionTypeCompoundDesc => '複利と拠出による残高の成長';

  @override
  String get projectionTypePortfolioDesc => 'ボラティリティに基づく最悪/最良の予想リターン';

  @override
  String get projectionTypeCashflowDesc => '収入から支出を引いた自由調整';

  @override
  String get chartStyleFan => 'ファンチャート';

  @override
  String get chartStyleLines => '3 本線';

  @override
  String get chartStyleScenarios => 'シナリオカード';

  @override
  String get whatIfSpending => '仮想支出';

  @override
  String get annualReturn => '年間リターン';

  @override
  String get volatility => 'ボラティリティ';

  @override
  String projectionAlertLiability(String name, String balance) {
    return '最悪ケースでは、$name が予想より早く $balance に達する可能性があります。';
  }

  @override
  String get projectionAlertBelowZero => '最悪ケースの予測が選択期間内にゼロを下回ります。';

  @override
  String get projectionAlertActionLiability => '普通預金口座から資金を移すことを検討してください。';

  @override
  String get projectionAlertActionSpending => '自由支出を見直すか、貯蓄を増やしてください。';

  @override
  String get confirmTypeWord => '確認のため';

  @override
  String get confirmToConfirm => ' と入力:';

  @override
  String get confirmHint => '上の単語を入力…';

  @override
  String currencyPair(String name, String symbol) {
    return '$name ($symbol)';
  }

  @override
  String budgetSpentFraction(String spent, String total) {
    return '$spent / $total';
  }

  @override
  String get editAccount => '口座を編集';

  @override
  String get editAction => '編集';

  @override
  String get filterAllShort => 'すべて';

  @override
  String get filterAssetsShort => '資産';

  @override
  String get filterLiabilitiesShort => '負債';

  @override
  String get showInactiveAccounts => '無効な口座を表示';

  @override
  String get showInactiveAccountsShort => '無効';

  @override
  String get accountInactive => '無効';

  @override
  String get unknown => '不明';

  @override
  String showingTransactionsOfTotal(int loaded, int total) {
    return '$total 件中 $loaded 件を表示';
  }

  @override
  String transactionsCount(int count) {
    return '$count 件の取引';
  }

  @override
  String get oneTransaction => '1 件の取引';

  @override
  String deleteBudgetConfirmBody(String name) {
    return '予算「$name」を削除してもよろしいですか？この操作は元に戻せません。';
  }

  @override
  String get scrollForMore => 'スクロールして続きを表示…';

  @override
  String get noTransactionsMatchFilters => '現在のフィルターに一致する取引はありません。';

  @override
  String get category => 'カテゴリ';

  @override
  String get totalSpentPeriod => 'この期間の支出合計';

  @override
  String get totalIncomePeriod => 'この期間の収入合計';

  @override
  String get totalTransferredPeriod => 'この期間の振替合計';

  @override
  String get totalPeriod => 'この期間の合計';

  @override
  String get volatilityUncertainty => 'ボラティリティ / 不確実性';

  @override
  String get editTransaction => '取引を編集';

  @override
  String get newDeposit => '入金を作成';

  @override
  String get editDeposit => '入金を編集';

  @override
  String get newWithdrawal => '出金を作成';

  @override
  String get editWithdrawal => '出金を編集';

  @override
  String get newTransfer => '振替を作成';

  @override
  String get editTransfer => '振替を編集';

  @override
  String get revenueAccount => '収入口座';

  @override
  String get assetAccount => '資産口座';

  @override
  String get expenseAccount => '支出口座';

  @override
  String get expenseLabel => '支出';

  @override
  String get transactionTypeDeposit => '入金';

  @override
  String get transactionTypeWithdrawal => '出金';

  @override
  String get transactionTypeTransfer => '振替';

  @override
  String get dataAndLoading => 'データと読み込み';

  @override
  String get transactionPageSize => '1 ページあたりの取引数';

  @override
  String get transactionPageSizeDescription => 'スクロールするたびに読み込む取引数。取引一覧に適用されます。';

  @override
  String transactionPageSizeValue(int count) {
    return '1 ページ $count 件';
  }

  @override
  String get defaultPeriod => 'デフォルト期間';

  @override
  String get defaultPeriodDescription => 'ダッシュボード、支出、収入、振替、取引を開いたときに適用されます。';

  @override
  String get customDateRange => 'カスタム範囲';

  @override
  String get pickDates => '日付を選択';

  @override
  String get budgetStatusOnTrack => '順調';

  @override
  String get budgetStatusOver => '予算超過';

  @override
  String whatIfCutSpending(int percent) {
    return '自由支出を $percent% 削減したら？';
  }

  @override
  String get usesAveragePatterns => '取引から算出した平均的な収入・支出パターンを使用します。';

  @override
  String get historicalNetSavingsNote => '過去の純貯蓄に基づきます。不確実性を調整して帯の幅を変更できます。';

  @override
  String get accountFilterLabel => '口座';

  @override
  String get noTransactionsForBudget => 'この予算の取引はありません。';

  @override
  String get noTransactionsForAccount => 'この口座の取引はありません。';

  @override
  String get deleteAccount => '口座を削除';

  @override
  String deleteAccountConfirmBody(String name) {
    return '口座「$name」を削除してもよろしいですか？この操作は元に戻せません。';
  }

  @override
  String accountDeleted(String name) {
    return '口座「$name」を削除しました。';
  }

  @override
  String failedToDeleteAccount(String error) {
    return '口座の削除に失敗しました: $error';
  }

  @override
  String get budgetNameHint => '予算名';

  @override
  String budgetAmountWithSymbol(String symbol) {
    return '予算額（$symbol）';
  }

  @override
  String get chartLegendActual => '実績';

  @override
  String get chartLegendWorst => '最悪';

  @override
  String get chartLegendBest => '最良';

  @override
  String get chartLegendWorstBest => '最悪 ↔ 最良';

  @override
  String get today => '今日';

  @override
  String get mcpServer => 'MCP サーバー';

  @override
  String mcpStatusFailed(String error) {
    return '失敗: $error';
  }

  @override
  String mcpStatusRunning(int port) {
    return 'ポート $port で実行中';
  }

  @override
  String get mcpStatusStarting => '起動中…';

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
  String get transactionDate => '日付';

  @override
  String get moreOptions => 'その他';

  @override
  String get foreignAmountLabel => '外貨金額';

  @override
  String get budgetLabel => '予算';

  @override
  String get piggyBank => '貯金箱';

  @override
  String get noPiggyBank => '（貯金箱なし）';

  @override
  String get tags => 'タグ';

  @override
  String get subscription => 'サブスクリプション';

  @override
  String get interestDate => '利息日';

  @override
  String get attachments => '添付ファイル';

  @override
  String get notes => 'メモ';

  @override
  String get none => '（なし）';

  @override
  String get attachmentsNotSupported => 'このアプリでは添付ファイルはまだサポートされていません。';

  @override
  String get deleteTransaction => '取引を削除';

  @override
  String deleteTransactionConfirmBody(String description) {
    return '「$description」を削除してもよろしいですか？この操作は元に戻せません。';
  }

  @override
  String get transactionDeleted => '取引を削除しました。';

  @override
  String failedToDeleteTransaction(String error) {
    return '取引の削除に失敗しました: $error';
  }

  @override
  String get transactionSaved => '取引を保存しました。';

  @override
  String failedToSaveTransaction(String error) {
    return '取引の保存に失敗しました: $error';
  }

  @override
  String get transactionDuplicated => '取引を複製しました。';

  @override
  String failedToDuplicateTransaction(String error) {
    return '取引の複製に失敗しました: $error';
  }

  @override
  String get duplicate => '複製';

  @override
  String get newTransaction => '新しい取引';

  @override
  String get transactionCreated => '取引を作成しました。';

  @override
  String failedToCreateTransaction(String error) {
    return '取引の作成に失敗しました: $error';
  }

  @override
  String get transactionFormIncomplete => '説明、金額、両方の口座を入力してください。';

  @override
  String get transactionInformation => '取引情報';

  @override
  String get addAnotherSplit => '分割を追加';

  @override
  String splitLabel(int number) {
    return '分割 $number';
  }

  @override
  String get removeSplit => '分割を削除';

  @override
  String splitCount(int count) {
    return '$count 件の分割';
  }

  @override
  String splitCategoriesCount(int count) {
    return '$count カテゴリ';
  }

  @override
  String get splitMainAmount => '合計金額';

  @override
  String get tooltipSplitMainAmount => '取引の合計金額。保存前に分割金額の合計がこれに一致する必要があります。';

  @override
  String splitTotalLabel(String amount) {
    return '分割合計: $amount';
  }

  @override
  String splitRemainder(String amount) {
    return '残り: $amount';
  }

  @override
  String splitsTotalMismatch(String expected) {
    return '分割金額の合計は $expected である必要があります。';
  }

  @override
  String get splitOptionalFields => '任意項目';

  @override
  String get foreignCurrency => '外貨';

  @override
  String get noSubscriptionsHint =>
      'サブスクリプションはまだありません。サブスクリプションページで作成して、定期支出をリンクしてください。';

  @override
  String get incomeTitle => '収入';

  @override
  String get transfersTitle => '振替';

  @override
  String get newTransferAction => '新しい振替';

  @override
  String get liabilitiesTitle => '負債';

  @override
  String get newIncome => '新しい収入';

  @override
  String get newIncomeRacoon => '新しいゲット';

  @override
  String get create => '作成';

  @override
  String get accountCreated => '口座を作成しました。';

  @override
  String get liabilityCreated => '負債を作成しました。';

  @override
  String get budgetCreated => '予算を作成しました。';

  @override
  String failedToCreateAccount(String error) {
    return '口座の作成に失敗しました: $error';
  }

  @override
  String failedToCreateBudget(String error) {
    return '予算の作成に失敗しました: $error';
  }

  @override
  String get noLiabilitiesFound => '負債が見つかりません。';

  @override
  String get liabilityType => '負債の種類';

  @override
  String get liabilityTypeDebt => '借金';

  @override
  String get liabilityTypeLoan => 'ローン';

  @override
  String get liabilityTypeMortgage => '住宅ローン';

  @override
  String get liabilityDirection => '負債の方向';

  @override
  String get liabilityDirectionOwe => '自分が誰かに借りている';

  @override
  String get liabilityDirectionOwed => '誰かが自分に借りている';

  @override
  String get amountOwed => '借入額';

  @override
  String get debtStartDate => '借入開始日';

  @override
  String get interestRate => '金利';

  @override
  String get interestPeriod => '金利期間';

  @override
  String get interestPeriodDaily => '1 日あたり';

  @override
  String get includeInNetWorth => '純資産に含める';

  @override
  String get accountNumber => '口座番号';

  @override
  String get iban => 'IBAN';

  @override
  String get bic => 'BIC';

  @override
  String get liabilityCurrencyHelp => 'この負債口座のデフォルト通貨。';

  @override
  String get interestPeriodHelp => '表示のみ — Firefly III は金利を自動計算しません。';

  @override
  String failedToCreateLiability(String error) {
    return '負債の作成に失敗しました: $error';
  }

  @override
  String get navIncomeRacoon => 'ゲット';

  @override
  String get navTransfersRacoon => '隠し場所の移動';

  @override
  String get navLiabilitiesRacoon => '借金';

  @override
  String get incomeTitleRacoon => 'ゲットした資金';

  @override
  String get transfersTitleRacoon => '隠し場所の移動';

  @override
  String get newTransferActionRacoon => '新しい隠し場所の移動';

  @override
  String get liabilitiesTitleRacoon => '借金一覧';

  @override
  String tooltipOpenSection(String section) {
    return '$section を開く。';
  }

  @override
  String get tooltipOpenDashboard => '主要 KPI のダッシュボードを開く。';

  @override
  String get tooltipOpenAccounts => '口座と残高を開く。';

  @override
  String get tooltipOpenTransactions => 'すべての取引とフィルターを開く。';

  @override
  String get tooltipOpenBudgets => '予算と支出の進捗を開く。';

  @override
  String get tooltipOpenPiggyBanks => '貯蓄目標と貯金箱を開く。';

  @override
  String get tooltipOpenExpenses => '支出分析と内訳を開く。';

  @override
  String get tooltipOpenIncome => '収入分析とトレンドを開く。';

  @override
  String get tooltipOpenTransfers => '振替分析と履歴を開く。';

  @override
  String get tooltipOpenLiabilities => '負債と借金の概要を開く。';

  @override
  String get tooltipOpenProjection => '予測シナリオと見通しを開く。';

  @override
  String get tooltipOpenPrognosis => '月末の口座残高見通しを開く。';

  @override
  String get projectionTabLongTerm => '長期予測';

  @override
  String get tooltipOpenSettings => 'アプリ設定と Firefly 接続を開く。';

  @override
  String get tooltipToggleSidebar => 'サイドバーを展開または折りたたむ。';

  @override
  String get tooltipSearchTransactions => '現在のページでテキスト検索。';

  @override
  String get tooltipToggleViewMode => 'リスト表示とグリッド表示を切り替える。';

  @override
  String get refreshFromFirefly => '更新';

  @override
  String get tooltipRefreshFromFirefly => 'Firefly III からデータを再取得';

  @override
  String get viewModeCards => 'カード';

  @override
  String get viewModeRows => '行';

  @override
  String get viewModeTightRows => 'タイト行';

  @override
  String get columnSelection => '列の選択';

  @override
  String get columnDate => '日付';

  @override
  String get columnAccount => '口座';

  @override
  String get columnType => '種別';

  @override
  String get columnPayee => '支払先';

  @override
  String get columnDescription => 'メモ';

  @override
  String get columnCategory => 'カテゴリ';

  @override
  String get columnBudget => '予算';

  @override
  String get columnAmount => '金額';

  @override
  String get columnReconciled => '照合済み';

  @override
  String get columnBalance => '残高';

  @override
  String get tooltipTransactionType => '取引の種類を選択。';

  @override
  String get tooltipFieldDescription => 'この取引で何が起きたか。';

  @override
  String get tooltipFieldSourceAccount => 'お金の送り元口座。';

  @override
  String get tooltipFieldDestinationAccount => 'お金の送り先口座。';

  @override
  String get tooltipFieldDate => '取引の日付と時刻。';

  @override
  String get tooltipFieldAmount => '選択した通貨での主な金額。';

  @override
  String get tooltipFieldCurrency => 'この分割の主通貨。';

  @override
  String get tooltipFieldForeignAmount => '別通貨での任意金額。';

  @override
  String get tooltipFieldForeignCurrency => '外貨金額に使用する通貨。';

  @override
  String get tooltipFieldBudget => 'この分割を予算に割り当てる。';

  @override
  String get tooltipFieldCategory => 'レポートとフィルター用のカテゴリ。';

  @override
  String get tooltipFieldPiggyBank => 'この分割を貯金箱にリンク。';

  @override
  String get tooltipFieldTags => 'クイックフィルター用のカンマ区切りタグ。';

  @override
  String get tooltipFieldSubscription => 'この分割をサブスクリプションにリンク。';

  @override
  String get tooltipFieldInterestDate => '任意の利息日または記帳日。';

  @override
  String get tooltipFieldAttachments => '添付ファイルは表示されますが、まだアップロードできません。';

  @override
  String get tooltipFieldNotes => '将来の参照用の追加詳細。';

  @override
  String get tooltipAddSplit => 'この取引に分割を追加。';

  @override
  String get tooltipRemoveSplit => 'この分割行を削除。';

  @override
  String get tooltipCancelTransaction => '変更を破棄して閉じる。';

  @override
  String get tooltipSaveTransaction => 'この取引を保存。';

  @override
  String get tooltipCancel => '変更を破棄して保存せずに閉じる。';

  @override
  String get tooltipSave => '変更を保存。';

  @override
  String get tooltipCreate => '新しい項目を作成。';

  @override
  String get tooltipConfirmDelete => 'この項目を完全に削除。';

  @override
  String get tooltipConfirmChallenge => '削除を確認するためにチャレンジワードを入力。';

  @override
  String get tooltipExpandDetails => '詳細を表示。';

  @override
  String get tooltipCollapseDetails => '追加詳細を非表示。';

  @override
  String get tooltipClearDate => '選択した日付を削除。';

  @override
  String get tooltipAccountName => '一覧とレポートに表示される名前。';

  @override
  String get tooltipAccountCurrentBalance => '本日時点の Firefly からの現在残高。';

  @override
  String get tooltipAccountEndOfMonthBalance =>
      '選択した日付の予測残高（予定取引、繰り返し取引、請求書を含む）。';

  @override
  String get tooltipBalanceDatePick => '別の日付の残高を表示';

  @override
  String get tooltipBalanceDateReset => '今月末に戻す';

  @override
  String get tooltipBalanceBeyondForecast => '予測はこの日付まで届いていないため、これは最後の予測値です。';

  @override
  String get tooltipRecordedBalance => 'この日付までに台帳が保持している残高（先付けされた取引を含む）。';

  @override
  String get tooltipBudgetName => 'この支出予算の名前。';

  @override
  String get tooltipBudgetAmount => 'この予算期間の上限額。';

  @override
  String get tooltipSubscriptionName => '定期請求またはサブスクリプションの名前。';

  @override
  String get tooltipSubscriptionCurrency => '予想金額に使用する通貨。';

  @override
  String get tooltipSubscriptionAmountMin => '期間あたりの最低予想請求額。';

  @override
  String get tooltipSubscriptionAmountMax => '期間あたりの最高予想請求額。';

  @override
  String get tooltipSubscriptionStartDate => 'サブスクリプションの開始日または最初の記録日。';

  @override
  String get tooltipSubscriptionRepeats => 'このサブスクリプションの繰り返し頻度。';

  @override
  String get tooltipSubscriptionSkip => '次回請求までにスキップする回数。';

  @override
  String get tooltipSubscriptionEndDate => 'このサブスクリプションが終了する任意の日付。';

  @override
  String get tooltipSubscriptionExtensionDate => '請求を延長または一時停止する任意の日付。';

  @override
  String get tooltipSubscriptionGroup => 'サブスクリプション整理用の任意グループラベル。';

  @override
  String get tooltipSubscriptionActive => 'このサブスクリプションが現在有効かどうか。';

  @override
  String get tooltipPiggyBankName => 'この貯蓄目標の名前。';

  @override
  String get tooltipPiggyBankTargetAmount => '合計で貯めたい金額。';

  @override
  String get tooltipPiggyBankCurrency => '目標と追跡貯蓄の通貨。';

  @override
  String get tooltipPiggyBankAccounts => 'この目標にカウントする口座の残高。';

  @override
  String tooltipPiggyBankAccount(String name) {
    return 'この貯金箱に $name を含める。';
  }

  @override
  String get tooltipPiggyBankStartDate => 'この目標の追跡を開始した日。';

  @override
  String get tooltipPiggyBankTargetDate => '目標達成の任意の期限。';

  @override
  String get tooltipPiggyBankGroup => '貯金箱整理用の任意グループラベル。';

  @override
  String get tooltipThemeLight => 'ライトカラースキームを使用。';

  @override
  String get tooltipThemeDark => 'ダークカラースキームを使用。';

  @override
  String get tooltipThemePaletteClassic => 'Firefly 風のクラシックパレット。';

  @override
  String get tooltipThemePaletteSpectrum => '鮮やかな多色カテゴリパレット。';

  @override
  String get tooltipThemePaletteRaccoon => '遊び心のあるアライグマテーマパレット。';

  @override
  String get tooltipThemeAccent => 'ボタン、リンク、ハイライトのアクセントカラー。';

  @override
  String tooltipThemeAccentOption(String name) {
    return '$name をアクセントカラーとして使用。';
  }

  @override
  String get tooltipThemeDone => '閉じて選択したテーマを保持。';

  @override
  String get repeatIntervalLabel => '間隔';

  @override
  String get repeatIntervalHelp => '繰り返しの頻度（例: 3 か月ごと）。';

  @override
  String repeatEveryNDays(int count) {
    return '$count 日ごと';
  }

  @override
  String repeatEveryNWeeks(int count) {
    return '$count 週ごと';
  }

  @override
  String repeatEveryNMonths(int count) {
    return '$count か月ごと';
  }

  @override
  String repeatEveryNYears(int count) {
    return '$count 年ごと';
  }

  @override
  String get writeAheadDays => '定期取引を事前に作成';

  @override
  String get writeAheadDaysDescription => '今後の定期取引をこの日数分先に作成します。';

  @override
  String get writeAheadOff => 'オフ';

  @override
  String writeAheadNDays(int count) {
    return '$count 日';
  }

  @override
  String get plannedLabel => '予定';

  @override
  String get navHistory => '履歴';

  @override
  String get navHistoryRacoon => '作戦リプレイ';

  @override
  String get tooltipOpenHistory => '元に戻す/やり直し履歴を開く。';

  @override
  String get tooltipUndo => '最後の操作を元に戻す。';

  @override
  String get tooltipRedo => '最後に元に戻した操作をやり直す。';

  @override
  String get undo => '元に戻す';

  @override
  String get redo => 'やり直す';

  @override
  String get clear => 'クリア';

  @override
  String get advanced => '詳細';

  @override
  String get undoHistorySize => '元に戻す/やり直し履歴のサイズ';

  @override
  String undoHistoryStoredEntries(int count, int limit) {
    return '保存済みエントリ: $count / $limit';
  }

  @override
  String get openHistoryScreen => '履歴画面を開く';

  @override
  String undoHistoryLimitRange(int min, int defaultValue, int max) {
    return '最小 $min  •  デフォルト $defaultValue  •  最大 $max';
  }

  @override
  String get searchHistory => '履歴を検索';

  @override
  String get allActions => 'すべての操作';

  @override
  String get noHistoryEntriesMatchFilters => 'フィルターに一致する履歴エントリはありません。';

  @override
  String historyExportedTo(String path) {
    return '履歴を $path にエクスポートしました';
  }

  @override
  String get historyExportedAndShared => '履歴をエクスポートして共有シートを開きました';

  @override
  String get exportJson => 'JSON をエクスポート';

  @override
  String get exportAndShare => 'エクスポートして共有';

  @override
  String get jumpToCurrent => '現在に移動';

  @override
  String get historyExportSubject => '履歴エクスポート';

  @override
  String get historyExportText => 'FireRacoon 履歴エクスポート';

  @override
  String get historySectionToday => '今日';

  @override
  String get historySectionYesterday => '昨日';

  @override
  String get historySectionOlder => 'それ以前';

  @override
  String historyEntriesCount(int count, int limit) {
    return '$count / $limit';
  }

  @override
  String get undoActionTypeThemeMode => 'テーマモード';

  @override
  String get undoActionTypeThemePalette => 'テーマパレット';

  @override
  String get undoActionTypeThemeAccent => 'テーマアクセント';

  @override
  String get undoActionTypeThemeFunMode => 'ファンモード';

  @override
  String get undoActionTypeLocale => '言語';

  @override
  String get undoActionTypeViewMode => '表示モード';

  @override
  String get undoActionTypeTransactionPageSize => '取引ページサイズ';

  @override
  String get undoActionTypePrognosisMode => '予測表示モード';

  @override
  String get undoActionTypePrognosisHorizon => '予測期間';

  @override
  String get undoActionTypePrognosisInclusion => '予測の含める項目';

  @override
  String get undoActionTypePrognosisMarginPercent => '予測マージン';

  @override
  String get undoActionTypeAccountCreate => '口座を作成';

  @override
  String get undoActionTypeAccountUpdate => '口座を更新';

  @override
  String get undoActionTypeAccountDelete => '口座を削除';

  @override
  String get undoActionTypeBudgetCreate => '予算を作成';

  @override
  String get undoActionTypeBudgetUpdate => '予算を更新';

  @override
  String get undoActionTypeBudgetDelete => '予算を削除';

  @override
  String get undoActionTypeTransactionCreate => '取引を作成';

  @override
  String get undoActionTypeTransactionUpdate => '取引を更新';

  @override
  String get undoActionTypeTransactionDelete => '取引を削除';

  @override
  String get undoActionTypeBillCreate => 'サブスクリプションを作成';

  @override
  String get undoActionTypeBillUpdate => 'サブスクリプションを更新';

  @override
  String get undoActionTypeBillDelete => 'サブスクリプションを削除';

  @override
  String get undoActionTypeRecurrenceCreate => '定期取引を作成';

  @override
  String get undoActionTypeRecurrenceUpdate => '定期取引を更新';

  @override
  String get undoActionTypeRecurrenceDelete => '定期取引を削除';

  @override
  String get undoActionTypePiggyBankCreate => '貯金箱を作成';

  @override
  String get undoActionTypePiggyBankUpdate => '貯金箱を更新';

  @override
  String get undoActionTypePiggyBankDelete => '貯金箱を削除';

  @override
  String get undoActionTypeLiabilityCreate => '負債を作成';

  @override
  String get searchHintTitle => '入力して検索';

  @override
  String get searchHintSubtitle => '説明、口座、カテゴリ、タグ、メモ、金額で検索できます。';

  @override
  String get noSuggestions => '該当する候補がありません';

  @override
  String get invalidAmount => '金額は0より大きい有効な数値である必要があります。';

  @override
  String get invalidForeignAmount => '外貨金額は0より大きい有効な数値である必要があります。';

  @override
  String get exportFireflyData => 'Firefly データをバックアップ';

  @override
  String get exportFireflyDataDescription =>
      'Firefly のデータのスナップショットを JSON ファイルに保存します。口座、各分割を含む取引、予算、カテゴリ、タグ、請求、貯金箱、繰り返しルール、通貨。\n\nこれは完全なバックアップではありません。Firefly III にバックアップ機能はなく、API 経由で通信するアプリはデータベース、アップロードされた添付ファイル、インスタンスキーには到達できません。動作する Firefly を復元するにはサーバー上で取得したボリュームアーカイブが必要です。デプロイガイドを参照してください。';

  @override
  String fireflyDataExportedTo(String path) {
    return 'Firefly データを $path にエクスポートしました';
  }

  @override
  String get missingInformation => '未入力の項目';

  @override
  String get missingDescription => '説明を入力してください。';

  @override
  String get missingAmount => '金額を入力してください。';

  @override
  String get missingAccounts => '送金元口座と送金先口座の両方を選択してください。';

  @override
  String get appUsers => 'アプリユーザー';

  @override
  String get enableAppUsers => 'アプリユーザーを有効にする';

  @override
  String get enableAppUsersDescription =>
      'Add password-protected profiles for the people who use this app. Everyone still shares the same Firefly III data.';

  @override
  String get createAdmin => '管理者アカウントを作成';

  @override
  String get createAdminDescription =>
      'You will be the first admin. You can add more accounts afterwards.';

  @override
  String get addUser => 'ユーザーを追加';

  @override
  String get editUser => 'ユーザーを編集';

  @override
  String get deleteUser => 'ユーザーを削除';

  @override
  String get role => '役割';

  @override
  String get roleAdmin => '管理者';

  @override
  String get roleUser => 'ユーザー';

  @override
  String get roleViewer => '閲覧者';

  @override
  String get roleAdminDescription =>
      'Full access, including Firefly settings and user management.';

  @override
  String get roleUserDescription => 'Can add and edit financial data.';

  @override
  String get roleViewerDescription => 'Read-only access.';

  @override
  String get requireLogin => '起動のたびにログインを要求する';

  @override
  String get requireLoginDescription =>
      'When off, signed-in users stay signed in between launches.';

  @override
  String get switchUser => 'Switch user';

  @override
  String get selectUserSubtitle =>
      'Choose whose profile to use. No password needed while login is not required.';

  @override
  String get assignPerson => '関連付けられた人物';

  @override
  String get noPersonAssigned => 'なし';

  @override
  String get myAccount => 'マイアカウント';

  @override
  String get changePassword => 'パスワードを変更';

  @override
  String get setPassword => 'Set password';

  @override
  String get clearPassword => 'Remove password';

  @override
  String get passwordOptionalHint =>
      'Optional. Leave blank to skip. Required only if login with password is enabled.';

  @override
  String get currentPassword => '現在のパスワード';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get confirmNewPassword => '新しいパスワードの確認';

  @override
  String get logout => 'ログアウト';

  @override
  String get login => 'ログイン';

  @override
  String get username => 'ユーザー名';

  @override
  String get password => 'パスワード';

  @override
  String get loginSubtitle => '続行するにはログインしてください。';

  @override
  String get loginMissingFields => 'ユーザー名とパスワードを入力してください。';

  @override
  String get loginInvalidCredentials => 'ユーザー名またはパスワードが正しくありません。';

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
  String get passwordsDoNotMatch => 'パスワードが一致しません。';

  @override
  String get usernameTaken => 'このユーザー名はすでに使用されています。';

  @override
  String get currentPasswordIncorrect => '現在のパスワードが正しくありません。';

  @override
  String get userCreated => 'ユーザーを作成しました。';

  @override
  String get userUpdated => 'ユーザーを更新しました。';

  @override
  String get userDeleted => 'ユーザーを削除しました。';

  @override
  String get passwordChanged => 'パスワードを更新しました。';

  @override
  String get passwordCleared => 'Password removed.';

  @override
  String get deleteUserConfirmTitle => 'ユーザーを削除';

  @override
  String deleteUserConfirmMessage(String username) {
    return 'This removes $username\'s app profile. Their Firefly III data is not affected.';
  }

  @override
  String signedInAs(String username) {
    return '$username としてサインイン中';
  }

  @override
  String get usernameRequired => 'ユーザー名を入力してください。';

  @override
  String get unlockWithBiometrics => '生体認証でロック解除';

  @override
  String get unlockWithBiometricsDescription =>
      'ログイン画面で Face ID、Touch ID、指紋、または端末の PIN を使います。';

  @override
  String get biometricUnlockReason => 'FireRacoon のロックを解除';

  @override
  String get biometricEnableReason => '生体認証のロック解除を有効にするには確認してください';

  @override
  String get biometricUnlockFailed => '生体認証によるロック解除がキャンセルされたか失敗しました。';

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
  String get recordedBalance => '記録済み';
}
