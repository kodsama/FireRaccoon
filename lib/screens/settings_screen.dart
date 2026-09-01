import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../deployment/deployment_providers.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../fun_modes/fun_mode.dart';
import '../providers/app_info_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/locale_provider.dart';
import '../providers/people_providers.dart';
import '../providers/theme_provider.dart';
import '../providers/default_period_provider.dart';
import '../providers/transaction_page_size_provider.dart';
import '../providers/write_ahead_provider.dart';
import '../providers/undo_history_provider.dart';
import '../services/mcp_service.dart';
import '../theme/app_theme.dart';
import '../widgets/theme_style_picker.dart';
import '../widgets/autocomplete_text_field.dart';
import '../widgets/small_loading_indicator.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/diagnostics_section.dart';
import '../widgets/firefly_backup_section.dart';
import '../widgets/mcp_settings_section.dart';
import '../widgets/people_settings_section.dart';
import '../widgets/settings_backup_section.dart';
import '../widgets/side_menu_settings_section.dart';
import '../utils/autocomplete_suggestions.dart';
import '../utils/locale_formatting.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _showLanguagePicker(BuildContext context) {
    final l10n = context.l10n;
    final current = ref.read(localeProvider);

    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.selectLanguage),
        children: AppLocale.supported.map((locale) {
          final option = AppLocale(locale);
          return SimpleDialogOption(
            onPressed: () {
              final previous = ref.read(localeProvider);
              ref.read(localeProvider.notifier).setLocale(option);
              ref
                  .read(undoHistoryProvider.notifier)
                  .record(
                    title: 'Language changed',
                    details:
                        'Language: ${previous.languageCode.toUpperCase()} -> ${option.languageCode.toUpperCase()}',
                    type: UndoActionType.locale,
                    undoPayload: {'locale': previous.languageCode},
                    redoPayload: {'locale': option.languageCode},
                  );
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                if (option.languageCode == current.languageCode)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 12),
                Text(l10n.languageDisplayName(option.languageCode)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// A date with a two-digit day and a month whose name differs from its
  /// number, so a sample tells the reader apart 03/04 from 4 March.
  static final DateTime _sampleDate = DateTime(2026, 3, 4);

  String _formattingLabel(Locale? chosen, {required String sample}) {
    final tag = chosen == null ? context.l10n.followsLanguage : '$chosen';
    return '$tag  $sample';
  }

  /// Picks the locale numbers or dates are written in.
  ///
  /// Every option carries what it would produce, because "fr_CA" tells nobody
  /// where the thousands separator lands, and the whole point of choosing this
  /// separately from the language is that the reader has a preference about
  /// exactly that.
  void _showFormattingPicker(
    BuildContext context, {
    required String title,
    required NotifierProvider<FormattingLocaleNotifier, Locale?> provider,
    required String Function(LocaleFormatting format) sample,
  }) {
    final l10n = context.l10n;
    final current = ref.read(provider);
    final interface = ref.read(localeProvider).locale;

    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          for (final option in <Locale?>[null, ...kFormattingLocales])
            SimpleDialogOption(
              onPressed: () {
                ref.read(provider.notifier).set(option);
                Navigator.pop(ctx);
              },
              child: Row(
                children: [
                  if (option?.toString() == current?.toString())
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option == null ? l10n.followsLanguage : '$option',
                    ),
                  ),
                  Text(
                    sample(LocaleFormatting(option ?? interface)),
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Says which of the ways a connection test can fail happened.
  ///
  /// Saving is refused until a test passes, so "failed" on its own left somebody
  /// staring at a dialog with no idea whether the address, the token or the
  /// network was the problem.
  String _connectionFailureText(
    AppLocalizations l10n,
    ConnectionTestResult result,
  ) {
    return switch (result.failure) {
      ConnectionFailure.insecureRefused => l10n.connectionFailedInsecure,
      ConnectionFailure.unauthorized => l10n.connectionFailedUnauthorized,
      ConnectionFailure.notFirefly => l10n.connectionFailedNotFirefly,
      ConnectionFailure.unreachable => l10n.connectionFailedUnreachable,
      ConnectionFailure.serverError || null => l10n.connectionFailed,
    };
  }

  void _showAuthDialog(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final auth = ref.read(authProvider);
    final urlController = TextEditingController(text: auth.serverUrl);
    final tokenController = TextEditingController(
      text: auth.authMode == AuthMode.token ? auth.apiToken : '',
    );
    final clientIdController = TextEditingController();

    AuthMode selectedMode = auth.authMode;
    bool allowInsecure = auth.allowInsecure;
    bool obscureToken = true;
    bool isTesting = false;
    bool testSuccess = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.fireflyConnectionTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: l10n.serverUrlLabel,
                    child: AutocompleteTextField(
                      controller: urlController,
                      suggestions: AutocompleteSuggestions.serverUrls(
                        urlController.text,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.serverUrlLabel,
                      ),
                      onChanged: (val) => setState(() => testSuccess = false),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Tooltip(
                    message: l10n.allowHttpConnections,
                    child: SwitchListTile(
                      title: Text(l10n.allowHttpConnections),
                      contentPadding: EdgeInsets.zero,
                      value: allowInsecure,
                      onChanged: (val) => setState(() {
                        allowInsecure = val;
                        testSuccess = false;
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Tooltip(
                    message: l10n.authenticationMethod,
                    child: DropdownButtonFormField<AuthMode>(
                      initialValue: selectedMode,
                      items: [
                        DropdownMenuItem(
                          value: AuthMode.token,
                          child: Text(l10n.personalAccessToken),
                        ),
                        DropdownMenuItem(
                          value: AuthMode.oauth2,
                          child: Text(l10n.oauth2),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedMode = val;
                            testSuccess = false;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: l10n.authenticationMethod,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selectedMode == AuthMode.token) ...[
                    Tooltip(
                      message: l10n.personalAccessToken,
                      child: AutocompleteTextField(
                        controller: tokenController,
                        obscureText: obscureToken,
                        suggestions: AutocompleteSuggestions.distinctNonEmpty([
                          tokenController.text,
                        ]),
                        decoration: InputDecoration(
                          labelText: l10n.personalAccessToken,
                          suffixIcon: IconButton(
                            tooltip: l10n.personalAccessToken,
                            icon: Icon(
                              obscureToken
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => obscureToken = !obscureToken),
                          ),
                        ),
                        onChanged: (val) => setState(() => testSuccess = false),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Tooltip(
                      message: l10n.testConnection,
                      child: ElevatedButton.icon(
                        onPressed: isTesting
                            ? null
                            : () async {
                                setState(() {
                                  isTesting = true;
                                  testSuccess = false;
                                });
                                final result = await ref
                                    .read(authProvider.notifier)
                                    .testConnection(
                                      urlController.text,
                                      tokenController.text,
                                      allowInsecure,
                                    );
                                if (context.mounted) {
                                  setState(() {
                                    isTesting = false;
                                    testSuccess = result.ok;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result.ok
                                            ? l10n.connectionSuccessful
                                            : _connectionFailureText(
                                                l10n,
                                                result,
                                              ),
                                      ),
                                      backgroundColor: result.ok
                                          ? context.colors.success
                                          : context.colors.danger,
                                      duration: const Duration(seconds: 8),
                                    ),
                                  );
                                }
                              },
                        icon: isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cable),
                        label: Text(l10n.testConnection),
                      ),
                    ),
                  ] else
                    Tooltip(
                      message: l10n.oauthClientId,
                      child: AutocompleteTextField(
                        controller: clientIdController,
                        suggestions: AutocompleteSuggestions.distinctNonEmpty([
                          clientIdController.text,
                        ]),
                        decoration: InputDecoration(
                          labelText: l10n.oauthClientId,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: (selectedMode == AuthMode.token && !testSuccess)
                    ? null
                    : () async {
                        try {
                          if (selectedMode == AuthMode.token) {
                            await ref
                                .read(authProvider.notifier)
                                .saveSettings(
                                  urlController.text,
                                  tokenController.text,
                                  allowInsecure,
                                );
                          } else {
                            await ref
                                .read(authProvider.notifier)
                                .authenticateOAuth(
                                  urlController.text,
                                  clientIdController.text,
                                  allowInsecure,
                                );
                          }
                          if (context.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                child: Text(
                  selectedMode == AuthMode.token
                      ? l10n.save
                      : l10n.loginViaBrowser,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDefaultPeriodPicker(BuildContext context) {
    final l10n = context.l10n;
    final current = ref.read(defaultDashboardPeriodProvider);

    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.defaultPeriod),
        children: DashboardPeriod.values
            .map(
              (period) => SimpleDialogOption(
                onPressed: () {
                  ref
                      .read(defaultDashboardPeriodProvider.notifier)
                      .setPeriod(period);
                  Navigator.pop(ctx);
                },
                child: Row(
                  children: [
                    if (period == current)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 12),
                    Text(period.localizedLabel(l10n)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, FireflyCurrency current) {
    final l10n = context.l10n;

    showDialog<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final currenciesAsync = ref.watch(currenciesProvider);
          return currenciesAsync.when(
            loading: () => AlertDialog(
              title: Text(l10n.selectCurrency),
              content: const Center(child: SmallLoadingIndicator(size: 20)),
            ),
            error: (error, _) => AlertDialog(
              title: Text(l10n.selectCurrency),
              content: Text(l10n.errorLoadingData(error.toString())),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.done),
                ),
              ],
            ),
            data: (currencies) {
              final selectable =
                  currencies.where(isSelectableFiatCurrency).toList()
                    ..sort((a, b) => a.code.compareTo(b.code));
              return SimpleDialog(
                title: Text(l10n.selectCurrency),
                children: selectable
                    .map(
                      (currency) => SimpleDialogOption(
                        onPressed: () => _confirmPrimaryCurrencyChange(
                          pickerContext: ctx,
                          current: current,
                          selected: currency,
                        ),
                        child: Row(
                          children: [
                            if (currency.code == current.code)
                              const Icon(Icons.check, size: 18)
                            else
                              const SizedBox(width: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.currencyPair(
                                  currency.name,
                                  currency.symbol,
                                ),
                                style: currency.code == current.code
                                    ? const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      )
                                    : null,
                              ),
                            ),
                            if (currency.code == current.code) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(l10n.primaryCurrencyCurrent),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmPrimaryCurrencyChange({
    required BuildContext pickerContext,
    required FireflyCurrency current,
    required FireflyCurrency selected,
  }) async {
    if (selected.code == current.code) {
      Navigator.pop(pickerContext);
      return;
    }

    final l10n = context.l10n;
    final confirmed = await showConfirmationDialog(
      context: pickerContext,
      title: l10n.changePrimaryCurrencyTitle,
      message: l10n.changePrimaryCurrencyMessage(
        selected.code,
        l10n.primaryCurrencyChangeWarning,
      ),
      confirmLabel: l10n.changePrimaryCurrencyConfirm,
    );
    if (confirmed != true || !pickerContext.mounted) return;

    await _applyPrimaryCurrency(
      context: pickerContext,
      current: current,
      selected: selected,
    );
  }

  Future<void> _applyPrimaryCurrency({
    required BuildContext context,
    required FireflyCurrency current,
    required FireflyCurrency selected,
  }) async {
    if (selected.code == current.code) {
      Navigator.pop(context);
      return;
    }

    final l10n = context.l10n;
    final service = ref.read(apiServiceProvider);
    if (service == null) return;

    try {
      await service.setPrimaryCurrency(selected.code);
      ref.invalidate(primaryCurrencyProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.primaryCurrencyChanged(selected.code))),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToSetPrimaryCurrency(error.toString())),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final appLocale = ref.watch(localeProvider);
    final currencyAsync = ref.watch(primaryCurrencyProvider);
    final pageSize = ref.watch(transactionPageSizeProvider);
    final pageSizeNotifier = ref.read(transactionPageSizeProvider.notifier);
    final defaultPeriod = ref.watch(defaultDashboardPeriodProvider);
    final undoState = ref.watch(undoHistoryProvider);
    final undoNotifier = ref.read(undoHistoryProvider.notifier);
    final showDeviceAppearance = !ref.watch(peopleProvider).isEnabled;

    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        Text(
          l10n.settingsTitle,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              if (showDeviceAppearance) ...[
                Tooltip(
                  message: l10n.selectLanguage,
                  child: ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(l10n.language),
                    trailing: Text(
                      l10n.languageDisplayName(appLocale.languageCode),
                    ),
                    onTap: () => _showLanguagePicker(context),
                  ),
                ),
                const Divider(height: 1),
                Tooltip(
                  message: l10n.formattingDescription,
                  child: ListTile(
                    leading: const Icon(Icons.numbers),
                    title: Text(l10n.numberFormat),
                    trailing: Text(
                      _formattingLabel(
                        ref.watch(numberLocaleProvider),
                        sample: context.format.formatNumber(1234.56),
                      ),
                    ),
                    onTap: () => _showFormattingPicker(
                      context,
                      title: l10n.selectNumberFormat,
                      provider: numberLocaleProvider,
                      sample: (format) => format.formatNumber(1234.56),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Tooltip(
                  message: l10n.formattingDescription,
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(l10n.dateFormat),
                    trailing: Text(
                      _formattingLabel(
                        ref.watch(dateLocaleProvider),
                        sample: context.format.formatMediumDate(_sampleDate),
                      ),
                    ),
                    onTap: () => _showFormattingPicker(
                      context,
                      title: l10n.selectDateFormat,
                      provider: dateLocaleProvider,
                      sample: (format) => format.formatMediumDate(_sampleDate),
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],
              currencyAsync.when(
                loading: () => ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: Text(l10n.defaultCurrency),
                  trailing: const SmallLoadingIndicator(),
                ),
                error: (e, st) => ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: Text(l10n.defaultCurrency),
                  subtitle: Text(
                    l10n.connectToFireflyToLoad,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                data: (currency) => Tooltip(
                  message: l10n.selectCurrency,
                  child: ListTile(
                    leading: const Icon(Icons.attach_money),
                    title: Text(l10n.defaultCurrency),
                    trailing: Text(
                      l10n.currencyPair(currency.name, currency.symbol),
                    ),
                    onTap: () => _showCurrencyPicker(context, currency),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDeviceAppearance) ...[
          const SizedBox(height: 24),
          Text(l10n.appearance, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                Tooltip(
                  message: l10n.raccoonMode,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.pets),
                    title: Text(l10n.raccoonMode),
                    subtitle: Text(l10n.appTagline),
                    value: themeSettings.isRaccoonMode,
                    onChanged: (val) {
                      final previous = themeSettings.funMode;
                      final next = val ? FunMode.raccoon : FunMode.none;
                      themeNotifier.setRaccoonMode(val);
                      undoNotifier.record(
                        title: 'Fun mode changed',
                        details: 'Fun mode: ${previous.name} -> ${next.name}',
                        type: UndoActionType.themeFunMode,
                        undoPayload: {'funMode': previous.name},
                        redoPayload: {'funMode': next.name},
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Tooltip(
                  message: l10n.themeStyleSubtitle,
                  child: ListTile(
                    leading: const Icon(Icons.color_lens),
                    title: Text(l10n.themeStyle),
                    trailing: Text(
                      themeStyleSummary(
                        context,
                        mode: themeSettings.themeMode,
                        palette: themeSettings.paletteType,
                        accent: themeSettings.accentType,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () => showThemeStylePicker(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          l10n.dataAndLoading,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              Tooltip(
                message: l10n.defaultPeriodDescription,
                child: ListTile(
                  leading: const Icon(Icons.date_range),
                  title: Text(l10n.defaultPeriod),
                  subtitle: Text(l10n.defaultPeriodDescription),
                  trailing: Text(
                    defaultPeriod.localizedLabel(l10n),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => _showDefaultPeriodPicker(context),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_repeat),
                      title: Text(l10n.writeAheadDays),
                      subtitle: Text(l10n.writeAheadDaysDescription),
                      trailing: DropdownButton<int>(
                        value: ref.watch(writeAheadDaysProvider),
                        items: [
                          for (final days in kWriteAheadDayChoices)
                            DropdownMenuItem(
                              value: days,
                              child: Text(
                                days == 0
                                    ? l10n.writeAheadOff
                                    : l10n.writeAheadNDays(days),
                              ),
                            ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          await ref
                              .read(writeAheadDaysProvider.notifier)
                              .setDays(value);
                          if (value > 0) {
                            final result = await runWriteAheadNow(ref);
                            if (!context.mounted) return;
                            if (result.hasFailures) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Write-ahead created ${result.created}, '
                                    'failed ${result.failed}',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.view_list),
                      title: Text(l10n.transactionPageSize),
                      subtitle: Text(l10n.transactionPageSizeDescription),
                    ),
                    Tooltip(
                      message: l10n.transactionPageSizeDescription,
                      child: Slider(
                        value: transactionPageSizeSliderIndex(
                          pageSize,
                        ).toDouble(),
                        min: 0,
                        max: kTransactionPageSizeSteps.toDouble(),
                        divisions: kTransactionPageSizeSteps,
                        label: l10n.transactionPageSizeValue(pageSize),
                        onChanged: (value) => pageSizeNotifier
                            .setPageSizeFromSliderIndex(value.round()),
                        onChangeEnd: (value) {
                          final next = transactionPageSizeFromSliderIndex(
                            value.round(),
                          );
                          if (next == pageSize) return;
                          undoNotifier.record(
                            title: 'Transaction page size changed',
                            details:
                                'Transaction page size: $pageSize -> $next',
                            type: UndoActionType.transactionPageSize,
                            undoPayload: {'pageSize': pageSize},
                            redoPayload: {'pageSize': next},
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        l10n.transactionPageSizeValue(pageSize),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(l10n.advanced, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(l10n.undoHistorySize),
                  subtitle: Text(
                    l10n.undoHistoryStoredEntries(
                      undoState.entries.length,
                      undoState.limit,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: undoState.entries.isEmpty
                        ? null
                        : () => undoNotifier.clearHistory(),
                    child: Text(l10n.clear),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.go('/history'),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(l10n.openHistoryScreen),
                  ),
                ),
                Slider(
                  value: undoState.limit.toDouble(),
                  min: kUndoHistoryMinLimit.toDouble(),
                  max: kUndoHistoryMaxLimit.toDouble(),
                  divisions:
                      (kUndoHistoryMaxLimit - kUndoHistoryMinLimit) ~/ 10,
                  label: undoState.limit.toString(),
                  onChanged: (value) {
                    undoNotifier.setLimit(value.round());
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.undoHistoryLimitRange(
                      kUndoHistoryMinLimit,
                      kUndoHistoryDefaultLimit,
                      kUndoHistoryMaxLimit,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const PeopleSettingsSection(),
        const SizedBox(height: 24),
        Text(
          l10n.settingsBackup,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        const SettingsBackupSection(),
        const SizedBox(height: 24),
        // Its own section rather than part of the one above: that one exports
        // FireRaccoon's settings, this one copies the ledger they point at.
        Text(
          l10n.fireflyBackups,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        const FireflyBackupSection(),
        const SizedBox(height: 24),
        const SideMenuSettingsSection(),
        if (ref.watch(canManageFireflyConnectionProvider)) ...[
          const SizedBox(height: 24),
          Text(
            l10n.backendConnection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                Tooltip(
                  message: l10n.fireflyConnectionTitle,
                  child: ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(l10n.serverUrl),
                    subtitle: Text(
                      ref.watch(authProvider).serverUrl.isEmpty
                          ? l10n.notConnected
                          : ref.watch(authProvider).serverUrl,
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _showAuthDialog(context, ref),
                  ),
                ),
                const Divider(height: 1),
                Tooltip(
                  message: l10n.authenticationMethod,
                  child: ListTile(
                    leading: const Icon(Icons.key),
                    title: Text(
                      ref.watch(authProvider).authMode == AuthMode.oauth2
                          ? l10n.oauth2Connection
                          : l10n.personalAccessToken,
                    ),
                    subtitle: Text(
                      ref.watch(authProvider).apiToken.isEmpty
                          ? l10n.notSet
                          : '•••••••••••••••••••••••••',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _showAuthDialog(context, ref),
                  ),
                ),
                if (ref.watch(authProvider).isValid) ...[
                  const Divider(height: 1),
                  Tooltip(
                    message: l10n.disconnect,
                    child: ListTile(
                      leading: Icon(Icons.logout, color: colors.danger),
                      title: Text(
                        l10n.disconnect,
                        style: TextStyle(color: colors.danger),
                      ),
                      // Deleting the token and URL from the keychain cannot be
                      // undone, and there is no copy anywhere else. Ask, the
                      // way every other irreversible action here asks.
                      onTap: () async {
                        final confirmed = await showConfirmationDialog(
                          context: context,
                          title: l10n.disconnectConfirmTitle,
                          message: l10n.disconnectConfirmMessage,
                          confirmLabel: l10n.disconnect,
                        );
                        if (confirmed != true) return;
                        await ref.read(authProvider.notifier).clearSettings();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        // Its own section, not part of the Firefly connection: these credentials
        // are for agents talking to FireRaccoon, and any signed-in person may
        // issue one for themselves rather than only a connection admin.
        if (mcpDesktopSupported ||
            ref.watch(deploymentConfigProvider).isServer) ...[
          const SizedBox(height: 24),
          Text(
            l10n.mcpServerCredentials,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          const Card(child: McpSettingsSection()),
        ],
        const SizedBox(height: 24),
        Text(
          l10n.recentProblems,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        const Card(child: DiagnosticsSection()),
        ...ref
            .watch(packageInfoProvider)
            .when(
              data: (info) => [
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    l10n.appVersion('${info.version}+${info.buildNumber}'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              loading: () => const <Widget>[],
              error: (_, _) => const <Widget>[],
            ),
      ],
    );
  }
}
