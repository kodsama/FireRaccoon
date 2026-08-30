import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('ja'),
    Locale('pt'),
    Locale('sv'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FireRaccoon'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'The brightest bandit for your budget.'**
  String get appTagline;

  /// No description provided for @appNameFire.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get appNameFire;

  /// No description provided for @appNameRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Raccoon'**
  String get appNameRaccoon;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navDashboardShort.
  ///
  /// In en, this message translates to:
  /// **'Dash'**
  String get navDashboardShort;

  /// No description provided for @navAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get navAccounts;

  /// No description provided for @navTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get navTransactions;

  /// No description provided for @navBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get navBudgets;

  /// No description provided for @navSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions & Recurring'**
  String get navSubscriptions;

  /// No description provided for @navPiggyBanks.
  ///
  /// In en, this message translates to:
  /// **'Piggy banks'**
  String get navPiggyBanks;

  /// No description provided for @navExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get navExpenses;

  /// No description provided for @navIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get navIncome;

  /// No description provided for @navTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get navTransfers;

  /// No description provided for @navLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get navLiabilities;

  /// No description provided for @navProjection.
  ///
  /// In en, this message translates to:
  /// **'Projection'**
  String get navProjection;

  /// No description provided for @navPrognosis.
  ///
  /// In en, this message translates to:
  /// **'Prognosis'**
  String get navPrognosis;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @netWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get netWorth;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @fireflyUser.
  ///
  /// In en, this message translates to:
  /// **'Firefly user'**
  String get fireflyUser;

  /// No description provided for @fireflyConnected.
  ///
  /// In en, this message translates to:
  /// **'Firefly III · connected'**
  String get fireflyConnected;

  /// No description provided for @fireflyDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Firefly III · disconnected'**
  String get fireflyDisconnected;

  /// No description provided for @fireflyConnectionChecking.
  ///
  /// In en, this message translates to:
  /// **'Firefly III · checking…'**
  String get fireflyConnectionChecking;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersion(String version);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get selectLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageSwedish.
  ///
  /// In en, this message translates to:
  /// **'Svenska'**
  String get languageSwedish;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Português'**
  String get languagePortuguese;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// No description provided for @defaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default Currency'**
  String get defaultCurrency;

  /// No description provided for @selectCurrency.
  ///
  /// In en, this message translates to:
  /// **'Select currency'**
  String get selectCurrency;

  /// No description provided for @primaryCurrencyChangeWarning.
  ///
  /// In en, this message translates to:
  /// **'Firefly III may recalculate stored amounts when the default currency changes.'**
  String get primaryCurrencyChangeWarning;

  /// No description provided for @primaryCurrencyChanged.
  ///
  /// In en, this message translates to:
  /// **'Default currency set to {code}'**
  String primaryCurrencyChanged(String code);

  /// No description provided for @failedToSetPrimaryCurrency.
  ///
  /// In en, this message translates to:
  /// **'Failed to set default currency: {error}'**
  String failedToSetPrimaryCurrency(String error);

  /// No description provided for @primaryCurrencyCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get primaryCurrencyCurrent;

  /// No description provided for @changePrimaryCurrencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Change default currency'**
  String get changePrimaryCurrencyTitle;

  /// No description provided for @changePrimaryCurrencyMessage.
  ///
  /// In en, this message translates to:
  /// **'Change the default currency to {code}? {warning}'**
  String changePrimaryCurrencyMessage(String code, String warning);

  /// No description provided for @changePrimaryCurrencyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changePrimaryCurrencyConfirm;

  /// No description provided for @connectToFireflyToLoad.
  ///
  /// In en, this message translates to:
  /// **'Connect to Firefly III to load'**
  String get connectToFireflyToLoad;

  /// No description provided for @managedInFirefly.
  ///
  /// In en, this message translates to:
  /// **'Managed in Firefly III'**
  String get managedInFirefly;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @raccoonMode.
  ///
  /// In en, this message translates to:
  /// **'Raccoon Mode'**
  String get raccoonMode;

  /// No description provided for @themeStyle.
  ///
  /// In en, this message translates to:
  /// **'Theme Style'**
  String get themeStyle;

  /// No description provided for @themeStyleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a palette, accent colour, and brightness. Changes apply instantly.'**
  String get themeStyleSubtitle;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @themeBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get themeBrightness;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themePalette.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get themePalette;

  /// No description provided for @paletteClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get paletteClassic;

  /// No description provided for @paletteSpectrum.
  ///
  /// In en, this message translates to:
  /// **'Spectrum'**
  String get paletteSpectrum;

  /// No description provided for @paletteRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Raccoon'**
  String get paletteRaccoon;

  /// No description provided for @themeAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent colour'**
  String get themeAccentColor;

  /// No description provided for @themePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get themePreview;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @accentGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get accentGreen;

  /// No description provided for @accentTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get accentTeal;

  /// No description provided for @accentBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get accentBlue;

  /// No description provided for @accentOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// No description provided for @accentRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get accentRed;

  /// No description provided for @accentViolet.
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get accentViolet;

  /// No description provided for @accentLime.
  ///
  /// In en, this message translates to:
  /// **'Lime'**
  String get accentLime;

  /// No description provided for @accentSky.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get accentSky;

  /// No description provided for @accentCharcoal.
  ///
  /// In en, this message translates to:
  /// **'Charcoal'**
  String get accentCharcoal;

  /// No description provided for @accentSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get accentSilver;

  /// No description provided for @accentTan.
  ///
  /// In en, this message translates to:
  /// **'Tan'**
  String get accentTan;

  /// No description provided for @accentAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get accentAmber;

  /// No description provided for @accentSlate.
  ///
  /// In en, this message translates to:
  /// **'Slate'**
  String get accentSlate;

  /// No description provided for @accentMidnight.
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get accentMidnight;

  /// No description provided for @accentSmoke.
  ///
  /// In en, this message translates to:
  /// **'Smoke'**
  String get accentSmoke;

  /// No description provided for @accentPearl.
  ///
  /// In en, this message translates to:
  /// **'Pearl'**
  String get accentPearl;

  /// No description provided for @backendConnection.
  ///
  /// In en, this message translates to:
  /// **'Backend Connection (Firefly III)'**
  String get backendConnection;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @oauth2Connection.
  ///
  /// In en, this message translates to:
  /// **'OAuth2 Connection'**
  String get oauth2Connection;

  /// No description provided for @personalAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Personal Access Token'**
  String get personalAccessToken;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @fireflyConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Firefly III Connection'**
  String get fireflyConnectionTitle;

  /// No description provided for @serverUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL (e.g. https://firefly.my-domain.com)'**
  String get serverUrlLabel;

  /// No description provided for @allowHttpConnections.
  ///
  /// In en, this message translates to:
  /// **'Allow HTTP connections'**
  String get allowHttpConnections;

  /// No description provided for @authenticationMethod.
  ///
  /// In en, this message translates to:
  /// **'Authentication Method'**
  String get authenticationMethod;

  /// No description provided for @oauth2.
  ///
  /// In en, this message translates to:
  /// **'OAuth2'**
  String get oauth2;

  /// No description provided for @oauthClientId.
  ///
  /// In en, this message translates to:
  /// **'OAuth Client ID'**
  String get oauthClientId;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @connectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connection successful!'**
  String get connectionSuccessful;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Please check your URL and Token.'**
  String get connectionFailed;

  /// No description provided for @loginViaBrowser.
  ///
  /// In en, this message translates to:
  /// **'Login via Browser'**
  String get loginViaBrowser;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorGeneric(String error);

  /// No description provided for @errorLoadingData.
  ///
  /// In en, this message translates to:
  /// **'Error loading data: {error}'**
  String errorLoadingData(String error);

  /// No description provided for @tabInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get tabInsights;

  /// No description provided for @tabAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get tabAccounts;

  /// No description provided for @tabFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get tabFocus;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get totalBalance;

  /// No description provided for @incomeMonth.
  ///
  /// In en, this message translates to:
  /// **'Income · {month}'**
  String incomeMonth(String month);

  /// No description provided for @spendingMonth.
  ///
  /// In en, this message translates to:
  /// **'Spending · {month}'**
  String spendingMonth(String month);

  /// No description provided for @savedMonth.
  ///
  /// In en, this message translates to:
  /// **'Saved · {month}'**
  String savedMonth(String month);

  /// No description provided for @snatchedFunds.
  ///
  /// In en, this message translates to:
  /// **'Snatched Funds'**
  String get snatchedFunds;

  /// No description provided for @burntCash.
  ///
  /// In en, this message translates to:
  /// **'Burnt Cash'**
  String get burntCash;

  /// No description provided for @stash.
  ///
  /// In en, this message translates to:
  /// **'Stash'**
  String get stash;

  /// No description provided for @snatched.
  ///
  /// In en, this message translates to:
  /// **'Snatched'**
  String get snatched;

  /// No description provided for @burnt.
  ///
  /// In en, this message translates to:
  /// **'Burnt'**
  String get burnt;

  /// No description provided for @navDashboardRaccoon.
  ///
  /// In en, this message translates to:
  /// **'The Den'**
  String get navDashboardRaccoon;

  /// No description provided for @navDashboardShortRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Den'**
  String get navDashboardShortRaccoon;

  /// No description provided for @navAccountsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Stashes'**
  String get navAccountsRaccoon;

  /// No description provided for @navTransactionsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Heist Log'**
  String get navTransactionsRaccoon;

  /// No description provided for @navBudgetsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Hoard Plans'**
  String get navBudgetsRaccoon;

  /// No description provided for @navSubscriptionsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Recurring Raids'**
  String get navSubscriptionsRaccoon;

  /// No description provided for @navPiggyBanksRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Mini Stashes'**
  String get navPiggyBanksRaccoon;

  /// No description provided for @navExpensesRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Burn Report'**
  String get navExpensesRaccoon;

  /// No description provided for @navProjectionRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Crystal Stash'**
  String get navProjectionRaccoon;

  /// No description provided for @navPrognosisRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Month-end loot'**
  String get navPrognosisRaccoon;

  /// No description provided for @navSettingsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Den Rules'**
  String get navSettingsRaccoon;

  /// No description provided for @netWorthRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Total Hoard'**
  String get netWorthRaccoon;

  /// No description provided for @searchRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Sniff around…'**
  String get searchRaccoon;

  /// No description provided for @accountsTitleRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Stashes'**
  String get accountsTitleRaccoon;

  /// No description provided for @transactionsTitleRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Heist Log'**
  String get transactionsTitleRaccoon;

  /// No description provided for @budgetsTitleRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Hoard Plans'**
  String get budgetsTitleRaccoon;

  /// No description provided for @expensesTitleRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Burn Report'**
  String get expensesTitleRaccoon;

  /// No description provided for @projectionTitleRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Crystal Stash'**
  String get projectionTitleRaccoon;

  /// No description provided for @settingsTitleRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Den Rules'**
  String get settingsTitleRaccoon;

  /// No description provided for @tabInsightsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Loot Intel'**
  String get tabInsightsRaccoon;

  /// No description provided for @tabAccountsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Stashes'**
  String get tabAccountsRaccoon;

  /// No description provided for @tabFocusRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Heist HQ'**
  String get tabFocusRaccoon;

  /// No description provided for @totalBalanceRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Full Stash'**
  String get totalBalanceRaccoon;

  /// No description provided for @incomeMonthRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Snatched · {month}'**
  String incomeMonthRaccoon(String month);

  /// No description provided for @spendingMonthRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Burnt · {month}'**
  String spendingMonthRaccoon(String month);

  /// No description provided for @savedMonthRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Stashed · {month}'**
  String savedMonthRaccoon(String month);

  /// No description provided for @cashFlowRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Loot Flow'**
  String get cashFlowRaccoon;

  /// No description provided for @whereMoneyGoesRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Where loot goes'**
  String get whereMoneyGoesRaccoon;

  /// No description provided for @recentActivityRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Recent Raids'**
  String get recentActivityRaccoon;

  /// No description provided for @yourAccountsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Your Stashes'**
  String get yourAccountsRaccoon;

  /// No description provided for @budgetsAtGlanceRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Hoard at a glance'**
  String get budgetsAtGlanceRaccoon;

  /// No description provided for @viewAllAccountsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'All stashes'**
  String get viewAllAccountsRaccoon;

  /// No description provided for @assetAccountsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Treasure Stashes'**
  String get assetAccountsRaccoon;

  /// No description provided for @liabilityAccountsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Debts & IOUs'**
  String get liabilityAccountsRaccoon;

  /// No description provided for @stocksAndFundsAccountsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Market Stashes'**
  String get stocksAndFundsAccountsRaccoon;

  /// No description provided for @allAccountsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'All Stashes'**
  String get allAccountsRaccoon;

  /// No description provided for @accountsRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Stashes'**
  String get accountsRaccoon;

  /// No description provided for @newTransactionRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Plan a Heist'**
  String get newTransactionRaccoon;

  /// No description provided for @editTransactionRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Edit Heist'**
  String get editTransactionRaccoon;

  /// No description provided for @transactionsCountRaccoon.
  ///
  /// In en, this message translates to:
  /// **'{count} heists'**
  String transactionsCountRaccoon(int count);

  /// No description provided for @oneTransactionRaccoon.
  ///
  /// In en, this message translates to:
  /// **'1 heist'**
  String get oneTransactionRaccoon;

  /// No description provided for @transactionTypeDepositRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Snatch'**
  String get transactionTypeDepositRaccoon;

  /// No description provided for @transactionTypeWithdrawalRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Burn'**
  String get transactionTypeWithdrawalRaccoon;

  /// No description provided for @transactionTypeTransferRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Stash Shuffle'**
  String get transactionTypeTransferRaccoon;

  /// No description provided for @expenseLabelRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Burn'**
  String get expenseLabelRaccoon;

  /// No description provided for @spentRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Burnt'**
  String get spentRaccoon;

  /// No description provided for @newBudgetRaccoon.
  ///
  /// In en, this message translates to:
  /// **'New Hoard Plan'**
  String get newBudgetRaccoon;

  /// No description provided for @projectedBalanceRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Future Hoard'**
  String get projectedBalanceRaccoon;

  /// No description provided for @piggyBankRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Mini Stash'**
  String get piggyBankRaccoon;

  /// No description provided for @transfersRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Stash Shuffles'**
  String get transfersRaccoon;

  /// No description provided for @expensesFilterRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Burns'**
  String get expensesFilterRaccoon;

  /// No description provided for @noTransactionsYetRaccoon.
  ///
  /// In en, this message translates to:
  /// **'No heists yet'**
  String get noTransactionsYetRaccoon;

  /// No description provided for @lookingAheadRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Peeking Ahead'**
  String get lookingAheadRaccoon;

  /// No description provided for @openProjectionRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Peek the Future'**
  String get openProjectionRaccoon;

  /// No description provided for @editAccountRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Edit Stash'**
  String get editAccountRaccoon;

  /// No description provided for @accountNameRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Stash name'**
  String get accountNameRaccoon;

  /// No description provided for @filterAccountRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Filter Stash'**
  String get filterAccountRaccoon;

  /// No description provided for @sourceAccountRaccoon.
  ///
  /// In en, this message translates to:
  /// **'From Stash'**
  String get sourceAccountRaccoon;

  /// No description provided for @destinationAccountRaccoon.
  ///
  /// In en, this message translates to:
  /// **'To Stash'**
  String get destinationAccountRaccoon;

  /// No description provided for @totalSpentPeriodRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Total burnt this period'**
  String get totalSpentPeriodRaccoon;

  /// No description provided for @totalIncomePeriodRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Total snatched this period'**
  String get totalIncomePeriodRaccoon;

  /// No description provided for @totalTransferredPeriodRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Total shuffled this period'**
  String get totalTransferredPeriodRaccoon;

  /// No description provided for @newAccount.
  ///
  /// In en, this message translates to:
  /// **'New Account'**
  String get newAccount;

  /// No description provided for @newLiability.
  ///
  /// In en, this message translates to:
  /// **'New Liability'**
  String get newLiability;

  /// No description provided for @newExpense.
  ///
  /// In en, this message translates to:
  /// **'New Expense'**
  String get newExpense;

  /// No description provided for @newAccountRaccoon.
  ///
  /// In en, this message translates to:
  /// **'New Stash'**
  String get newAccountRaccoon;

  /// No description provided for @newLiabilityRaccoon.
  ///
  /// In en, this message translates to:
  /// **'New IOU'**
  String get newLiabilityRaccoon;

  /// No description provided for @newExpenseRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Plan a Burn'**
  String get newExpenseRaccoon;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @spending.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get spending;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @cashFlow.
  ///
  /// In en, this message translates to:
  /// **'Cash flow'**
  String get cashFlow;

  /// No description provided for @whereMoneyGoes.
  ///
  /// In en, this message translates to:
  /// **'Where money goes'**
  String get whereMoneyGoes;

  /// No description provided for @noSpendingThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No spending this month yet'**
  String get noSpendingThisMonth;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @lookingAhead.
  ///
  /// In en, this message translates to:
  /// **'Looking ahead'**
  String get lookingAhead;

  /// No description provided for @spendingPaceWarning.
  ///
  /// In en, this message translates to:
  /// **'Spending pace may exceed income this month'**
  String get spendingPaceWarning;

  /// No description provided for @openProjection.
  ///
  /// In en, this message translates to:
  /// **'Open projection'**
  String get openProjection;

  /// No description provided for @yourAccounts.
  ///
  /// In en, this message translates to:
  /// **'Your Accounts'**
  String get yourAccounts;

  /// No description provided for @budgetsAtGlance.
  ///
  /// In en, this message translates to:
  /// **'Budgets at a glance'**
  String get budgetsAtGlance;

  /// No description provided for @viewAllAccounts.
  ///
  /// In en, this message translates to:
  /// **'View all accounts'**
  String get viewAllAccounts;

  /// No description provided for @thirtyDayOutlook.
  ///
  /// In en, this message translates to:
  /// **'30-day outlook'**
  String get thirtyDayOutlook;

  /// No description provided for @monthEndPrognosis.
  ///
  /// In en, this message translates to:
  /// **'Month-end prognosis'**
  String get monthEndPrognosis;

  /// No description provided for @projectedEndOfMonth.
  ///
  /// In en, this message translates to:
  /// **'End of month'**
  String get projectedEndOfMonth;

  /// No description provided for @includeCreditCardPayments.
  ///
  /// In en, this message translates to:
  /// **'Include credit card payments'**
  String get includeCreditCardPayments;

  /// No description provided for @prognosisDeltaPositive.
  ///
  /// In en, this message translates to:
  /// **'+{amount} expected'**
  String prognosisDeltaPositive(String amount);

  /// No description provided for @prognosisDeltaNegative.
  ///
  /// In en, this message translates to:
  /// **'{amount} expected'**
  String prognosisDeltaNegative(String amount);

  /// No description provided for @prognosisLowBalanceWarning.
  ///
  /// In en, this message translates to:
  /// **'Projected balance may go negative'**
  String get prognosisLowBalanceWarning;

  /// No description provided for @prognosisDebtWarning.
  ///
  /// In en, this message translates to:
  /// **'Projected debt may increase'**
  String get prognosisDebtWarning;

  /// No description provided for @openPrognosis.
  ///
  /// In en, this message translates to:
  /// **'Open prognosis'**
  String get openPrognosis;

  /// No description provided for @prognosisMarginLabel.
  ///
  /// In en, this message translates to:
  /// **'Margin of error'**
  String get prognosisMarginLabel;

  /// No description provided for @prognosisMarginDetail.
  ///
  /// In en, this message translates to:
  /// **'±{percent}% uncertainty on amounts'**
  String prognosisMarginDetail(String percent);

  /// No description provided for @prognosisIncludeScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled transactions'**
  String get prognosisIncludeScheduled;

  /// No description provided for @prognosisIncludeRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions'**
  String get prognosisIncludeRecurring;

  /// No description provided for @prognosisIncludeBills.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get prognosisIncludeBills;

  /// No description provided for @prognosisIncludeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get prognosisIncludeIncome;

  /// No description provided for @prognosisIncludeExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get prognosisIncludeExpenses;

  /// No description provided for @prognosisIncludeTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get prognosisIncludeTransfers;

  /// No description provided for @prognosisIncludeCreditCards.
  ///
  /// In en, this message translates to:
  /// **'Credit cards'**
  String get prognosisIncludeCreditCards;

  /// No description provided for @prognosisEndOfNextMonth.
  ///
  /// In en, this message translates to:
  /// **'End of next month'**
  String get prognosisEndOfNextMonth;

  /// No description provided for @prognosisMinBalance.
  ///
  /// In en, this message translates to:
  /// **'Min prognosis'**
  String get prognosisMinBalance;

  /// No description provided for @prognosisMaxBalance.
  ///
  /// In en, this message translates to:
  /// **'Max prognosis'**
  String get prognosisMaxBalance;

  /// No description provided for @prognosisExpectedBalance.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get prognosisExpectedBalance;

  /// No description provided for @prognosisSelectAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get prognosisSelectAccount;

  /// No description provided for @prognosisBandLegend.
  ///
  /// In en, this message translates to:
  /// **'Shaded band shows min–max range; line is expected'**
  String get prognosisBandLegend;

  /// No description provided for @prognosisModeExpected.
  ///
  /// In en, this message translates to:
  /// **'Real projection'**
  String get prognosisModeExpected;

  /// No description provided for @prognosisModeProjected.
  ///
  /// In en, this message translates to:
  /// **'Speculative projection'**
  String get prognosisModeProjected;

  /// No description provided for @prognosisModeExpectedHint.
  ///
  /// In en, this message translates to:
  /// **'Month-end balances from current balances, scheduled transactions, recurring items, and bills'**
  String get prognosisModeExpectedHint;

  /// No description provided for @prognosisModeProjectedHint.
  ///
  /// In en, this message translates to:
  /// **'Trend-based forecast from historical net cash flow'**
  String get prognosisModeProjectedHint;

  /// No description provided for @prognosisHorizonLabel.
  ///
  /// In en, this message translates to:
  /// **'Horizon'**
  String get prognosisHorizonLabel;

  /// No description provided for @prognosisHorizonEndOfMonth.
  ///
  /// In en, this message translates to:
  /// **'End of month'**
  String get prognosisHorizonEndOfMonth;

  /// No description provided for @prognosisHorizonEndOfNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get prognosisHorizonEndOfNextMonth;

  /// No description provided for @prognosisHorizonTwoMonths.
  ///
  /// In en, this message translates to:
  /// **'2 months'**
  String get prognosisHorizonTwoMonths;

  /// No description provided for @prognosisHorizonThreeMonths.
  ///
  /// In en, this message translates to:
  /// **'3 months'**
  String get prognosisHorizonThreeMonths;

  /// No description provided for @prognosisHorizonSixMonths.
  ///
  /// In en, this message translates to:
  /// **'6 months'**
  String get prognosisHorizonSixMonths;

  /// No description provided for @prognosisHorizonOneYear.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get prognosisHorizonOneYear;

  /// No description provided for @prognosisHorizonThreeYears.
  ///
  /// In en, this message translates to:
  /// **'3 years'**
  String get prognosisHorizonThreeYears;

  /// No description provided for @prognosisHorizonFiveYears.
  ///
  /// In en, this message translates to:
  /// **'5 years'**
  String get prognosisHorizonFiveYears;

  /// No description provided for @prognosisHorizonTenYears.
  ///
  /// In en, this message translates to:
  /// **'10 years'**
  String get prognosisHorizonTenYears;

  /// No description provided for @prognosisMilestoneThreeMonths.
  ///
  /// In en, this message translates to:
  /// **'End of 3 months'**
  String get prognosisMilestoneThreeMonths;

  /// No description provided for @prognosisMilestoneSixMonths.
  ///
  /// In en, this message translates to:
  /// **'End of 6 months'**
  String get prognosisMilestoneSixMonths;

  /// No description provided for @prognosisMilestoneOneYear.
  ///
  /// In en, this message translates to:
  /// **'End of 1 year'**
  String get prognosisMilestoneOneYear;

  /// No description provided for @prognosisIncludeSources.
  ///
  /// In en, this message translates to:
  /// **'Include in forecast'**
  String get prognosisIncludeSources;

  /// No description provided for @prognosisIncludeLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get prognosisIncludeLiabilities;

  /// No description provided for @prognosisNegativeOn.
  ///
  /// In en, this message translates to:
  /// **'Negative on {date}'**
  String prognosisNegativeOn(String date);

  /// No description provided for @prognosisCurrentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current balance'**
  String get prognosisCurrentBalance;

  /// No description provided for @prognosisPredictedBalances.
  ///
  /// In en, this message translates to:
  /// **'Predicted balances'**
  String get prognosisPredictedBalances;

  /// No description provided for @todaysTimeline.
  ///
  /// In en, this message translates to:
  /// **'Today\'s timeline'**
  String get todaysTimeline;

  /// No description provided for @noActivityToday.
  ///
  /// In en, this message translates to:
  /// **'No activity today'**
  String get noActivityToday;

  /// No description provided for @noChangeVsLastMonth.
  ///
  /// In en, this message translates to:
  /// **'No change vs last month'**
  String get noChangeVsLastMonth;

  /// No description provided for @newActivityThisMonth.
  ///
  /// In en, this message translates to:
  /// **'New activity this month'**
  String get newActivityThisMonth;

  /// No description provided for @percentVsLastMonth.
  ///
  /// In en, this message translates to:
  /// **'{arrow}{percent}% vs last month'**
  String percentVsLastMonth(String arrow, String percent);

  /// No description provided for @projectedSavingsHeadline.
  ///
  /// In en, this message translates to:
  /// **'{amount} projected savings this month'**
  String projectedSavingsHeadline(String amount);

  /// No description provided for @onPaceDetail.
  ///
  /// In en, this message translates to:
  /// **'On pace for {amount} saved by month end'**
  String onPaceDetail(String amount);

  /// No description provided for @spendingOutpacingDetail.
  ///
  /// In en, this message translates to:
  /// **'Spending is outpacing income by {amount}'**
  String spendingOutpacingDetail(String amount);

  /// No description provided for @accountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTitle;

  /// No description provided for @assetAccounts.
  ///
  /// In en, this message translates to:
  /// **'Asset Accounts'**
  String get assetAccounts;

  /// No description provided for @stocksAndFundsAccounts.
  ///
  /// In en, this message translates to:
  /// **'Stocks & Funds Accounts'**
  String get stocksAndFundsAccounts;

  /// No description provided for @liabilityAccounts.
  ///
  /// In en, this message translates to:
  /// **'Liability Accounts'**
  String get liabilityAccounts;

  /// No description provided for @noAccountsFound.
  ///
  /// In en, this message translates to:
  /// **'No accounts found.'**
  String get noAccountsFound;

  /// No description provided for @allAccounts.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get allAccounts;

  /// No description provided for @assetsOnly.
  ///
  /// In en, this message translates to:
  /// **'Assets only'**
  String get assetsOnly;

  /// No description provided for @liabilitiesOnly.
  ///
  /// In en, this message translates to:
  /// **'Liabilities only'**
  String get liabilitiesOnly;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountName;

  /// No description provided for @accountRoleDefault.
  ///
  /// In en, this message translates to:
  /// **'Checking account'**
  String get accountRoleDefault;

  /// No description provided for @accountRoleShared.
  ///
  /// In en, this message translates to:
  /// **'Shared account'**
  String get accountRoleShared;

  /// No description provided for @accountRoleSaving.
  ///
  /// In en, this message translates to:
  /// **'Savings account'**
  String get accountRoleSaving;

  /// No description provided for @accountRoleCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get accountRoleCreditCard;

  /// No description provided for @holdingAccountFundLabel.
  ///
  /// In en, this message translates to:
  /// **'(Fund)'**
  String get holdingAccountFundLabel;

  /// No description provided for @holdingAccountStockLabel.
  ///
  /// In en, this message translates to:
  /// **'(Stock)'**
  String get holdingAccountStockLabel;

  /// No description provided for @failedToUpdate.
  ///
  /// In en, this message translates to:
  /// **'Failed to update: {error}'**
  String failedToUpdate(String error);

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @transactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactionsTitle;

  /// No description provided for @filteredBy.
  ///
  /// In en, this message translates to:
  /// **'Filtered by: {account}'**
  String filteredBy(String account);

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance:'**
  String get balance;

  /// No description provided for @balanceCheckMode.
  ///
  /// In en, this message translates to:
  /// **'Check balance'**
  String get balanceCheckMode;

  /// No description provided for @balanceCheckExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected balance'**
  String get balanceCheckExpected;

  /// No description provided for @balanceCheckStatement.
  ///
  /// In en, this message translates to:
  /// **'Your balance'**
  String get balanceCheckStatement;

  /// No description provided for @balanceCheckStatementHint.
  ///
  /// In en, this message translates to:
  /// **'Enter balance from your statement'**
  String get balanceCheckStatementHint;

  /// No description provided for @balanceCheckMatch.
  ///
  /// In en, this message translates to:
  /// **'Balances match'**
  String get balanceCheckMatch;

  /// No description provided for @balanceCheckDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference: {amount}'**
  String balanceCheckDifference(String amount);

  /// No description provided for @balanceCheckEnterBalance.
  ///
  /// In en, this message translates to:
  /// **'Enter a balance to compare'**
  String get balanceCheckEnterBalance;

  /// No description provided for @balanceCheckInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get balanceCheckInvalidAmount;

  /// No description provided for @balanceCheckSelectedBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance from selected'**
  String get balanceCheckSelectedBalance;

  /// No description provided for @balanceCheckReconcile.
  ///
  /// In en, this message translates to:
  /// **'Reconcile selected'**
  String get balanceCheckReconcile;

  /// No description provided for @balanceCheckReconciled.
  ///
  /// In en, this message translates to:
  /// **'Selected transactions reconciled'**
  String get balanceCheckReconciled;

  /// No description provided for @balanceCheckNothingToReconcile.
  ///
  /// In en, this message translates to:
  /// **'Nothing to reconcile. Select unreconciled transactions to include them.'**
  String get balanceCheckNothingToReconcile;

  /// No description provided for @balanceCheckPaymentAccount.
  ///
  /// In en, this message translates to:
  /// **'Payment account'**
  String get balanceCheckPaymentAccount;

  /// No description provided for @balanceCheckPaybackDate.
  ///
  /// In en, this message translates to:
  /// **'Payback date'**
  String get balanceCheckPaybackDate;

  /// No description provided for @balanceCheckSelectPaymentAccount.
  ///
  /// In en, this message translates to:
  /// **'Select payment account'**
  String get balanceCheckSelectPaymentAccount;

  /// No description provided for @balanceCheckNoPaymentAccounts.
  ///
  /// In en, this message translates to:
  /// **'No eligible payment accounts'**
  String get balanceCheckNoPaymentAccounts;

  /// No description provided for @balanceCheckPaybackSummary.
  ///
  /// In en, this message translates to:
  /// **'Payback: {amount} from {account} on {date}'**
  String balanceCheckPaybackSummary(String amount, String account, String date);

  /// No description provided for @balanceCheckPaybackReconciled.
  ///
  /// In en, this message translates to:
  /// **'Purchases reconciled and payback transfer created'**
  String get balanceCheckPaybackReconciled;

  /// No description provided for @balanceCheckNoEligiblePurchases.
  ///
  /// In en, this message translates to:
  /// **'Select at least one credit card purchase'**
  String get balanceCheckNoEligiblePurchases;

  /// No description provided for @tooltipBalanceCheckMode.
  ///
  /// In en, this message translates to:
  /// **'Compare your statement balance with Firefly'**
  String get tooltipBalanceCheckMode;

  /// No description provided for @tooltipBalanceCheckIncludePending.
  ///
  /// In en, this message translates to:
  /// **'Include in balance check'**
  String get tooltipBalanceCheckIncludePending;

  /// No description provided for @tooltipBalanceCheckExcludeReconciled.
  ///
  /// In en, this message translates to:
  /// **'Exclude from balance check'**
  String get tooltipBalanceCheckExcludeReconciled;

  /// No description provided for @transactionReconciled.
  ///
  /// In en, this message translates to:
  /// **'Reconciled'**
  String get transactionReconciled;

  /// No description provided for @partiallyReconciled.
  ///
  /// In en, this message translates to:
  /// **'Partially reconciled'**
  String get partiallyReconciled;

  /// No description provided for @tooltipTransactionReconciled.
  ///
  /// In en, this message translates to:
  /// **'Verified against your bank statement'**
  String get tooltipTransactionReconciled;

  /// No description provided for @transactionReconciledUpdated.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation updated'**
  String get transactionReconciledUpdated;

  /// No description provided for @failedToUpdateReconciliation.
  ///
  /// In en, this message translates to:
  /// **'Failed to update reconciliation: {error}'**
  String failedToUpdateReconciliation(String error);

  /// No description provided for @reconciledFilter.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation'**
  String get reconciledFilter;

  /// No description provided for @reconciledFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All transactions'**
  String get reconciledFilterAll;

  /// No description provided for @reconciledFilterReconciled.
  ///
  /// In en, this message translates to:
  /// **'Reconciled only'**
  String get reconciledFilterReconciled;

  /// No description provided for @reconciledFilterUnreconciled.
  ///
  /// In en, this message translates to:
  /// **'Unreconciled only'**
  String get reconciledFilterUnreconciled;

  /// No description provided for @reconcile.
  ///
  /// In en, this message translates to:
  /// **'Reconcile'**
  String get reconcile;

  /// No description provided for @reconcileExpectedBalance.
  ///
  /// In en, this message translates to:
  /// **'Expected balance: {amount}'**
  String reconcileExpectedBalance(String amount);

  /// No description provided for @reconcileClickHint.
  ///
  /// In en, this message translates to:
  /// **'Click to reconcile'**
  String get reconcileClickHint;

  /// No description provided for @reconciliationTitle.
  ///
  /// In en, this message translates to:
  /// **'Reconcile account'**
  String get reconciliationTitle;

  /// No description provided for @reconciliationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Match your statement with Firefly III'**
  String get reconciliationSubtitle;

  /// No description provided for @reconciliationAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get reconciliationAccount;

  /// No description provided for @reconciliationStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get reconciliationStartDate;

  /// No description provided for @reconciliationEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get reconciliationEndDate;

  /// No description provided for @reconciliationStartBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get reconciliationStartBalance;

  /// No description provided for @reconciliationEndBalance.
  ///
  /// In en, this message translates to:
  /// **'Closing balance'**
  String get reconciliationEndBalance;

  /// No description provided for @reconciliationStart.
  ///
  /// In en, this message translates to:
  /// **'Start reconciling'**
  String get reconciliationStart;

  /// No description provided for @reconciliationRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get reconciliationRestart;

  /// No description provided for @reconciliationOptions.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation options'**
  String get reconciliationOptions;

  /// No description provided for @reconciliationGapZero.
  ///
  /// In en, this message translates to:
  /// **'Your checked transactions match the statement. You can store this reconciliation.'**
  String get reconciliationGapZero;

  /// No description provided for @reconciliationGapPositive.
  ///
  /// In en, this message translates to:
  /// **'Firefly has {amount} less than your statement. A correction transaction can be created when you store.'**
  String reconciliationGapPositive(String amount);

  /// No description provided for @reconciliationGapNegative.
  ///
  /// In en, this message translates to:
  /// **'Firefly has {amount} more than your statement. A correction transaction can be created when you store.'**
  String reconciliationGapNegative(String amount);

  /// No description provided for @reconciliationStore.
  ///
  /// In en, this message translates to:
  /// **'Store reconciliation'**
  String get reconciliationStore;

  /// No description provided for @reconciliationStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Store reconciliation?'**
  String get reconciliationStoreTitle;

  /// No description provided for @reconciliationStoreBody.
  ///
  /// In en, this message translates to:
  /// **'Mark {count} transactions as reconciled.'**
  String reconciliationStoreBody(int count);

  /// No description provided for @reconciliationCreateCorrectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Create correction transaction?'**
  String get reconciliationCreateCorrectionTitle;

  /// No description provided for @reconciliationCreateCorrectionBody.
  ///
  /// In en, this message translates to:
  /// **'There is a remaining difference of {amount}. FireRaccoon will create a reconciliation transaction to correct it.'**
  String reconciliationCreateCorrectionBody(String amount);

  /// No description provided for @reconciliationStored.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation stored'**
  String get reconciliationStored;

  /// No description provided for @reconciliationStoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to store reconciliation: {error}'**
  String reconciliationStoreFailed(String error);

  /// No description provided for @reconciliationSelectAccount.
  ///
  /// In en, this message translates to:
  /// **'Select an asset account to reconcile'**
  String get reconciliationSelectAccount;

  /// No description provided for @reconciliationInvalidBalances.
  ///
  /// In en, this message translates to:
  /// **'Enter valid opening and closing balances'**
  String get reconciliationInvalidBalances;

  /// No description provided for @reconciliationInvalidDateRange.
  ///
  /// In en, this message translates to:
  /// **'End date must be on or after the start date'**
  String get reconciliationInvalidDateRange;

  /// No description provided for @reconciliationSelectTransactions.
  ///
  /// In en, this message translates to:
  /// **'Check at least one transaction from your statement'**
  String get reconciliationSelectTransactions;

  /// No description provided for @reconciliationNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions found for this period'**
  String get reconciliationNoTransactions;

  /// No description provided for @reconciliationUnreconciled.
  ///
  /// In en, this message translates to:
  /// **'Unreconciled'**
  String get reconciliationUnreconciled;

  /// No description provided for @reconciliationFutureTransaction.
  ///
  /// In en, this message translates to:
  /// **'After period end'**
  String get reconciliationFutureTransaction;

  /// No description provided for @futureTransactions.
  ///
  /// In en, this message translates to:
  /// **'Future transactions'**
  String get futureTransactions;

  /// No description provided for @reconciliationOpenWizard.
  ///
  /// In en, this message translates to:
  /// **'Reconcile account'**
  String get reconciliationOpenWizard;

  /// No description provided for @tooltipReconciliationWizard.
  ///
  /// In en, this message translates to:
  /// **'Match transactions against your bank statement'**
  String get tooltipReconciliationWizard;

  /// No description provided for @reconciliationUseFireflyBalances.
  ///
  /// In en, this message translates to:
  /// **'Use Firefly balances'**
  String get reconciliationUseFireflyBalances;

  /// No description provided for @reconciliationLoadingBalances.
  ///
  /// In en, this message translates to:
  /// **'Loading balances from Firefly…'**
  String get reconciliationLoadingBalances;

  /// No description provided for @reconciliationBalancesFilled.
  ///
  /// In en, this message translates to:
  /// **'Balances filled from Firefly'**
  String get reconciliationBalancesFilled;

  /// No description provided for @reconciliationBalancesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load balances: {error}'**
  String reconciliationBalancesFailed(String error);

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// No description provided for @groupBy.
  ///
  /// In en, this message translates to:
  /// **'Group By'**
  String get groupBy;

  /// No description provided for @groupByDate.
  ///
  /// In en, this message translates to:
  /// **'Group by Date'**
  String get groupByDate;

  /// No description provided for @groupByAccount.
  ///
  /// In en, this message translates to:
  /// **'Group by Account'**
  String get groupByAccount;

  /// No description provided for @groupByPayee.
  ///
  /// In en, this message translates to:
  /// **'Group by Payee'**
  String get groupByPayee;

  /// No description provided for @groupByType.
  ///
  /// In en, this message translates to:
  /// **'Group by Type'**
  String get groupByType;

  /// No description provided for @groupByCategory.
  ///
  /// In en, this message translates to:
  /// **'Group by Category'**
  String get groupByCategory;

  /// No description provided for @filterAccount.
  ///
  /// In en, this message translates to:
  /// **'Filter Account'**
  String get filterAccount;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @sourceAccount.
  ///
  /// In en, this message translates to:
  /// **'Source Account'**
  String get sourceAccount;

  /// No description provided for @destinationAccount.
  ///
  /// In en, this message translates to:
  /// **'Destination Account'**
  String get destinationAccount;

  /// No description provided for @payee.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get payee;

  /// No description provided for @savingNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Saving is not supported in read-only mode.'**
  String get savingNotSupported;

  /// No description provided for @transactionDateCategory.
  ///
  /// In en, this message translates to:
  /// **'{category} · {date}'**
  String transactionDateCategory(String category, String date);

  /// No description provided for @foreignAmount.
  ///
  /// In en, this message translates to:
  /// **'({amount})'**
  String foreignAmount(String amount);

  /// No description provided for @budgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgetsTitle;

  /// No description provided for @subscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions & Recurring'**
  String get subscriptionsTitle;

  /// No description provided for @newSubscription.
  ///
  /// In en, this message translates to:
  /// **'New Subscription'**
  String get newSubscription;

  /// No description provided for @createSubscription.
  ///
  /// In en, this message translates to:
  /// **'Create Subscription'**
  String get createSubscription;

  /// No description provided for @editSubscription.
  ///
  /// In en, this message translates to:
  /// **'Edit Subscription'**
  String get editSubscription;

  /// No description provided for @subscriptionCreated.
  ///
  /// In en, this message translates to:
  /// **'Subscription created.'**
  String get subscriptionCreated;

  /// No description provided for @subscriptionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Subscription \"{name}\" deleted.'**
  String subscriptionDeleted(String name);

  /// No description provided for @failedToCreateSubscription.
  ///
  /// In en, this message translates to:
  /// **'Failed to create subscription: {error}'**
  String failedToCreateSubscription(String error);

  /// No description provided for @failedToUpdateSubscription.
  ///
  /// In en, this message translates to:
  /// **'Failed to update subscription: {error}'**
  String failedToUpdateSubscription(String error);

  /// No description provided for @failedToDeleteSubscription.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete subscription: {error}'**
  String failedToDeleteSubscription(String error);

  /// No description provided for @deleteSubscription.
  ///
  /// In en, this message translates to:
  /// **'Delete Subscription'**
  String get deleteSubscription;

  /// No description provided for @deleteSubscriptionConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the subscription \"{name}\"? This action cannot be undone.'**
  String deleteSubscriptionConfirmBody(String name);

  /// No description provided for @noSubscriptionsFound.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions found.'**
  String get noSubscriptionsFound;

  /// No description provided for @subscriptionInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get subscriptionInactive;

  /// No description provided for @subscriptionActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get subscriptionActive;

  /// No description provided for @mandatoryFields.
  ///
  /// In en, this message translates to:
  /// **'Mandatory fields'**
  String get mandatoryFields;

  /// No description provided for @optionalFields.
  ///
  /// In en, this message translates to:
  /// **'Optional fields'**
  String get optionalFields;

  /// No description provided for @minimumAmount.
  ///
  /// In en, this message translates to:
  /// **'Minimum amount'**
  String get minimumAmount;

  /// No description provided for @maximumAmount.
  ///
  /// In en, this message translates to:
  /// **'Maximum amount'**
  String get maximumAmount;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @repeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get repeats;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @skipHelp.
  ///
  /// In en, this message translates to:
  /// **'Use skip to create bi-monthly (skip = 1) or other custom intervals.'**
  String get skipHelp;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// No description provided for @endDateHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional. The subscription is expected to end on this date.'**
  String get endDateHelp;

  /// No description provided for @extensionDate.
  ///
  /// In en, this message translates to:
  /// **'Extension date'**
  String get extensionDate;

  /// No description provided for @extensionDateHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional. The subscription must be extended (or cancelled) on or before this date.'**
  String get extensionDateHelp;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @notesMarkdownHint.
  ///
  /// In en, this message translates to:
  /// **'This field supports Markdown.'**
  String get notesMarkdownHint;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatMonthly;

  /// No description provided for @repeatQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get repeatQuarterly;

  /// No description provided for @repeatHalfYear.
  ///
  /// In en, this message translates to:
  /// **'Half-year'**
  String get repeatHalfYear;

  /// No description provided for @repeatYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get repeatYearly;

  /// No description provided for @subscriptionAmountRange.
  ///
  /// In en, this message translates to:
  /// **'{min} – {max}'**
  String subscriptionAmountRange(String min, String max);

  /// No description provided for @tabSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get tabSubscriptions;

  /// No description provided for @tabRecurringTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions'**
  String get tabRecurringTransactions;

  /// No description provided for @badgeSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get badgeSubscription;

  /// No description provided for @badgeRecurringTransaction.
  ///
  /// In en, this message translates to:
  /// **'Recurring transaction'**
  String get badgeRecurringTransaction;

  /// No description provided for @addSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get addSubscription;

  /// No description provided for @addRecurringTransaction.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get addRecurringTransaction;

  /// No description provided for @noSubscriptionsOrRecurrencesFound.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions or recurring transactions found.'**
  String get noSubscriptionsOrRecurrencesFound;

  /// No description provided for @newRecurringTransaction.
  ///
  /// In en, this message translates to:
  /// **'New Recurring Transaction'**
  String get newRecurringTransaction;

  /// No description provided for @createRecurringTransaction.
  ///
  /// In en, this message translates to:
  /// **'Create Recurring Transaction'**
  String get createRecurringTransaction;

  /// No description provided for @editRecurringTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit Recurring Transaction'**
  String get editRecurringTransaction;

  /// No description provided for @recurringTransactionCreated.
  ///
  /// In en, this message translates to:
  /// **'Recurring transaction created.'**
  String get recurringTransactionCreated;

  /// No description provided for @recurringTransactionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recurring transaction \"{name}\" deleted.'**
  String recurringTransactionDeleted(String name);

  /// No description provided for @failedToCreateRecurringTransaction.
  ///
  /// In en, this message translates to:
  /// **'Failed to create recurring transaction: {error}'**
  String failedToCreateRecurringTransaction(String error);

  /// No description provided for @failedToUpdateRecurringTransaction.
  ///
  /// In en, this message translates to:
  /// **'Failed to update recurring transaction: {error}'**
  String failedToUpdateRecurringTransaction(String error);

  /// No description provided for @failedToDeleteRecurringTransaction.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete recurring transaction: {error}'**
  String failedToDeleteRecurringTransaction(String error);

  /// No description provided for @deleteRecurringTransaction.
  ///
  /// In en, this message translates to:
  /// **'Delete Recurring Transaction'**
  String get deleteRecurringTransaction;

  /// No description provided for @deleteRecurringTransactionConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the recurring transaction \"{name}\"? This action cannot be undone.'**
  String deleteRecurringTransactionConfirmBody(String name);

  /// No description provided for @noRecurringTransactionsFound.
  ///
  /// In en, this message translates to:
  /// **'No recurring transactions found.'**
  String get noRecurringTransactionsFound;

  /// No description provided for @recurringTransactionInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get recurringTransactionInactive;

  /// No description provided for @mandatoryRecurrenceFields.
  ///
  /// In en, this message translates to:
  /// **'Mandatory recurrence information'**
  String get mandatoryRecurrenceFields;

  /// No description provided for @optionalRecurrenceFields.
  ///
  /// In en, this message translates to:
  /// **'Optional recurrence information'**
  String get optionalRecurrenceFields;

  /// No description provided for @mandatoryTransactionFields.
  ///
  /// In en, this message translates to:
  /// **'Mandatory transaction information'**
  String get mandatoryTransactionFields;

  /// No description provided for @optionalTransactionFields.
  ///
  /// In en, this message translates to:
  /// **'Optional transaction information'**
  String get optionalTransactionFields;

  /// No description provided for @recurrenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get recurrenceTitle;

  /// No description provided for @firstDate.
  ///
  /// In en, this message translates to:
  /// **'First date'**
  String get firstDate;

  /// No description provided for @firstDateHelp.
  ///
  /// In en, this message translates to:
  /// **'Indicate the first expected recurrence. This must be in the future.'**
  String get firstDateHelp;

  /// No description provided for @typeOfRepetition.
  ///
  /// In en, this message translates to:
  /// **'Type of repetition'**
  String get typeOfRepetition;

  /// No description provided for @typeOfRepetitionHelp.
  ///
  /// In en, this message translates to:
  /// **'Change the first date to see more options.'**
  String get typeOfRepetitionHelp;

  /// No description provided for @weekendHandling.
  ///
  /// In en, this message translates to:
  /// **'Weekend'**
  String get weekendHandling;

  /// No description provided for @weekendCreateAnyway.
  ///
  /// In en, this message translates to:
  /// **'Just create the transaction'**
  String get weekendCreateAnyway;

  /// No description provided for @weekendSkip.
  ///
  /// In en, this message translates to:
  /// **'Do not create a transaction'**
  String get weekendSkip;

  /// No description provided for @weekendPreviousFriday.
  ///
  /// In en, this message translates to:
  /// **'Skip to the previous Friday'**
  String get weekendPreviousFriday;

  /// No description provided for @weekendNextMonday.
  ///
  /// In en, this message translates to:
  /// **'Skip to the next Monday'**
  String get weekendNextMonday;

  /// No description provided for @weekendHelp.
  ///
  /// In en, this message translates to:
  /// **'What should Firefly III do when the recurring transaction falls on a Saturday or Sunday?'**
  String get weekendHelp;

  /// No description provided for @repetitionEnds.
  ///
  /// In en, this message translates to:
  /// **'Repetition ends'**
  String get repetitionEnds;

  /// No description provided for @repeatForever.
  ///
  /// In en, this message translates to:
  /// **'Repeat forever'**
  String get repeatForever;

  /// No description provided for @repeatUntilDate.
  ///
  /// In en, this message translates to:
  /// **'Repeat until date'**
  String get repeatUntilDate;

  /// No description provided for @repeatCount.
  ///
  /// In en, this message translates to:
  /// **'Repeat a fixed number of times'**
  String get repeatCount;

  /// No description provided for @numberOfRepetitions.
  ///
  /// In en, this message translates to:
  /// **'Number of repetitions'**
  String get numberOfRepetitions;

  /// No description provided for @applyRules.
  ///
  /// In en, this message translates to:
  /// **'Apply rules'**
  String get applyRules;

  /// No description provided for @applyRulesHelp.
  ///
  /// In en, this message translates to:
  /// **'Whether to fire rules after creating each transaction.'**
  String get applyRulesHelp;

  /// No description provided for @recurrenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Recurring transaction description'**
  String get recurrenceDescription;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get repeatDaily;

  /// No description provided for @repeatNdom.
  ///
  /// In en, this message translates to:
  /// **'Monthly on nth weekday'**
  String get repeatNdom;

  /// No description provided for @recurrenceAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount}'**
  String recurrenceAmount(String amount);

  /// No description provided for @tooltipOpenSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Open subscriptions and recurring transactions.'**
  String get tooltipOpenSubscriptions;

  /// No description provided for @subscriptionsTitleRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Recurring Raids & Schedules'**
  String get subscriptionsTitleRaccoon;

  /// No description provided for @newSubscriptionRaccoon.
  ///
  /// In en, this message translates to:
  /// **'New Recurring Raid'**
  String get newSubscriptionRaccoon;

  /// No description provided for @piggyBanksTitle.
  ///
  /// In en, this message translates to:
  /// **'Piggy banks'**
  String get piggyBanksTitle;

  /// No description provided for @newPiggyBank.
  ///
  /// In en, this message translates to:
  /// **'New piggy bank'**
  String get newPiggyBank;

  /// No description provided for @createPiggyBank.
  ///
  /// In en, this message translates to:
  /// **'Create piggy bank'**
  String get createPiggyBank;

  /// No description provided for @editPiggyBank.
  ///
  /// In en, this message translates to:
  /// **'Edit piggy bank'**
  String get editPiggyBank;

  /// No description provided for @piggyBankCreated.
  ///
  /// In en, this message translates to:
  /// **'Piggy bank created.'**
  String get piggyBankCreated;

  /// No description provided for @piggyBankDeleted.
  ///
  /// In en, this message translates to:
  /// **'Piggy bank \"{name}\" deleted.'**
  String piggyBankDeleted(String name);

  /// No description provided for @failedToCreatePiggyBank.
  ///
  /// In en, this message translates to:
  /// **'Failed to create piggy bank: {error}'**
  String failedToCreatePiggyBank(String error);

  /// No description provided for @failedToUpdatePiggyBank.
  ///
  /// In en, this message translates to:
  /// **'Failed to update piggy bank: {error}'**
  String failedToUpdatePiggyBank(String error);

  /// No description provided for @failedToDeletePiggyBank.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete piggy bank: {error}'**
  String failedToDeletePiggyBank(String error);

  /// No description provided for @deletePiggyBank.
  ///
  /// In en, this message translates to:
  /// **'Delete piggy bank'**
  String get deletePiggyBank;

  /// No description provided for @deletePiggyBankConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the piggy bank \"{name}\"? This action cannot be undone.'**
  String deletePiggyBankConfirmBody(String name);

  /// No description provided for @noPiggyBanksFound.
  ///
  /// In en, this message translates to:
  /// **'No piggy banks found.'**
  String get noPiggyBanksFound;

  /// No description provided for @targetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get targetAmount;

  /// No description provided for @piggyBankCurrencyHelp.
  ///
  /// In en, this message translates to:
  /// **'Piggy banks can only save money in a single currency.'**
  String get piggyBankCurrencyHelp;

  /// No description provided for @saveOnAccounts.
  ///
  /// In en, this message translates to:
  /// **'Save on account(s)'**
  String get saveOnAccounts;

  /// No description provided for @piggyBankAccountsHelp.
  ///
  /// In en, this message translates to:
  /// **'Only accounts that use the previously selected currency will be accepted.'**
  String get piggyBankAccountsHelp;

  /// No description provided for @targetDate.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get targetDate;

  /// No description provided for @targetDateHelp.
  ///
  /// In en, this message translates to:
  /// **'The date you intend to finish saving money.'**
  String get targetDateHelp;

  /// No description provided for @accountGroupDefaultAssets.
  ///
  /// In en, this message translates to:
  /// **'Default asset accounts'**
  String get accountGroupDefaultAssets;

  /// No description provided for @accountGroupSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings accounts'**
  String get accountGroupSavings;

  /// No description provided for @accountGroupCash.
  ///
  /// In en, this message translates to:
  /// **'Cash wallets'**
  String get accountGroupCash;

  /// No description provided for @accountGroupLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get accountGroupLiabilities;

  /// No description provided for @selectAtLeastOneAccount.
  ///
  /// In en, this message translates to:
  /// **'Select at least one account.'**
  String get selectAtLeastOneAccount;

  /// No description provided for @piggyBankProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {target}'**
  String piggyBankProgress(String current, String target);

  /// No description provided for @piggyBanksTitleRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Mini Stashes'**
  String get piggyBanksTitleRaccoon;

  /// No description provided for @newPiggyBankRaccoon.
  ///
  /// In en, this message translates to:
  /// **'New Mini Stash'**
  String get newPiggyBankRaccoon;

  /// No description provided for @newBudget.
  ///
  /// In en, this message translates to:
  /// **'New Budget'**
  String get newBudget;

  /// No description provided for @deleteBudget.
  ///
  /// In en, this message translates to:
  /// **'Delete Budget'**
  String get deleteBudget;

  /// No description provided for @deleteBudgetMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteBudgetMessage(String name);

  /// No description provided for @budgetDeleted.
  ///
  /// In en, this message translates to:
  /// **'Budget \"{name}\" deleted.'**
  String budgetDeleted(String name);

  /// No description provided for @failedToDeleteBudget.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete budget: {error}'**
  String failedToDeleteBudget(String error);

  /// No description provided for @spent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spent;

  /// No description provided for @ofAmount.
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String ofAmount(String amount);

  /// No description provided for @overBudget.
  ///
  /// In en, this message translates to:
  /// **'{amount} over budget'**
  String overBudget(String amount);

  /// No description provided for @leftInBudget.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String leftInBudget(String amount);

  /// No description provided for @budgetPerPeriod.
  ///
  /// In en, this message translates to:
  /// **'{amount} per {period}'**
  String budgetPerPeriod(String amount, String period);

  /// No description provided for @budgetLimitForPeriod.
  ///
  /// In en, this message translates to:
  /// **'{amount} for {period}'**
  String budgetLimitForPeriod(String amount, String period);

  /// No description provided for @budgetCadenceDaily.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get budgetCadenceDaily;

  /// No description provided for @budgetCadenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get budgetCadenceWeekly;

  /// No description provided for @budgetCadenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get budgetCadenceMonthly;

  /// No description provided for @budgetCadenceQuarterly.
  ///
  /// In en, this message translates to:
  /// **'quarter'**
  String get budgetCadenceQuarterly;

  /// No description provided for @budgetCadenceHalfYear.
  ///
  /// In en, this message translates to:
  /// **'half-year'**
  String get budgetCadenceHalfYear;

  /// No description provided for @budgetCadenceYearly.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get budgetCadenceYearly;

  /// No description provided for @viewPeriod.
  ///
  /// In en, this message translates to:
  /// **'View period'**
  String get viewPeriod;

  /// No description provided for @budgetAmount.
  ///
  /// In en, this message translates to:
  /// **'Budget amount'**
  String get budgetAmount;

  /// No description provided for @editBudget.
  ///
  /// In en, this message translates to:
  /// **'Edit Budget'**
  String get editBudget;

  /// No description provided for @createBudget.
  ///
  /// In en, this message translates to:
  /// **'Create Budget'**
  String get createBudget;

  /// No description provided for @createPayee.
  ///
  /// In en, this message translates to:
  /// **'Create Payee'**
  String get createPayee;

  /// No description provided for @createCategory.
  ///
  /// In en, this message translates to:
  /// **'Create Category'**
  String get createCategory;

  /// No description provided for @budgetLimit.
  ///
  /// In en, this message translates to:
  /// **'Budget limit'**
  String get budgetLimit;

  /// No description provided for @autoBudget.
  ///
  /// In en, this message translates to:
  /// **'Auto-budget amount'**
  String get autoBudget;

  /// No description provided for @budgetAmountMode.
  ///
  /// In en, this message translates to:
  /// **'Limit type'**
  String get budgetAmountMode;

  /// No description provided for @budgetAmountModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Repeating period'**
  String get budgetAmountModeAuto;

  /// No description provided for @budgetAmountModeDateRange.
  ///
  /// In en, this message translates to:
  /// **'Fixed date range'**
  String get budgetAmountModeDateRange;

  /// No description provided for @budgetAmountModeNone.
  ///
  /// In en, this message translates to:
  /// **'No amount'**
  String get budgetAmountModeNone;

  /// No description provided for @budgetRepeatPeriod.
  ///
  /// In en, this message translates to:
  /// **'Repeats every'**
  String get budgetRepeatPeriod;

  /// No description provided for @budgetAutoType.
  ///
  /// In en, this message translates to:
  /// **'Auto-budget behavior'**
  String get budgetAutoType;

  /// No description provided for @budgetAutoTypeReset.
  ///
  /// In en, this message translates to:
  /// **'Reset each period'**
  String get budgetAutoTypeReset;

  /// No description provided for @budgetAutoTypeRollover.
  ///
  /// In en, this message translates to:
  /// **'Roll over unused'**
  String get budgetAutoTypeRollover;

  /// No description provided for @budgetAutoTypeAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Adjust to spending'**
  String get budgetAutoTypeAdjusted;

  /// No description provided for @budgetAutoTypeNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get budgetAutoTypeNone;

  /// No description provided for @budgetActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get budgetActive;

  /// No description provided for @budgetPeriodDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get budgetPeriodDaily;

  /// No description provided for @budgetPeriodWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get budgetPeriodWeekly;

  /// No description provided for @budgetPeriodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get budgetPeriodMonthly;

  /// No description provided for @budgetPeriodQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get budgetPeriodQuarterly;

  /// No description provided for @budgetPeriodHalfYear.
  ///
  /// In en, this message translates to:
  /// **'Every half year'**
  String get budgetPeriodHalfYear;

  /// No description provided for @budgetPeriodYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get budgetPeriodYearly;

  /// No description provided for @tooltipBudgetAmountMode.
  ///
  /// In en, this message translates to:
  /// **'Choose a repeating auto-budget, a fixed date range, or no limit'**
  String get tooltipBudgetAmountMode;

  /// No description provided for @tooltipBudgetRepeatPeriod.
  ///
  /// In en, this message translates to:
  /// **'How often the budget amount applies (e.g. monthly)'**
  String get tooltipBudgetRepeatPeriod;

  /// No description provided for @tooltipBudgetAutoType.
  ///
  /// In en, this message translates to:
  /// **'What happens at the start of each budget period'**
  String get tooltipBudgetAutoType;

  /// No description provided for @tooltipBudgetStartDate.
  ///
  /// In en, this message translates to:
  /// **'First day this budget limit applies'**
  String get tooltipBudgetStartDate;

  /// No description provided for @tooltipBudgetEndDate.
  ///
  /// In en, this message translates to:
  /// **'Last day this budget limit applies'**
  String get tooltipBudgetEndDate;

  /// No description provided for @tooltipBudgetActive.
  ///
  /// In en, this message translates to:
  /// **'Inactive budgets are hidden from default views in Firefly'**
  String get tooltipBudgetActive;

  /// No description provided for @tooltipBudgetNotes.
  ///
  /// In en, this message translates to:
  /// **'Optional notes stored with the budget'**
  String get tooltipBudgetNotes;

  /// No description provided for @tooltipBudgetCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency for the budget amount'**
  String get tooltipBudgetCurrency;

  /// No description provided for @expensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTitle;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @byCategory.
  ///
  /// In en, this message translates to:
  /// **'By Category'**
  String get byCategory;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// No description provided for @allTypes.
  ///
  /// In en, this message translates to:
  /// **'All Types'**
  String get allTypes;

  /// No description provided for @expensesFilter.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesFilter;

  /// No description provided for @transfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transfers;

  /// No description provided for @expensePeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get expensePeriodWeek;

  /// No description provided for @expensePeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get expensePeriodMonth;

  /// No description provided for @expensePeriodQuarter.
  ///
  /// In en, this message translates to:
  /// **'This Quarter'**
  String get expensePeriodQuarter;

  /// No description provided for @expensePeriodSemester.
  ///
  /// In en, this message translates to:
  /// **'This Semester'**
  String get expensePeriodSemester;

  /// No description provided for @expensePeriodYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get expensePeriodYear;

  /// No description provided for @expensePeriodAll.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get expensePeriodAll;

  /// No description provided for @dashboardPeriodThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get dashboardPeriodThisWeek;

  /// No description provided for @dashboardPeriodLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get dashboardPeriodLastWeek;

  /// No description provided for @dashboardPeriodThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get dashboardPeriodThisMonth;

  /// No description provided for @dashboardPeriodLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get dashboardPeriodLastMonth;

  /// No description provided for @dashboardPeriodThisQuarter.
  ///
  /// In en, this message translates to:
  /// **'This quarter'**
  String get dashboardPeriodThisQuarter;

  /// No description provided for @dashboardPeriodLastQuarter.
  ///
  /// In en, this message translates to:
  /// **'Last quarter'**
  String get dashboardPeriodLastQuarter;

  /// No description provided for @dashboardPeriodThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get dashboardPeriodThisYear;

  /// No description provided for @dashboardPeriodLastYear.
  ///
  /// In en, this message translates to:
  /// **'Last year'**
  String get dashboardPeriodLastYear;

  /// No description provided for @dashboardPeriodLast2Years.
  ///
  /// In en, this message translates to:
  /// **'Last 2 years'**
  String get dashboardPeriodLast2Years;

  /// No description provided for @dashboardPeriodLast5Years.
  ///
  /// In en, this message translates to:
  /// **'Last 5 years'**
  String get dashboardPeriodLast5Years;

  /// No description provided for @dashboardPeriodLast10Years.
  ///
  /// In en, this message translates to:
  /// **'Last 10 years'**
  String get dashboardPeriodLast10Years;

  /// No description provided for @dashboardPeriodAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get dashboardPeriodAll;

  /// No description provided for @deltaComparisonPreviousWeek.
  ///
  /// In en, this message translates to:
  /// **'previous week'**
  String get deltaComparisonPreviousWeek;

  /// No description provided for @deltaComparisonPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'previous month'**
  String get deltaComparisonPreviousMonth;

  /// No description provided for @deltaComparisonPreviousQuarter.
  ///
  /// In en, this message translates to:
  /// **'previous quarter'**
  String get deltaComparisonPreviousQuarter;

  /// No description provided for @deltaComparisonPreviousYear.
  ///
  /// In en, this message translates to:
  /// **'previous year'**
  String get deltaComparisonPreviousYear;

  /// No description provided for @deltaComparisonPrevious2Years.
  ///
  /// In en, this message translates to:
  /// **'previous 2 years'**
  String get deltaComparisonPrevious2Years;

  /// No description provided for @deltaComparisonPrevious5Years.
  ///
  /// In en, this message translates to:
  /// **'previous 5 years'**
  String get deltaComparisonPrevious5Years;

  /// No description provided for @deltaComparisonPrevious10Years.
  ///
  /// In en, this message translates to:
  /// **'previous 10 years'**
  String get deltaComparisonPrevious10Years;

  /// No description provided for @deltaComparisonCustomPeriod.
  ///
  /// In en, this message translates to:
  /// **'previous period'**
  String get deltaComparisonCustomPeriod;

  /// No description provided for @noChangeVsComparisonPeriod.
  ///
  /// In en, this message translates to:
  /// **'No change vs {period}'**
  String noChangeVsComparisonPeriod(String period);

  /// No description provided for @newActivityVsComparisonPeriod.
  ///
  /// In en, this message translates to:
  /// **'New activity vs {period}'**
  String newActivityVsComparisonPeriod(String period);

  /// No description provided for @percentVsComparisonPeriod.
  ///
  /// In en, this message translates to:
  /// **'{arrow}{percent}% vs {period}'**
  String percentVsComparisonPeriod(String arrow, String percent, String period);

  /// No description provided for @dateRangeSeparator.
  ///
  /// In en, this message translates to:
  /// **'–'**
  String get dateRangeSeparator;

  /// No description provided for @dateEllipsis.
  ///
  /// In en, this message translates to:
  /// **'…'**
  String get dateEllipsis;

  /// No description provided for @projectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Projection'**
  String get projectionTitle;

  /// No description provided for @projectedBalance.
  ///
  /// In en, this message translates to:
  /// **'Projected balance'**
  String get projectedBalance;

  /// No description provided for @visualization.
  ///
  /// In en, this message translates to:
  /// **'Visualization'**
  String get visualization;

  /// No description provided for @parameters.
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get parameters;

  /// No description provided for @predictedBalances.
  ///
  /// In en, this message translates to:
  /// **'Predicted balances · {period}'**
  String predictedBalances(String period);

  /// No description provided for @noAccountsLoaded.
  ///
  /// In en, this message translates to:
  /// **'No accounts loaded'**
  String get noAccountsLoaded;

  /// No description provided for @scenarioSummary.
  ///
  /// In en, this message translates to:
  /// **'Scenario summary'**
  String get scenarioSummary;

  /// No description provided for @nowAmount.
  ///
  /// In en, this message translates to:
  /// **'now {amount}'**
  String nowAmount(String amount);

  /// No description provided for @worstCase.
  ///
  /// In en, this message translates to:
  /// **'Worst case'**
  String get worstCase;

  /// No description provided for @expected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get expected;

  /// No description provided for @bestCase.
  ///
  /// In en, this message translates to:
  /// **'Best case'**
  String get bestCase;

  /// No description provided for @moveSliderToSeeImpact.
  ///
  /// In en, this message translates to:
  /// **'Move the slider to see impact'**
  String get moveSliderToSeeImpact;

  /// No description provided for @whatIfImpact.
  ///
  /// In en, this message translates to:
  /// **'+{amount} over {period}'**
  String whatIfImpact(String amount, String period);

  /// No description provided for @projectionPeriod3Months.
  ///
  /// In en, this message translates to:
  /// **'3 Months'**
  String get projectionPeriod3Months;

  /// No description provided for @projectionPeriod6Months.
  ///
  /// In en, this message translates to:
  /// **'6 Months'**
  String get projectionPeriod6Months;

  /// No description provided for @projectionPeriod1Year.
  ///
  /// In en, this message translates to:
  /// **'1 Year'**
  String get projectionPeriod1Year;

  /// No description provided for @projectionPeriod3Years.
  ///
  /// In en, this message translates to:
  /// **'3 Years'**
  String get projectionPeriod3Years;

  /// No description provided for @projectionTypeSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings rate'**
  String get projectionTypeSavings;

  /// No description provided for @projectionTypeCompound.
  ///
  /// In en, this message translates to:
  /// **'Compound growth'**
  String get projectionTypeCompound;

  /// No description provided for @projectionTypePortfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio (volatile)'**
  String get projectionTypePortfolio;

  /// No description provided for @projectionTypeCashflow.
  ///
  /// In en, this message translates to:
  /// **'Cash flow'**
  String get projectionTypeCashflow;

  /// No description provided for @projectionTypeSavingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Linear projection from your historical net savings'**
  String get projectionTypeSavingsDesc;

  /// No description provided for @projectionTypeCompoundDesc.
  ///
  /// In en, this message translates to:
  /// **'Balance grows with compound interest plus contributions'**
  String get projectionTypeCompoundDesc;

  /// No description provided for @projectionTypePortfolioDesc.
  ///
  /// In en, this message translates to:
  /// **'Expected return with worst/best bands from volatility'**
  String get projectionTypePortfolioDesc;

  /// No description provided for @projectionTypeCashflowDesc.
  ///
  /// In en, this message translates to:
  /// **'Income minus expenses with discretionary adjustments'**
  String get projectionTypeCashflowDesc;

  /// No description provided for @chartStyleFan.
  ///
  /// In en, this message translates to:
  /// **'Fan chart'**
  String get chartStyleFan;

  /// No description provided for @chartStyleLines.
  ///
  /// In en, this message translates to:
  /// **'Three lines'**
  String get chartStyleLines;

  /// No description provided for @chartStyleScenarios.
  ///
  /// In en, this message translates to:
  /// **'Scenario cards'**
  String get chartStyleScenarios;

  /// No description provided for @whatIfSpending.
  ///
  /// In en, this message translates to:
  /// **'What-if spending'**
  String get whatIfSpending;

  /// No description provided for @annualReturn.
  ///
  /// In en, this message translates to:
  /// **'Annual return'**
  String get annualReturn;

  /// No description provided for @volatility.
  ///
  /// In en, this message translates to:
  /// **'Volatility'**
  String get volatility;

  /// No description provided for @projectionAlertLiability.
  ///
  /// In en, this message translates to:
  /// **'At worst case, {name} may reach {balance} sooner than expected.'**
  String projectionAlertLiability(String name, String balance);

  /// No description provided for @projectionAlertBelowZero.
  ///
  /// In en, this message translates to:
  /// **'Worst-case projection dips below zero within the selected period.'**
  String get projectionAlertBelowZero;

  /// No description provided for @projectionAlertActionLiability.
  ///
  /// In en, this message translates to:
  /// **'Consider moving funds from a savings account.'**
  String get projectionAlertActionLiability;

  /// No description provided for @projectionAlertActionSpending.
  ///
  /// In en, this message translates to:
  /// **'Review discretionary spending or increase savings.'**
  String get projectionAlertActionSpending;

  /// No description provided for @confirmTypeWord.
  ///
  /// In en, this message translates to:
  /// **'Type '**
  String get confirmTypeWord;

  /// No description provided for @confirmToConfirm.
  ///
  /// In en, this message translates to:
  /// **' to confirm:'**
  String get confirmToConfirm;

  /// No description provided for @confirmHint.
  ///
  /// In en, this message translates to:
  /// **'Type the word above…'**
  String get confirmHint;

  /// No description provided for @currencyPair.
  ///
  /// In en, this message translates to:
  /// **'{name} ({symbol})'**
  String currencyPair(String name, String symbol);

  /// No description provided for @budgetSpentFraction.
  ///
  /// In en, this message translates to:
  /// **'{spent} / {total}'**
  String budgetSpentFraction(String spent, String total);

  /// No description provided for @editAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit Account'**
  String get editAccount;

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @filterAllShort.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAllShort;

  /// No description provided for @filterAssetsShort.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get filterAssetsShort;

  /// No description provided for @filterLiabilitiesShort.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get filterLiabilitiesShort;

  /// No description provided for @showInactiveAccounts.
  ///
  /// In en, this message translates to:
  /// **'Show inactive accounts'**
  String get showInactiveAccounts;

  /// No description provided for @showInactiveAccountsShort.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get showInactiveAccountsShort;

  /// No description provided for @accountInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get accountInactive;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @showingTransactionsOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Showing {loaded} of {total} transactions'**
  String showingTransactionsOfTotal(int loaded, int total);

  /// No description provided for @transactionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} transactions'**
  String transactionsCount(int count);

  /// No description provided for @oneTransaction.
  ///
  /// In en, this message translates to:
  /// **'1 transaction'**
  String get oneTransaction;

  /// No description provided for @deleteBudgetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the budget \"{name}\"? This action cannot be undone.'**
  String deleteBudgetConfirmBody(String name);

  /// No description provided for @scrollForMore.
  ///
  /// In en, this message translates to:
  /// **'Scroll for more…'**
  String get scrollForMore;

  /// No description provided for @noTransactionsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No transactions match the current filters.'**
  String get noTransactionsMatchFilters;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @totalSpentPeriod.
  ///
  /// In en, this message translates to:
  /// **'Total spent this period'**
  String get totalSpentPeriod;

  /// No description provided for @totalIncomePeriod.
  ///
  /// In en, this message translates to:
  /// **'Total income this period'**
  String get totalIncomePeriod;

  /// No description provided for @totalTransferredPeriod.
  ///
  /// In en, this message translates to:
  /// **'Total transferred this period'**
  String get totalTransferredPeriod;

  /// No description provided for @totalPeriod.
  ///
  /// In en, this message translates to:
  /// **'Total this period'**
  String get totalPeriod;

  /// No description provided for @volatilityUncertainty.
  ///
  /// In en, this message translates to:
  /// **'Volatility / uncertainty'**
  String get volatilityUncertainty;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get editTransaction;

  /// No description provided for @newDeposit.
  ///
  /// In en, this message translates to:
  /// **'Create new deposit'**
  String get newDeposit;

  /// No description provided for @editDeposit.
  ///
  /// In en, this message translates to:
  /// **'Edit deposit'**
  String get editDeposit;

  /// No description provided for @newWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Create new withdrawal'**
  String get newWithdrawal;

  /// No description provided for @editWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Edit withdrawal'**
  String get editWithdrawal;

  /// No description provided for @newTransfer.
  ///
  /// In en, this message translates to:
  /// **'Create new transfer'**
  String get newTransfer;

  /// No description provided for @editTransfer.
  ///
  /// In en, this message translates to:
  /// **'Edit transfer'**
  String get editTransfer;

  /// No description provided for @revenueAccount.
  ///
  /// In en, this message translates to:
  /// **'Revenue account'**
  String get revenueAccount;

  /// No description provided for @assetAccount.
  ///
  /// In en, this message translates to:
  /// **'Asset account'**
  String get assetAccount;

  /// No description provided for @expenseAccount.
  ///
  /// In en, this message translates to:
  /// **'Expense account'**
  String get expenseAccount;

  /// No description provided for @expenseLabel.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expenseLabel;

  /// No description provided for @transactionTypeDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get transactionTypeDeposit;

  /// No description provided for @transactionTypeWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get transactionTypeWithdrawal;

  /// No description provided for @transactionTypeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transactionTypeTransfer;

  /// No description provided for @dataAndLoading.
  ///
  /// In en, this message translates to:
  /// **'Data & loading'**
  String get dataAndLoading;

  /// No description provided for @transactionPageSize.
  ///
  /// In en, this message translates to:
  /// **'Transactions per page'**
  String get transactionPageSize;

  /// No description provided for @transactionPageSizeDescription.
  ///
  /// In en, this message translates to:
  /// **'How many transactions to load each time you scroll. Applies to the transactions list.'**
  String get transactionPageSizeDescription;

  /// No description provided for @transactionPageSizeValue.
  ///
  /// In en, this message translates to:
  /// **'{count} per page'**
  String transactionPageSizeValue(int count);

  /// No description provided for @defaultPeriod.
  ///
  /// In en, this message translates to:
  /// **'Default period'**
  String get defaultPeriod;

  /// No description provided for @defaultPeriodDescription.
  ///
  /// In en, this message translates to:
  /// **'Applied when opening the dashboard, expenses, income, transfers, and transactions.'**
  String get defaultPeriodDescription;

  /// No description provided for @customDateRange.
  ///
  /// In en, this message translates to:
  /// **'Custom Range'**
  String get customDateRange;

  /// No description provided for @pickDates.
  ///
  /// In en, this message translates to:
  /// **'Pick Dates'**
  String get pickDates;

  /// No description provided for @budgetStatusOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get budgetStatusOnTrack;

  /// No description provided for @budgetStatusOver.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get budgetStatusOver;

  /// No description provided for @whatIfCutSpending.
  ///
  /// In en, this message translates to:
  /// **'What if I cut discretionary spending by {percent}%?'**
  String whatIfCutSpending(int percent);

  /// No description provided for @usesAveragePatterns.
  ///
  /// In en, this message translates to:
  /// **'Uses your average income and expense patterns from transactions.'**
  String get usesAveragePatterns;

  /// No description provided for @historicalNetSavingsNote.
  ///
  /// In en, this message translates to:
  /// **'Based on historical net savings. Adjust uncertainty to widen or narrow the band.'**
  String get historicalNetSavingsNote;

  /// No description provided for @accountFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountFilterLabel;

  /// No description provided for @noTransactionsForBudget.
  ///
  /// In en, this message translates to:
  /// **'No transactions for this budget.'**
  String get noTransactionsForBudget;

  /// No description provided for @noTransactionsForAccount.
  ///
  /// In en, this message translates to:
  /// **'No transactions for this account.'**
  String get noTransactionsForAccount;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the account \"{name}\"? This action cannot be undone.'**
  String deleteAccountConfirmBody(String name);

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account \"{name}\" deleted.'**
  String accountDeleted(String name);

  /// No description provided for @failedToDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account: {error}'**
  String failedToDeleteAccount(String error);

  /// No description provided for @budgetNameHint.
  ///
  /// In en, this message translates to:
  /// **'Budget name'**
  String get budgetNameHint;

  /// No description provided for @budgetAmountWithSymbol.
  ///
  /// In en, this message translates to:
  /// **'Budget Amount ({symbol})'**
  String budgetAmountWithSymbol(String symbol);

  /// No description provided for @chartLegendActual.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get chartLegendActual;

  /// No description provided for @chartLegendWorst.
  ///
  /// In en, this message translates to:
  /// **'Worst'**
  String get chartLegendWorst;

  /// No description provided for @chartLegendBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get chartLegendBest;

  /// No description provided for @chartLegendWorstBest.
  ///
  /// In en, this message translates to:
  /// **'Worst ↔ Best'**
  String get chartLegendWorstBest;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get today;

  /// No description provided for @mcpServer.
  ///
  /// In en, this message translates to:
  /// **'MCP server'**
  String get mcpServer;

  /// No description provided for @mcpStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String mcpStatusFailed(String error);

  /// No description provided for @mcpStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running on port {port}'**
  String mcpStatusRunning(int port);

  /// No description provided for @mcpStatusStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get mcpStatusStarting;

  /// No description provided for @mcpStatusNoKeys.
  ///
  /// In en, this message translates to:
  /// **'No agent keys yet, so the server is idle'**
  String get mcpStatusNoKeys;

  /// No description provided for @mcpAgentKeys.
  ///
  /// In en, this message translates to:
  /// **'Agent keys'**
  String get mcpAgentKeys;

  /// No description provided for @mcpAgentKeysHint.
  ///
  /// In en, this message translates to:
  /// **'Agents authenticate with a FireRaccoon key, not your Firefly III token. Each key acts as the person who created it.'**
  String get mcpAgentKeysHint;

  /// No description provided for @mcpNoAgentKeys.
  ///
  /// In en, this message translates to:
  /// **'No agent keys yet'**
  String get mcpNoAgentKeys;

  /// No description provided for @mcpCreateKey.
  ///
  /// In en, this message translates to:
  /// **'Create key'**
  String get mcpCreateKey;

  /// No description provided for @mcpKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get mcpKeyLabel;

  /// No description provided for @mcpKeyLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Claude Desktop'**
  String get mcpKeyLabelHint;

  /// No description provided for @mcpKeyIssuedTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy your agent key'**
  String get mcpKeyIssuedTitle;

  /// No description provided for @mcpForgetKey.
  ///
  /// In en, this message translates to:
  /// **'Forget this key'**
  String get mcpForgetKey;

  /// No description provided for @mcpPickKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Which key should it use?'**
  String get mcpPickKeyTitle;

  /// No description provided for @mcpWithoutKey.
  ///
  /// In en, this message translates to:
  /// **'Without a key'**
  String get mcpWithoutKey;

  /// No description provided for @mcpShowKey.
  ///
  /// In en, this message translates to:
  /// **'Show key'**
  String get mcpShowKey;

  /// No description provided for @mcpKeyNotRecoverable.
  ///
  /// In en, this message translates to:
  /// **'This key was created before keys could be read back. Revoke it and create a new one.'**
  String get mcpKeyNotRecoverable;

  /// No description provided for @mcpKeyIssuedBody.
  ///
  /// In en, this message translates to:
  /// **'Paste this into your MCP client as initialize.params.apiKey, or set FIRERACCOON_API_KEY. You can reopen it later from this list.'**
  String get mcpKeyIssuedBody;

  /// No description provided for @mcpCopyKey.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get mcpCopyKey;

  /// No description provided for @mcpKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Agent key copied'**
  String get mcpKeyCopied;

  /// No description provided for @mcpRevokeKey.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get mcpRevokeKey;

  /// No description provided for @mcpRevokeKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke agent key?'**
  String get mcpRevokeKeyTitle;

  /// No description provided for @mcpRevokeKeyBody.
  ///
  /// In en, this message translates to:
  /// **'{label} stops working immediately and its open connections drop.'**
  String mcpRevokeKeyBody(String label);

  /// No description provided for @mcpKeyCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String mcpKeyCreatedAt(String date);

  /// No description provided for @mcpKeyRevokedAt.
  ///
  /// In en, this message translates to:
  /// **'Revoked {date}'**
  String mcpKeyRevokedAt(String date);

  /// No description provided for @mcpServerCredentials.
  ///
  /// In en, this message translates to:
  /// **'MCP server credentials'**
  String get mcpServerCredentials;

  /// No description provided for @mcpAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get mcpAddress;

  /// No description provided for @mcpNotRunning.
  ///
  /// In en, this message translates to:
  /// **'Not running'**
  String get mcpNotRunning;

  /// No description provided for @mcpAuthParameter.
  ///
  /// In en, this message translates to:
  /// **'Auth parameter'**
  String get mcpAuthParameter;

  /// No description provided for @mcpTransportLabel.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get mcpTransportLabel;

  /// No description provided for @mcpTransportTcp.
  ///
  /// In en, this message translates to:
  /// **'TCP (localhost only)'**
  String get mcpTransportTcp;

  /// No description provided for @mcpCopyConnection.
  ///
  /// In en, this message translates to:
  /// **'Copy connection details'**
  String get mcpCopyConnection;

  /// No description provided for @mcpConnectionCopied.
  ///
  /// In en, this message translates to:
  /// **'Connection details copied'**
  String get mcpConnectionCopied;

  /// No description provided for @mcpKeyLastUsedAt.
  ///
  /// In en, this message translates to:
  /// **'Last used {date}'**
  String mcpKeyLastUsedAt(String date);

  /// No description provided for @mcpKeyNeverUsed.
  ///
  /// In en, this message translates to:
  /// **'Never used'**
  String get mcpKeyNeverUsed;

  /// No description provided for @mcpKeyOwner.
  ///
  /// In en, this message translates to:
  /// **'Acts as {name} ({role})'**
  String mcpKeyOwner(String name, String role);

  /// No description provided for @transactionDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get transactionDate;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreOptions;

  /// No description provided for @foreignAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Foreign amount'**
  String get foreignAmountLabel;

  /// No description provided for @budgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetLabel;

  /// No description provided for @piggyBank.
  ///
  /// In en, this message translates to:
  /// **'Piggy bank'**
  String get piggyBank;

  /// No description provided for @noPiggyBank.
  ///
  /// In en, this message translates to:
  /// **'(no piggy bank)'**
  String get noPiggyBank;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @interestDate.
  ///
  /// In en, this message translates to:
  /// **'Interest date'**
  String get interestDate;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'(none)'**
  String get none;

  /// No description provided for @attachmentsNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Attachments are not supported in this app yet.'**
  String get attachmentsNotSupported;

  /// No description provided for @deleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Delete Transaction'**
  String get deleteTransaction;

  /// No description provided for @deleteTransactionConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{description}\"? This action cannot be undone.'**
  String deleteTransactionConfirmBody(String description);

  /// No description provided for @transactionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted.'**
  String get transactionDeleted;

  /// No description provided for @failedToDeleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete transaction: {error}'**
  String failedToDeleteTransaction(String error);

  /// No description provided for @transactionSaved.
  ///
  /// In en, this message translates to:
  /// **'Transaction saved.'**
  String get transactionSaved;

  /// No description provided for @failedToSaveTransaction.
  ///
  /// In en, this message translates to:
  /// **'Failed to save transaction: {error}'**
  String failedToSaveTransaction(String error);

  /// No description provided for @transactionDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Transaction duplicated.'**
  String get transactionDuplicated;

  /// No description provided for @failedToDuplicateTransaction.
  ///
  /// In en, this message translates to:
  /// **'Failed to duplicate transaction: {error}'**
  String failedToDuplicateTransaction(String error);

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @newTransaction.
  ///
  /// In en, this message translates to:
  /// **'New Transaction'**
  String get newTransaction;

  /// No description provided for @transactionCreated.
  ///
  /// In en, this message translates to:
  /// **'Transaction created.'**
  String get transactionCreated;

  /// No description provided for @failedToCreateTransaction.
  ///
  /// In en, this message translates to:
  /// **'Failed to create transaction: {error}'**
  String failedToCreateTransaction(String error);

  /// No description provided for @transactionFormIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Please fill in description, amount, and both accounts.'**
  String get transactionFormIncomplete;

  /// No description provided for @transactionInformation.
  ///
  /// In en, this message translates to:
  /// **'Transaction information'**
  String get transactionInformation;

  /// No description provided for @addAnotherSplit.
  ///
  /// In en, this message translates to:
  /// **'Add another split'**
  String get addAnotherSplit;

  /// No description provided for @splitLabel.
  ///
  /// In en, this message translates to:
  /// **'Split {number}'**
  String splitLabel(int number);

  /// No description provided for @removeSplit.
  ///
  /// In en, this message translates to:
  /// **'Remove split'**
  String get removeSplit;

  /// No description provided for @splitCount.
  ///
  /// In en, this message translates to:
  /// **'{count} splits'**
  String splitCount(int count);

  /// No description provided for @splitCategoriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} categories'**
  String splitCategoriesCount(int count);

  /// No description provided for @splitMainAmount.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get splitMainAmount;

  /// No description provided for @tooltipSplitMainAmount.
  ///
  /// In en, this message translates to:
  /// **'Main transaction total. Split amounts must add up to this before saving.'**
  String get tooltipSplitMainAmount;

  /// No description provided for @splitTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Split total: {amount}'**
  String splitTotalLabel(String amount);

  /// No description provided for @splitRemainder.
  ///
  /// In en, this message translates to:
  /// **'Remainder: {amount}'**
  String splitRemainder(String amount);

  /// No description provided for @splitsTotalMismatch.
  ///
  /// In en, this message translates to:
  /// **'Split amounts must total {expected}.'**
  String splitsTotalMismatch(String expected);

  /// No description provided for @splitOptionalFields.
  ///
  /// In en, this message translates to:
  /// **'Optional fields'**
  String get splitOptionalFields;

  /// No description provided for @foreignCurrency.
  ///
  /// In en, this message translates to:
  /// **'Foreign currency'**
  String get foreignCurrency;

  /// No description provided for @noSubscriptionsHint.
  ///
  /// In en, this message translates to:
  /// **'You have no subscriptions yet. Create some on the Subscriptions page to link recurring expenses.'**
  String get noSubscriptionsHint;

  /// No description provided for @incomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get incomeTitle;

  /// No description provided for @transfersTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transfersTitle;

  /// No description provided for @newTransferAction.
  ///
  /// In en, this message translates to:
  /// **'New Transfer'**
  String get newTransferAction;

  /// No description provided for @liabilitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get liabilitiesTitle;

  /// No description provided for @newIncome.
  ///
  /// In en, this message translates to:
  /// **'New Income'**
  String get newIncome;

  /// No description provided for @newIncomeRaccoon.
  ///
  /// In en, this message translates to:
  /// **'New Snatch'**
  String get newIncomeRaccoon;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @accountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created.'**
  String get accountCreated;

  /// No description provided for @liabilityCreated.
  ///
  /// In en, this message translates to:
  /// **'Liability created.'**
  String get liabilityCreated;

  /// No description provided for @budgetCreated.
  ///
  /// In en, this message translates to:
  /// **'Budget created.'**
  String get budgetCreated;

  /// No description provided for @failedToCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Failed to create account: {error}'**
  String failedToCreateAccount(String error);

  /// No description provided for @failedToCreateBudget.
  ///
  /// In en, this message translates to:
  /// **'Failed to create budget: {error}'**
  String failedToCreateBudget(String error);

  /// No description provided for @noLiabilitiesFound.
  ///
  /// In en, this message translates to:
  /// **'No liabilities found.'**
  String get noLiabilitiesFound;

  /// No description provided for @liabilityType.
  ///
  /// In en, this message translates to:
  /// **'Liability type'**
  String get liabilityType;

  /// No description provided for @liabilityTypeDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get liabilityTypeDebt;

  /// No description provided for @liabilityTypeLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get liabilityTypeLoan;

  /// No description provided for @liabilityTypeMortgage.
  ///
  /// In en, this message translates to:
  /// **'Mortgage'**
  String get liabilityTypeMortgage;

  /// No description provided for @liabilityDirection.
  ///
  /// In en, this message translates to:
  /// **'Liability in/out'**
  String get liabilityDirection;

  /// No description provided for @liabilityDirectionOwe.
  ///
  /// In en, this message translates to:
  /// **'I owe this debt to somebody else'**
  String get liabilityDirectionOwe;

  /// No description provided for @liabilityDirectionOwed.
  ///
  /// In en, this message translates to:
  /// **'Somebody owes this debt to me'**
  String get liabilityDirectionOwed;

  /// No description provided for @amountOwed.
  ///
  /// In en, this message translates to:
  /// **'I owe amount'**
  String get amountOwed;

  /// No description provided for @debtStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date of debt'**
  String get debtStartDate;

  /// No description provided for @interestRate.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get interestRate;

  /// No description provided for @interestPeriod.
  ///
  /// In en, this message translates to:
  /// **'Interest period'**
  String get interestPeriod;

  /// No description provided for @interestPeriodDaily.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get interestPeriodDaily;

  /// No description provided for @includeInNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Include in net worth'**
  String get includeInNetWorth;

  /// No description provided for @accountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get accountNumber;

  /// No description provided for @iban.
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get iban;

  /// No description provided for @bic.
  ///
  /// In en, this message translates to:
  /// **'BIC'**
  String get bic;

  /// No description provided for @liabilityCurrencyHelp.
  ///
  /// In en, this message translates to:
  /// **'Default currency for this liability account.'**
  String get liabilityCurrencyHelp;

  /// No description provided for @interestPeriodHelp.
  ///
  /// In en, this message translates to:
  /// **'Cosmetic only — Firefly III does not calculate interest automatically.'**
  String get interestPeriodHelp;

  /// No description provided for @failedToCreateLiability.
  ///
  /// In en, this message translates to:
  /// **'Failed to create liability: {error}'**
  String failedToCreateLiability(String error);

  /// No description provided for @navIncomeRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Snatched'**
  String get navIncomeRaccoon;

  /// No description provided for @navTransfersRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Stash Shuffles'**
  String get navTransfersRaccoon;

  /// No description provided for @navLiabilitiesRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get navLiabilitiesRaccoon;

  /// No description provided for @incomeTitleRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Snatched Funds'**
  String get incomeTitleRaccoon;

  /// No description provided for @transfersTitleRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Stash Shuffles'**
  String get transfersTitleRaccoon;

  /// No description provided for @newTransferActionRaccoon.
  ///
  /// In en, this message translates to:
  /// **'New Stash Shuffle'**
  String get newTransferActionRaccoon;

  /// No description provided for @liabilitiesTitleRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Debts Owed'**
  String get liabilitiesTitleRaccoon;

  /// No description provided for @tooltipOpenSection.
  ///
  /// In en, this message translates to:
  /// **'Open {section}.'**
  String tooltipOpenSection(String section);

  /// No description provided for @tooltipOpenDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open the dashboard with your key KPIs.'**
  String get tooltipOpenDashboard;

  /// No description provided for @tooltipOpenAccounts.
  ///
  /// In en, this message translates to:
  /// **'Open your accounts and balances.'**
  String get tooltipOpenAccounts;

  /// No description provided for @tooltipOpenTransactions.
  ///
  /// In en, this message translates to:
  /// **'Open all transactions and filters.'**
  String get tooltipOpenTransactions;

  /// No description provided for @tooltipOpenBudgets.
  ///
  /// In en, this message translates to:
  /// **'Open your budgets and spending progress.'**
  String get tooltipOpenBudgets;

  /// No description provided for @tooltipOpenPiggyBanks.
  ///
  /// In en, this message translates to:
  /// **'Open your savings goals and piggy banks.'**
  String get tooltipOpenPiggyBanks;

  /// No description provided for @tooltipOpenExpenses.
  ///
  /// In en, this message translates to:
  /// **'Open expense analytics and breakdowns.'**
  String get tooltipOpenExpenses;

  /// No description provided for @tooltipOpenIncome.
  ///
  /// In en, this message translates to:
  /// **'Open income analytics and trends.'**
  String get tooltipOpenIncome;

  /// No description provided for @tooltipOpenTransfers.
  ///
  /// In en, this message translates to:
  /// **'Open transfer analytics and history.'**
  String get tooltipOpenTransfers;

  /// No description provided for @tooltipOpenLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Open liabilities and debt overview.'**
  String get tooltipOpenLiabilities;

  /// No description provided for @tooltipOpenProjection.
  ///
  /// In en, this message translates to:
  /// **'Open projection scenarios and forecasts.'**
  String get tooltipOpenProjection;

  /// No description provided for @tooltipOpenPrognosis.
  ///
  /// In en, this message translates to:
  /// **'Open month-end account balance prognosis.'**
  String get tooltipOpenPrognosis;

  /// No description provided for @projectionTabLongTerm.
  ///
  /// In en, this message translates to:
  /// **'Long-term forecast'**
  String get projectionTabLongTerm;

  /// No description provided for @tooltipOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open app settings and Firefly connection.'**
  String get tooltipOpenSettings;

  /// No description provided for @tooltipToggleSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand or collapse the sidebar.'**
  String get tooltipToggleSidebar;

  /// No description provided for @tooltipSearchTransactions.
  ///
  /// In en, this message translates to:
  /// **'Search by text in the current page.'**
  String get tooltipSearchTransactions;

  /// No description provided for @tooltipToggleViewMode.
  ///
  /// In en, this message translates to:
  /// **'Switch between list and grid view.'**
  String get tooltipToggleViewMode;

  /// No description provided for @refreshFromFirefly.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshFromFirefly;

  /// No description provided for @tooltipRefreshFromFirefly.
  ///
  /// In en, this message translates to:
  /// **'Re-fetch data from Firefly III'**
  String get tooltipRefreshFromFirefly;

  /// No description provided for @viewModeCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get viewModeCards;

  /// No description provided for @viewModeRows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get viewModeRows;

  /// No description provided for @viewModeTightRows.
  ///
  /// In en, this message translates to:
  /// **'Tight rows'**
  String get viewModeTightRows;

  /// No description provided for @columnSelection.
  ///
  /// In en, this message translates to:
  /// **'Select columns'**
  String get columnSelection;

  /// No description provided for @columnDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get columnDate;

  /// No description provided for @columnAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get columnAccount;

  /// No description provided for @columnType.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get columnType;

  /// No description provided for @columnPayee.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get columnPayee;

  /// No description provided for @columnDescription.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get columnDescription;

  /// No description provided for @columnCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get columnCategory;

  /// No description provided for @columnBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get columnBudget;

  /// No description provided for @columnAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get columnAmount;

  /// No description provided for @columnReconciled.
  ///
  /// In en, this message translates to:
  /// **'Reconciled'**
  String get columnReconciled;

  /// No description provided for @columnBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get columnBalance;

  /// No description provided for @tooltipTransactionType.
  ///
  /// In en, this message translates to:
  /// **'Choose the transaction type.'**
  String get tooltipTransactionType;

  /// No description provided for @tooltipFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'What happened in this transaction.'**
  String get tooltipFieldDescription;

  /// No description provided for @tooltipFieldSourceAccount.
  ///
  /// In en, this message translates to:
  /// **'Account money comes from.'**
  String get tooltipFieldSourceAccount;

  /// No description provided for @tooltipFieldDestinationAccount.
  ///
  /// In en, this message translates to:
  /// **'Account money goes to.'**
  String get tooltipFieldDestinationAccount;

  /// No description provided for @tooltipSwapTransferAccounts.
  ///
  /// In en, this message translates to:
  /// **'Swap the two accounts.'**
  String get tooltipSwapTransferAccounts;

  /// No description provided for @disconnectConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Firefly III'**
  String get disconnectConfirmTitle;

  /// No description provided for @connectionFailedNotFirefly.
  ///
  /// In en, this message translates to:
  /// **'That address answered, but not with the Firefly III API. Check the server URL: a user interface address, or one behind a sign-in page, answers every path with a web page.'**
  String get connectionFailedNotFirefly;

  /// No description provided for @connectionFailedUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'The server answered and refused the token. Check the personal access token.'**
  String get connectionFailedUnauthorized;

  /// No description provided for @connectionFailedUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach that server. Check the address and that it is running.'**
  String get connectionFailedUnreachable;

  /// No description provided for @connectionFailedInsecure.
  ///
  /// In en, this message translates to:
  /// **'That is a plain http:// address. Turn on Allow HTTP connections if you mean it.'**
  String get connectionFailedInsecure;

  /// No description provided for @disconnectConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This deletes the server URL and the personal access token from this device\'s keychain. You will have to enter them again to reconnect.'**
  String get disconnectConfirmMessage;

  /// No description provided for @tooltipFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date and time of the transaction.'**
  String get tooltipFieldDate;

  /// No description provided for @tooltipFieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Main amount in the selected currency.'**
  String get tooltipFieldAmount;

  /// No description provided for @tooltipFieldCurrency.
  ///
  /// In en, this message translates to:
  /// **'Primary currency of this split.'**
  String get tooltipFieldCurrency;

  /// No description provided for @tooltipFieldForeignAmount.
  ///
  /// In en, this message translates to:
  /// **'Optional amount in another currency.'**
  String get tooltipFieldForeignAmount;

  /// No description provided for @tooltipFieldForeignCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency used for foreign amount.'**
  String get tooltipFieldForeignCurrency;

  /// No description provided for @tooltipFieldBudget.
  ///
  /// In en, this message translates to:
  /// **'Assign this split to a budget.'**
  String get tooltipFieldBudget;

  /// No description provided for @tooltipFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category for reporting and filters.'**
  String get tooltipFieldCategory;

  /// No description provided for @tooltipFieldPiggyBank.
  ///
  /// In en, this message translates to:
  /// **'Link this split to a piggy bank.'**
  String get tooltipFieldPiggyBank;

  /// No description provided for @tooltipFieldTags.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated tags for quick filtering.'**
  String get tooltipFieldTags;

  /// No description provided for @tooltipFieldSubscription.
  ///
  /// In en, this message translates to:
  /// **'Link this split to a subscription.'**
  String get tooltipFieldSubscription;

  /// No description provided for @tooltipFieldInterestDate.
  ///
  /// In en, this message translates to:
  /// **'Optional interest or booking date.'**
  String get tooltipFieldInterestDate;

  /// No description provided for @tooltipFieldAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments are shown but not uploaded yet.'**
  String get tooltipFieldAttachments;

  /// No description provided for @tooltipFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Extra details for future reference.'**
  String get tooltipFieldNotes;

  /// No description provided for @tooltipAddSplit.
  ///
  /// In en, this message translates to:
  /// **'Add another split to this transaction.'**
  String get tooltipAddSplit;

  /// No description provided for @tooltipRemoveSplit.
  ///
  /// In en, this message translates to:
  /// **'Remove this split line.'**
  String get tooltipRemoveSplit;

  /// No description provided for @tooltipCancelTransaction.
  ///
  /// In en, this message translates to:
  /// **'Discard changes and close.'**
  String get tooltipCancelTransaction;

  /// No description provided for @tooltipSaveTransaction.
  ///
  /// In en, this message translates to:
  /// **'Save this transaction.'**
  String get tooltipSaveTransaction;

  /// No description provided for @tooltipCancel.
  ///
  /// In en, this message translates to:
  /// **'Discard changes and close without saving.'**
  String get tooltipCancel;

  /// No description provided for @tooltipSave.
  ///
  /// In en, this message translates to:
  /// **'Save your changes.'**
  String get tooltipSave;

  /// No description provided for @tooltipCreate.
  ///
  /// In en, this message translates to:
  /// **'Create the new item.'**
  String get tooltipCreate;

  /// No description provided for @tooltipConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete this item.'**
  String get tooltipConfirmDelete;

  /// No description provided for @tooltipConfirmChallenge.
  ///
  /// In en, this message translates to:
  /// **'Type the challenge word to confirm deletion.'**
  String get tooltipConfirmChallenge;

  /// No description provided for @tooltipExpandDetails.
  ///
  /// In en, this message translates to:
  /// **'Show more details.'**
  String get tooltipExpandDetails;

  /// No description provided for @tooltipCollapseDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide extra details.'**
  String get tooltipCollapseDetails;

  /// No description provided for @tooltipClearDate.
  ///
  /// In en, this message translates to:
  /// **'Remove the selected date.'**
  String get tooltipClearDate;

  /// No description provided for @tooltipAccountName.
  ///
  /// In en, this message translates to:
  /// **'Display name shown in lists and reports.'**
  String get tooltipAccountName;

  /// No description provided for @tooltipAccountCurrentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current balance from Firefly as of today.'**
  String get tooltipAccountCurrentBalance;

  /// No description provided for @tooltipAccountEndOfMonthBalance.
  ///
  /// In en, this message translates to:
  /// **'Projected balance at the selected date, including scheduled transactions, recurrences, and bills.'**
  String get tooltipAccountEndOfMonthBalance;

  /// No description provided for @tooltipBalanceDatePick.
  ///
  /// In en, this message translates to:
  /// **'Show balances at another date'**
  String get tooltipBalanceDatePick;

  /// No description provided for @tooltipBalanceDateReset.
  ///
  /// In en, this message translates to:
  /// **'Back to the end of this month'**
  String get tooltipBalanceDateReset;

  /// No description provided for @tooltipBalanceBeyondForecast.
  ///
  /// In en, this message translates to:
  /// **'The forecast does not reach this far ahead, so this is the last projected figure.'**
  String get tooltipBalanceBeyondForecast;

  /// No description provided for @tooltipRecordedBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance the ledger holds through this date, including transactions already dated ahead.'**
  String get tooltipRecordedBalance;

  /// No description provided for @tooltipBudgetName.
  ///
  /// In en, this message translates to:
  /// **'Name for this spending budget.'**
  String get tooltipBudgetName;

  /// No description provided for @tooltipBudgetAmount.
  ///
  /// In en, this message translates to:
  /// **'Limit amount for this budget period.'**
  String get tooltipBudgetAmount;

  /// No description provided for @tooltipSubscriptionName.
  ///
  /// In en, this message translates to:
  /// **'Name of the recurring bill or subscription.'**
  String get tooltipSubscriptionName;

  /// No description provided for @tooltipSubscriptionCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency used for expected amounts.'**
  String get tooltipSubscriptionCurrency;

  /// No description provided for @tooltipSubscriptionAmountMin.
  ///
  /// In en, this message translates to:
  /// **'Lowest expected charge per period.'**
  String get tooltipSubscriptionAmountMin;

  /// No description provided for @tooltipSubscriptionAmountMax.
  ///
  /// In en, this message translates to:
  /// **'Highest expected charge per period.'**
  String get tooltipSubscriptionAmountMax;

  /// No description provided for @tooltipSubscriptionStartDate.
  ///
  /// In en, this message translates to:
  /// **'Date the subscription begins or was first recorded.'**
  String get tooltipSubscriptionStartDate;

  /// No description provided for @tooltipSubscriptionRepeats.
  ///
  /// In en, this message translates to:
  /// **'How often this subscription repeats.'**
  String get tooltipSubscriptionRepeats;

  /// No description provided for @tooltipSubscriptionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip the next N occurrences before charging again.'**
  String get tooltipSubscriptionSkip;

  /// No description provided for @tooltipSubscriptionEndDate.
  ///
  /// In en, this message translates to:
  /// **'Optional date when this subscription stops.'**
  String get tooltipSubscriptionEndDate;

  /// No description provided for @tooltipSubscriptionExtensionDate.
  ///
  /// In en, this message translates to:
  /// **'Optional date to extend or pause billing.'**
  String get tooltipSubscriptionExtensionDate;

  /// No description provided for @tooltipSubscriptionGroup.
  ///
  /// In en, this message translates to:
  /// **'Optional group label for organizing subscriptions.'**
  String get tooltipSubscriptionGroup;

  /// No description provided for @tooltipSubscriptionActive.
  ///
  /// In en, this message translates to:
  /// **'Whether this subscription is currently active.'**
  String get tooltipSubscriptionActive;

  /// No description provided for @tooltipPiggyBankName.
  ///
  /// In en, this message translates to:
  /// **'Name of this savings goal.'**
  String get tooltipPiggyBankName;

  /// No description provided for @tooltipPiggyBankTargetAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount you want to save in total.'**
  String get tooltipPiggyBankTargetAmount;

  /// No description provided for @tooltipPiggyBankCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency for the target and tracked savings.'**
  String get tooltipPiggyBankCurrency;

  /// No description provided for @tooltipPiggyBankAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts whose balances count toward this goal.'**
  String get tooltipPiggyBankAccounts;

  /// No description provided for @tooltipPiggyBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Include {name} in this piggy bank.'**
  String tooltipPiggyBankAccount(String name);

  /// No description provided for @tooltipPiggyBankStartDate.
  ///
  /// In en, this message translates to:
  /// **'When you started tracking this goal.'**
  String get tooltipPiggyBankStartDate;

  /// No description provided for @tooltipPiggyBankTargetDate.
  ///
  /// In en, this message translates to:
  /// **'Optional deadline to reach the target.'**
  String get tooltipPiggyBankTargetDate;

  /// No description provided for @tooltipPiggyBankGroup.
  ///
  /// In en, this message translates to:
  /// **'Optional group label for organizing piggy banks.'**
  String get tooltipPiggyBankGroup;

  /// No description provided for @tooltipThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Use the light color scheme.'**
  String get tooltipThemeLight;

  /// No description provided for @tooltipThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Use the dark color scheme.'**
  String get tooltipThemeDark;

  /// No description provided for @tooltipThemePaletteClassic.
  ///
  /// In en, this message translates to:
  /// **'Firefly-inspired classic palette.'**
  String get tooltipThemePaletteClassic;

  /// No description provided for @tooltipThemePaletteSpectrum.
  ///
  /// In en, this message translates to:
  /// **'Vivid multi-color category palette.'**
  String get tooltipThemePaletteSpectrum;

  /// No description provided for @tooltipThemePaletteRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Playful raccoon-themed palette.'**
  String get tooltipThemePaletteRaccoon;

  /// No description provided for @tooltipThemeAccent.
  ///
  /// In en, this message translates to:
  /// **'Accent color for buttons, links, and highlights.'**
  String get tooltipThemeAccent;

  /// No description provided for @tooltipThemeAccentOption.
  ///
  /// In en, this message translates to:
  /// **'Use {name} as the accent color.'**
  String tooltipThemeAccentOption(String name);

  /// No description provided for @tooltipThemeDone.
  ///
  /// In en, this message translates to:
  /// **'Close and keep the selected theme.'**
  String get tooltipThemeDone;

  /// No description provided for @repeatIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get repeatIntervalLabel;

  /// No description provided for @repeatIntervalHelp.
  ///
  /// In en, this message translates to:
  /// **'How often this repeats, e.g. every 3 months.'**
  String get repeatIntervalHelp;

  /// No description provided for @repeatEveryNDays.
  ///
  /// In en, this message translates to:
  /// **'Every {count} days'**
  String repeatEveryNDays(int count);

  /// No description provided for @repeatEveryNWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every {count} weeks'**
  String repeatEveryNWeeks(int count);

  /// No description provided for @repeatEveryNMonths.
  ///
  /// In en, this message translates to:
  /// **'Every {count} months'**
  String repeatEveryNMonths(int count);

  /// No description provided for @repeatEveryNYears.
  ///
  /// In en, this message translates to:
  /// **'Every {count} years'**
  String repeatEveryNYears(int count);

  /// No description provided for @writeAheadDays.
  ///
  /// In en, this message translates to:
  /// **'Write recurring transactions in advance'**
  String get writeAheadDays;

  /// No description provided for @writeAheadDaysDescription.
  ///
  /// In en, this message translates to:
  /// **'Create upcoming recurring transactions this many days ahead.'**
  String get writeAheadDaysDescription;

  /// No description provided for @writeAheadOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get writeAheadOff;

  /// No description provided for @writeAheadNDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String writeAheadNDays(int count);

  /// No description provided for @plannedLabel.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get plannedLabel;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navHistoryRaccoon.
  ///
  /// In en, this message translates to:
  /// **'Heist Replay'**
  String get navHistoryRaccoon;

  /// No description provided for @tooltipOpenHistory.
  ///
  /// In en, this message translates to:
  /// **'Open undo/redo history.'**
  String get tooltipOpenHistory;

  /// No description provided for @tooltipUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo the last action.'**
  String get tooltipUndo;

  /// No description provided for @tooltipRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo the last undone action.'**
  String get tooltipRedo;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @undoHistorySize.
  ///
  /// In en, this message translates to:
  /// **'Undo/Redo history size'**
  String get undoHistorySize;

  /// No description provided for @undoHistoryStoredEntries.
  ///
  /// In en, this message translates to:
  /// **'Stored entries: {count} / {limit}'**
  String undoHistoryStoredEntries(int count, int limit);

  /// No description provided for @openHistoryScreen.
  ///
  /// In en, this message translates to:
  /// **'Open history screen'**
  String get openHistoryScreen;

  /// No description provided for @undoHistoryLimitRange.
  ///
  /// In en, this message translates to:
  /// **'Min {min}  •  Default {defaultValue}  •  Max {max}'**
  String undoHistoryLimitRange(int min, int defaultValue, int max);

  /// No description provided for @searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search history'**
  String get searchHistory;

  /// No description provided for @allActions.
  ///
  /// In en, this message translates to:
  /// **'All actions'**
  String get allActions;

  /// No description provided for @noHistoryEntriesMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No history entries match your filters.'**
  String get noHistoryEntriesMatchFilters;

  /// No description provided for @historyExportedTo.
  ///
  /// In en, this message translates to:
  /// **'History exported to {path}'**
  String historyExportedTo(String path);

  /// No description provided for @historyExportedAndShared.
  ///
  /// In en, this message translates to:
  /// **'History exported and share sheet opened'**
  String get historyExportedAndShared;

  /// No description provided for @exportJson.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get exportJson;

  /// No description provided for @exportAndShare.
  ///
  /// In en, this message translates to:
  /// **'Export & Share'**
  String get exportAndShare;

  /// No description provided for @jumpToCurrent.
  ///
  /// In en, this message translates to:
  /// **'Jump to current'**
  String get jumpToCurrent;

  /// No description provided for @historyExportSubject.
  ///
  /// In en, this message translates to:
  /// **'History export'**
  String get historyExportSubject;

  /// No description provided for @historyExportText.
  ///
  /// In en, this message translates to:
  /// **'FireRaccoon history export'**
  String get historyExportText;

  /// No description provided for @historySectionToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historySectionToday;

  /// No description provided for @historySectionYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get historySectionYesterday;

  /// No description provided for @historySectionOlder.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get historySectionOlder;

  /// No description provided for @historyEntriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} / {limit}'**
  String historyEntriesCount(int count, int limit);

  /// No description provided for @undoActionTypeThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get undoActionTypeThemeMode;

  /// No description provided for @undoActionTypeThemePalette.
  ///
  /// In en, this message translates to:
  /// **'Theme palette'**
  String get undoActionTypeThemePalette;

  /// No description provided for @undoActionTypeThemeAccent.
  ///
  /// In en, this message translates to:
  /// **'Theme accent'**
  String get undoActionTypeThemeAccent;

  /// No description provided for @undoActionTypeThemeFunMode.
  ///
  /// In en, this message translates to:
  /// **'Fun mode'**
  String get undoActionTypeThemeFunMode;

  /// No description provided for @undoActionTypeLocale.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get undoActionTypeLocale;

  /// No description provided for @undoActionTypeViewMode.
  ///
  /// In en, this message translates to:
  /// **'View mode'**
  String get undoActionTypeViewMode;

  /// No description provided for @undoActionTypeTransactionPageSize.
  ///
  /// In en, this message translates to:
  /// **'Transaction page size'**
  String get undoActionTypeTransactionPageSize;

  /// No description provided for @undoActionTypePrognosisMode.
  ///
  /// In en, this message translates to:
  /// **'Projection view mode'**
  String get undoActionTypePrognosisMode;

  /// No description provided for @undoActionTypePrognosisHorizon.
  ///
  /// In en, this message translates to:
  /// **'Projection horizon'**
  String get undoActionTypePrognosisHorizon;

  /// No description provided for @undoActionTypePrognosisInclusion.
  ///
  /// In en, this message translates to:
  /// **'Projection inclusion'**
  String get undoActionTypePrognosisInclusion;

  /// No description provided for @undoActionTypePrognosisMarginPercent.
  ///
  /// In en, this message translates to:
  /// **'Projection margin'**
  String get undoActionTypePrognosisMarginPercent;

  /// No description provided for @undoActionTypeAccountCreate.
  ///
  /// In en, this message translates to:
  /// **'Account created'**
  String get undoActionTypeAccountCreate;

  /// No description provided for @undoActionTypeAccountUpdate.
  ///
  /// In en, this message translates to:
  /// **'Account updated'**
  String get undoActionTypeAccountUpdate;

  /// No description provided for @undoActionTypeAccountDelete.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get undoActionTypeAccountDelete;

  /// No description provided for @undoActionTypeBudgetCreate.
  ///
  /// In en, this message translates to:
  /// **'Budget created'**
  String get undoActionTypeBudgetCreate;

  /// No description provided for @undoActionTypeBudgetUpdate.
  ///
  /// In en, this message translates to:
  /// **'Budget updated'**
  String get undoActionTypeBudgetUpdate;

  /// No description provided for @undoActionTypeBudgetDelete.
  ///
  /// In en, this message translates to:
  /// **'Budget deleted'**
  String get undoActionTypeBudgetDelete;

  /// No description provided for @undoActionTypeTransactionCreate.
  ///
  /// In en, this message translates to:
  /// **'Transaction created'**
  String get undoActionTypeTransactionCreate;

  /// No description provided for @undoActionTypeTransactionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Transaction updated'**
  String get undoActionTypeTransactionUpdate;

  /// No description provided for @undoActionTypeTransactionDelete.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted'**
  String get undoActionTypeTransactionDelete;

  /// No description provided for @undoActionTypeBillCreate.
  ///
  /// In en, this message translates to:
  /// **'Subscription created'**
  String get undoActionTypeBillCreate;

  /// No description provided for @undoActionTypeBillUpdate.
  ///
  /// In en, this message translates to:
  /// **'Subscription updated'**
  String get undoActionTypeBillUpdate;

  /// No description provided for @undoActionTypeBillDelete.
  ///
  /// In en, this message translates to:
  /// **'Subscription deleted'**
  String get undoActionTypeBillDelete;

  /// No description provided for @undoActionTypeRecurrenceCreate.
  ///
  /// In en, this message translates to:
  /// **'Recurring transaction created'**
  String get undoActionTypeRecurrenceCreate;

  /// No description provided for @undoActionTypeRecurrenceUpdate.
  ///
  /// In en, this message translates to:
  /// **'Recurring transaction updated'**
  String get undoActionTypeRecurrenceUpdate;

  /// No description provided for @undoActionTypeRecurrenceDelete.
  ///
  /// In en, this message translates to:
  /// **'Recurring transaction deleted'**
  String get undoActionTypeRecurrenceDelete;

  /// No description provided for @undoActionTypePiggyBankCreate.
  ///
  /// In en, this message translates to:
  /// **'Piggy bank created'**
  String get undoActionTypePiggyBankCreate;

  /// No description provided for @undoActionTypePiggyBankUpdate.
  ///
  /// In en, this message translates to:
  /// **'Piggy bank updated'**
  String get undoActionTypePiggyBankUpdate;

  /// No description provided for @undoActionTypePiggyBankDelete.
  ///
  /// In en, this message translates to:
  /// **'Piggy bank deleted'**
  String get undoActionTypePiggyBankDelete;

  /// No description provided for @undoActionTypeLiabilityCreate.
  ///
  /// In en, this message translates to:
  /// **'Liability created'**
  String get undoActionTypeLiabilityCreate;

  /// No description provided for @searchHintTitle.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search'**
  String get searchHintTitle;

  /// No description provided for @searchHintSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search by description, account, category, tag, note, or amount.'**
  String get searchHintSubtitle;

  /// No description provided for @noSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No matching suggestions'**
  String get noSuggestions;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount must be a valid number greater than 0.'**
  String get invalidAmount;

  /// No description provided for @invalidForeignAmount.
  ///
  /// In en, this message translates to:
  /// **'Foreign amount must be a valid number greater than 0.'**
  String get invalidForeignAmount;

  /// No description provided for @exportFireflyData.
  ///
  /// In en, this message translates to:
  /// **'Back up Firefly data'**
  String get exportFireflyData;

  /// No description provided for @exportFireflyDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Saves a snapshot of your Firefly data to a JSON file: accounts, transactions with every split, budgets, categories, tags, bills, piggy banks, recurring rules and currencies.\n\nThis is not a full backup. Firefly III has no backup feature, and an app talking to its API cannot reach the database, uploaded attachments or the instance key. Restoring a working Firefly needs a volume archive taken on the server; see the deployment guide.'**
  String get exportFireflyDataDescription;

  /// No description provided for @fireflyDataExportedTo.
  ///
  /// In en, this message translates to:
  /// **'Firefly data exported to {path}'**
  String fireflyDataExportedTo(String path);

  /// No description provided for @missingInformation.
  ///
  /// In en, this message translates to:
  /// **'Missing information'**
  String get missingInformation;

  /// No description provided for @missingDescription.
  ///
  /// In en, this message translates to:
  /// **'Please enter a description.'**
  String get missingDescription;

  /// No description provided for @missingAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount.'**
  String get missingAmount;

  /// No description provided for @numberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format'**
  String get numberFormat;

  /// No description provided for @dateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get dateFormat;

  /// No description provided for @followsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Follows the language'**
  String get followsLanguage;

  /// No description provided for @formattingDescription.
  ///
  /// In en, this message translates to:
  /// **'How amounts and dates are written, which is a separate choice from the language the app is in.'**
  String get formattingDescription;

  /// No description provided for @selectNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format'**
  String get selectNumberFormat;

  /// No description provided for @selectDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get selectDateFormat;

  /// No description provided for @recentProblems.
  ///
  /// In en, this message translates to:
  /// **'Recent problems'**
  String get recentProblems;

  /// No description provided for @recentProblemsDescription.
  ///
  /// In en, this message translates to:
  /// **'What has failed since this app started, newest last. Nothing here leaves the device until you copy it.'**
  String get recentProblemsDescription;

  /// No description provided for @noRecentProblems.
  ///
  /// In en, this message translates to:
  /// **'Nothing has failed since this app started.'**
  String get noRecentProblems;

  /// No description provided for @copyProblems.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyProblems;

  /// No description provided for @clearProblems.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearProblems;

  /// No description provided for @problemsCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied {count} lines.'**
  String problemsCopied(int count);

  /// No description provided for @missingForeignAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter the foreign amount.'**
  String get missingForeignAmount;

  /// No description provided for @missingAccounts.
  ///
  /// In en, this message translates to:
  /// **'Please select both source and destination accounts.'**
  String get missingAccounts;

  /// No description provided for @appUsers.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get appUsers;

  /// No description provided for @enableAppUsers.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get enableAppUsers;

  /// No description provided for @enableAppUsersDescription.
  ///
  /// In en, this message translates to:
  /// **'Add household members who can use this app and own shares of accounts. Everyone still shares the same Firefly III data.'**
  String get enableAppUsersDescription;

  /// No description provided for @createAdmin.
  ///
  /// In en, this message translates to:
  /// **'Add first person'**
  String get createAdmin;

  /// No description provided for @createAdminDescription.
  ///
  /// In en, this message translates to:
  /// **'The first person becomes an admin. You can add more people afterwards.'**
  String get createAdminDescription;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add person'**
  String get addUser;

  /// No description provided for @editUser.
  ///
  /// In en, this message translates to:
  /// **'Edit person'**
  String get editUser;

  /// No description provided for @deleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete person'**
  String get deleteUser;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get roleUser;

  /// No description provided for @roleViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get roleViewer;

  /// No description provided for @roleAdminDescription.
  ///
  /// In en, this message translates to:
  /// **'Full access, including Firefly settings and people management.'**
  String get roleAdminDescription;

  /// No description provided for @roleUserDescription.
  ///
  /// In en, this message translates to:
  /// **'Can add and edit financial data.'**
  String get roleUserDescription;

  /// No description provided for @roleViewerDescription.
  ///
  /// In en, this message translates to:
  /// **'Read-only access.'**
  String get roleViewerDescription;

  /// No description provided for @requireLogin.
  ///
  /// In en, this message translates to:
  /// **'Login with password'**
  String get requireLogin;

  /// No description provided for @requireLoginDescription.
  ///
  /// In en, this message translates to:
  /// **'When on, every launch requires a password (or biometrics). Every person must have a password before this can be enabled.'**
  String get requireLoginDescription;

  /// No description provided for @switchUser.
  ///
  /// In en, this message translates to:
  /// **'Switch person'**
  String get switchUser;

  /// No description provided for @selectUserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose whose profile to use. No password needed while login with password is off.'**
  String get selectUserSubtitle;

  /// No description provided for @assignPerson.
  ///
  /// In en, this message translates to:
  /// **'Linked person'**
  String get assignPerson;

  /// No description provided for @noPersonAssigned.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noPersonAssigned;

  /// No description provided for @myAccount.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get myAccount;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @setPassword.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get setPassword;

  /// No description provided for @clearPassword.
  ///
  /// In en, this message translates to:
  /// **'Remove password'**
  String get clearPassword;

  /// No description provided for @passwordOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Optional. Leave blank to skip. Required only if login with password is enabled.'**
  String get passwordOptionalHint;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue to FireRaccoon.'**
  String get loginSubtitle;

  /// No description provided for @loginMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Enter your name and password.'**
  String get loginMissingFields;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect name or password.'**
  String get loginInvalidCredentials;

  /// No description provided for @passwordTooWeak.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 10 characters and include an uppercase letter, a lowercase letter, a digit, and a special character.'**
  String get passwordTooWeak;

  /// No description provided for @passwordRequirements.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters, with uppercase, lowercase, a digit, and a special character.'**
  String get passwordRequirements;

  /// No description provided for @passwordMissingRequirements.
  ///
  /// In en, this message translates to:
  /// **'Password is missing {requirements}.'**
  String passwordMissingRequirements(String requirements);

  /// No description provided for @passwordReqMinLength.
  ///
  /// In en, this message translates to:
  /// **'at least 10 characters'**
  String get passwordReqMinLength;

  /// No description provided for @passwordReqUpper.
  ///
  /// In en, this message translates to:
  /// **'an uppercase letter'**
  String get passwordReqUpper;

  /// No description provided for @passwordReqLower.
  ///
  /// In en, this message translates to:
  /// **'a lowercase letter'**
  String get passwordReqLower;

  /// No description provided for @passwordReqDigit.
  ///
  /// In en, this message translates to:
  /// **'a digit'**
  String get passwordReqDigit;

  /// No description provided for @passwordReqSpecial.
  ///
  /// In en, this message translates to:
  /// **'a special character'**
  String get passwordReqSpecial;

  /// No description provided for @passwordPwned.
  ///
  /// In en, this message translates to:
  /// **'This password has appeared in a known data breach. Please choose another one.'**
  String get passwordPwned;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @usernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That name is already taken.'**
  String get usernameTaken;

  /// No description provided for @currentPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect.'**
  String get currentPasswordIncorrect;

  /// No description provided for @userCreated.
  ///
  /// In en, this message translates to:
  /// **'Person created.'**
  String get userCreated;

  /// No description provided for @userUpdated.
  ///
  /// In en, this message translates to:
  /// **'Person updated.'**
  String get userUpdated;

  /// No description provided for @userDeleted.
  ///
  /// In en, this message translates to:
  /// **'Person deleted.'**
  String get userDeleted;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get passwordChanged;

  /// No description provided for @passwordCleared.
  ///
  /// In en, this message translates to:
  /// **'Password removed.'**
  String get passwordCleared;

  /// No description provided for @deleteUserConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete person'**
  String get deleteUserConfirmTitle;

  /// No description provided for @deleteUserConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes {username} and their ownership shares. Firefly III data is not affected.'**
  String deleteUserConfirmMessage(String username);

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {username}'**
  String signedInAs(String username);

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name.'**
  String get usernameRequired;

  /// No description provided for @unlockWithBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get unlockWithBiometrics;

  /// No description provided for @unlockWithBiometricsDescription.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID, Touch ID, fingerprint, or your device PIN on the login screen.'**
  String get unlockWithBiometricsDescription;

  /// No description provided for @biometricUnlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock FireRaccoon'**
  String get biometricUnlockReason;

  /// No description provided for @biometricEnableReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm to enable biometric unlock'**
  String get biometricEnableReason;

  /// No description provided for @biometricUnlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock was cancelled or failed.'**
  String get biometricUnlockFailed;

  /// No description provided for @peopleMissingPasswordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Passwords required'**
  String get peopleMissingPasswordsTitle;

  /// No description provided for @peopleMissingPasswordsMessage.
  ///
  /// In en, this message translates to:
  /// **'Set a password for these people before enabling login with password: {names}.'**
  String peopleMissingPasswordsMessage(String names);

  /// No description provided for @hasPassword.
  ///
  /// In en, this message translates to:
  /// **'Password set'**
  String get hasPassword;

  /// No description provided for @noPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'No password'**
  String get noPasswordSet;

  /// No description provided for @cropAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust photo'**
  String get cropAvatarTitle;

  /// No description provided for @saveAvatar.
  ///
  /// In en, this message translates to:
  /// **'Save photo'**
  String get saveAvatar;

  /// No description provided for @chooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Profile picture'**
  String get chooseAvatar;

  /// No description provided for @uploadAvatar.
  ///
  /// In en, this message translates to:
  /// **'Upload photo'**
  String get uploadAvatar;

  /// No description provided for @avatarPresets.
  ///
  /// In en, this message translates to:
  /// **'Raccoon presets'**
  String get avatarPresets;

  /// No description provided for @avatarTooSmall.
  ///
  /// In en, this message translates to:
  /// **'Image is too small (minimum 10 KB).'**
  String get avatarTooSmall;

  /// No description provided for @avatarTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image is too large (maximum 5 MB).'**
  String get avatarTooLarge;

  /// No description provided for @avatarInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Could not read image. Use a JPG or PNG file.'**
  String get avatarInvalidFormat;

  /// No description provided for @personAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get personAppearance;

  /// No description provided for @personLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get personLanguage;

  /// No description provided for @allPeople.
  ///
  /// In en, this message translates to:
  /// **'All People'**
  String get allPeople;

  /// No description provided for @filterByPersonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter by Person'**
  String get filterByPersonTooltip;

  /// No description provided for @peopleAndOwnership.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get peopleAndOwnership;

  /// No description provided for @peopleAndOwnershipSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles, roles, passwords, and account ownership'**
  String get peopleAndOwnershipSubtitle;

  /// No description provided for @addPerson.
  ///
  /// In en, this message translates to:
  /// **'Add Person'**
  String get addPerson;

  /// No description provided for @editPerson.
  ///
  /// In en, this message translates to:
  /// **'Edit Person'**
  String get editPerson;

  /// No description provided for @deletePerson.
  ///
  /// In en, this message translates to:
  /// **'Delete Person'**
  String get deletePerson;

  /// No description provided for @cannotDeleteOnlyAdmin.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete the only admin. Promote someone else first.'**
  String get cannotDeleteOnlyAdmin;

  /// No description provided for @cannotDemoteOnlyAdmin.
  ///
  /// In en, this message translates to:
  /// **'Cannot demote the only admin. Promote someone else first.'**
  String get cannotDemoteOnlyAdmin;

  /// No description provided for @personName.
  ///
  /// In en, this message translates to:
  /// **'Person Name'**
  String get personName;

  /// No description provided for @selectOwners.
  ///
  /// In en, this message translates to:
  /// **'Assign Owners'**
  String get selectOwners;

  /// No description provided for @customSplit.
  ///
  /// In en, this message translates to:
  /// **'Custom Percentage Split'**
  String get customSplit;

  /// No description provided for @accountAssignments.
  ///
  /// In en, this message translates to:
  /// **'Account Assignments & Split Ratios'**
  String get accountAssignments;

  /// No description provided for @colorBadge.
  ///
  /// In en, this message translates to:
  /// **'Color Badge'**
  String get colorBadge;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get settingsBackup;

  /// No description provided for @exportSettingsDisclosureTitle.
  ///
  /// In en, this message translates to:
  /// **'What goes into the file?'**
  String get exportSettingsDisclosureTitle;

  /// No description provided for @exportSettingsDisclosure.
  ///
  /// In en, this message translates to:
  /// **'INCLUDED:\n• People, their roles, and account assignments\n• Account classifications, layout, and preferences\n• Prognosis settings and the Firefly URL\n\nNOT INCLUDED:\n• MCP agent keys. They never leave this device, so an agent needs a key issued where it will run.\n• Your Firefly data itself: accounts, transactions, budgets. That stays in Firefly III.\n• Custom profile photos and biometric unlock\n• The Firefly API token and password hashes, unless you set a backup passphrase on the next screen, which seals them into the file'**
  String get exportSettingsDisclosure;

  /// No description provided for @exportSettingsContinue.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportSettingsContinue;

  /// No description provided for @exportSettings.
  ///
  /// In en, this message translates to:
  /// **'Export settings'**
  String get exportSettings;

  /// No description provided for @exportSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Saves people and their roles, account assignments and classifications, layout, preferences, prognosis settings, and the Firefly URL to a JSON file.\n\nLeft out: MCP agent keys, which never leave this device; your Firefly data itself (accounts, transactions, budgets), which stays in Firefly III; custom profile photos; and biometric unlock. The Firefly API token and password hashes are only included if you set a backup passphrase, which encrypts them.'**
  String get exportSettingsDescription;

  /// No description provided for @importSettings.
  ///
  /// In en, this message translates to:
  /// **'Import settings'**
  String get importSettings;

  /// No description provided for @importSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Replaces what is on this device with a previously exported file: people and their roles, account assignments and classifications, layout, preferences, prognosis settings, and the Firefly connection if the file has one.\n\nDeletes MCP agent keys whose owner no longer exists afterwards. A key created before People were set up belongs to \"this device\", so importing people removes it and any agent using it stops working.\n\nDoes not restore custom profile photos or biometric unlock. Password login stays off unless the file carries portable password hashes and you enter its passphrase.'**
  String get importSettingsDescription;

  /// No description provided for @importSettingsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Overwrite settings?'**
  String get importSettingsConfirmTitle;

  /// No description provided for @importSettingsConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'REPLACED on this device:\n• People, their roles, and account assignments\n• Account classifications\n• Layout: side menu, columns, view mode, row density\n• Theme, language, dashboard period, page size, write-ahead days, undo limit\n• Prognosis settings\n• The Firefly connection, if the file carries one\n\nDELETED:\n• MCP agent keys whose owner no longer exists afterwards. A key created before People were set up belongs to \"this device\" and will be removed, so any agent using it stops working and needs a new key.\n\nNOT RESTORED:\n• Custom profile photos and biometric unlock\n• Password login, unless the file carries portable password hashes and you enter its passphrase'**
  String get importSettingsConfirmMessage;

  /// No description provided for @backupPassphraseExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect backup'**
  String get backupPassphraseExportTitle;

  /// No description provided for @backupPassphraseExportMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a passphrase to encrypt the Firefly API token and password hashes in this file. You will need the same passphrase to import.'**
  String get backupPassphraseExportMessage;

  /// No description provided for @backupPassphraseImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock backup'**
  String get backupPassphraseImportTitle;

  /// No description provided for @backupPassphraseImportMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter the passphrase used when this settings file was exported.'**
  String get backupPassphraseImportMessage;

  /// No description provided for @backupPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Backup passphrase'**
  String get backupPassphrase;

  /// No description provided for @backupPassphraseRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the backup passphrase.'**
  String get backupPassphraseRequired;

  /// No description provided for @backupPassphraseShow.
  ///
  /// In en, this message translates to:
  /// **'Show passphrase'**
  String get backupPassphraseShow;

  /// No description provided for @backupPassphraseHide.
  ///
  /// In en, this message translates to:
  /// **'Hide passphrase'**
  String get backupPassphraseHide;

  /// No description provided for @settingsExportedTo.
  ///
  /// In en, this message translates to:
  /// **'Settings exported to {path}'**
  String settingsExportedTo(String path);

  /// No description provided for @settingsImported.
  ///
  /// In en, this message translates to:
  /// **'Settings imported.'**
  String get settingsImported;

  /// No description provided for @settingsImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import settings: {error}'**
  String settingsImportFailed(String error);

  /// No description provided for @settingsExportSubject.
  ///
  /// In en, this message translates to:
  /// **'FireRaccoon settings'**
  String get settingsExportSubject;

  /// No description provided for @settingsExportText.
  ///
  /// In en, this message translates to:
  /// **'FireRaccoon settings backup'**
  String get settingsExportText;

  /// No description provided for @recordedBalance.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get recordedBalance;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'en',
    'fr',
    'ja',
    'pt',
    'sv',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'pt':
      return AppLocalizationsPt();
    case 'sv':
      return AppLocalizationsSv();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
