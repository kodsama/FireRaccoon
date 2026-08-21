import 'package:fireracoon_engine/utils/dashboard_period.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../deployment/deployment_providers.dart';
import '../fun_modes/fun_mode.dart';
import '../models/account_prognosis.dart';
import '../models/people_models.dart';
import '../models/settings_bundle.dart';
import '../models/side_menu_config.dart';
import '../theme/app_colors.dart';
import '../theme/theme_palette.dart';
import 'account_classification_provider.dart';
import 'auth_provider.dart';
import 'column_config_provider.dart';
import 'default_period_provider.dart';
import 'locale_provider.dart';
import 'people_providers.dart';
import 'prognosis_settings_provider.dart';
import 'server_session_provider.dart';
import 'side_menu_config_provider.dart';
import 'theme_provider.dart';
import 'tight_rows_columns_provider.dart';
import 'transaction_page_size_provider.dart';
import 'undo_history_provider.dart';
import 'view_mode_provider.dart';
import 'write_ahead_provider.dart';

/// Builds and applies portable settings bundles.
///
/// Firefly tokens and salted password hashes are carried in memory and sealed
/// with a backup passphrase on disk. Omits biometrics and custom avatar bytes.
/// Local and server mode export the same secrets shape; server mode loads PAT
/// and hashes from an admin-only backup endpoint.
class SettingsExportImport {
  SettingsExportImport(this._ref);

  final Ref _ref;

  Future<SettingsBundle> buildBundle() async {
    final theme = _ref.read(themeProvider);
    final locale = _ref.read(localeProvider);
    final peopleState = _ref.read(peopleProvider);
    final classifications = _ref.read(accountClassificationProvider);
    final sideMenu = _ref.read(sideMenuConfigProvider);
    final accountColumns = _ref.read(accountColumnConfigProvider);
    final transactionColumns = _ref.read(transactionColumnConfigProvider);
    final viewMode = _ref.read(viewModeProvider);
    final tightColumns = _ref.read(tightRowsColumnsProvider);
    final prognosis = _ref.read(prognosisSettingsProvider);
    final auth = _ref.read(authProvider);
    final isServer = _ref.read(deploymentConfigProvider).isServer;
    final defaultPeriod = _ref.read(defaultDashboardPeriodProvider).name;
    final transactionPageSize = _ref.read(transactionPageSizeProvider);
    final writeAheadDays = _ref.read(writeAheadDaysProvider);
    final undoHistoryLimit = _ref.read(undoHistoryProvider).limit;

    SettingsFireflyBundle? firefly;
    var people = peopleState.people;
    var requirePasswordLogin = peopleState.requirePasswordLogin;

    if (isServer) {
      final secrets = await _loadServerBackupSecrets();
      if (secrets != null) {
        final fireflyRaw = secrets['firefly'];
        if (fireflyRaw is Map) {
          final map = fireflyRaw.map((k, v) => MapEntry(k.toString(), v));
          final url = map['url'] as String? ?? '';
          final token = map['token'] as String? ?? '';
          if (url.isNotEmpty && token.isNotEmpty) {
            firefly = SettingsFireflyBundle(
              serverUrl: url,
              apiToken: token,
              allowInsecure: map['allowInsecure'] == true,
            );
          }
        }
        requirePasswordLogin =
            secrets['requirePasswordLogin'] as bool? ?? requirePasswordLogin;
        people = _peopleWithImportedAuth(people, secrets['peopleAuth']);
      }
    } else if (auth.serverUrl.isNotEmpty && auth.apiToken.isNotEmpty) {
      firefly = SettingsFireflyBundle(
        serverUrl: auth.serverUrl,
        apiToken: auth.apiToken,
        authMode: auth.authMode.name,
        allowInsecure: auth.allowInsecure,
      );
    }

    return SettingsBundle(
      schemaVersion: kSettingsBundleSchemaVersion,
      exportedAtIso: DateTime.now().toUtc().toIso8601String(),
      device: {
        'themeMode': theme.themeMode.name,
        'paletteType': theme.paletteType.name,
        'accentType': theme.accentType.name,
        'funMode': theme.funMode.name,
        'locale': locale.languageCode,
        'defaultDashboardPeriod': defaultPeriod,
        'transactionPageSize': transactionPageSize,
        'recurrenceWriteAheadDays': writeAheadDays,
        'undoHistoryLimit': undoHistoryLimit,
      },
      people: exportPeopleBundle(
        people: people,
        accountOwnerships: peopleState.config.accountOwnerships,
        requirePasswordLogin: requirePasswordLogin,
      ),
      firefly: firefly,
      accountClassifications: {
        for (final e in classifications.entries) e.key: e.value.name,
      },
      sideMenu: sideMenu.toJson(),
      accountColumns: accountColumns.toJson(),
      transactionColumns: transactionColumns.toJson(),
      viewMode: viewMode.name,
      tightRowsColumns: tightColumns.map((c) => c.name).toList(),
      prognosis: {
        'mode': prognosis.mode.name,
        'horizon': prognosis.horizon.name,
        'marginPercent': prognosis.marginPercent,
        'inclusion': {
          'includeScheduledTransactions':
              prognosis.inclusion.includeScheduledTransactions,
          'includeRecurringTransactions':
              prognosis.inclusion.includeRecurringTransactions,
          'includeBills': prognosis.inclusion.includeBills,
          'includeIncome': prognosis.inclusion.includeIncome,
          'includeExpenses': prognosis.inclusion.includeExpenses,
          'includeTransfers': prognosis.inclusion.includeTransfers,
          'includeCreditCards': prognosis.inclusion.includeCreditCards,
          'includeLiabilities': prognosis.inclusion.includeLiabilities,
        },
      },
    );
  }

  Future<Map<String, dynamic>?> _loadServerBackupSecrets() async {
    final client = _ref.read(serverSessionProvider.notifier).client;
    if (client == null || client.sessionToken == null) return null;
    try {
      return await client.fetchBackupSecrets();
    } on Object {
      return null;
    }
  }

  List<Person> _peopleWithImportedAuth(
    List<Person> people,
    Object? peopleAuthRaw,
  ) {
    if (peopleAuthRaw is! Map) {
      return [
        for (final person in people) person.copyWith(clearPassword: true),
      ];
    }
    return people.map((person) {
      final raw = peopleAuthRaw[person.id];
      if (raw is! Map) return person.copyWith(clearPassword: true);
      final auth = raw.map((k, v) => MapEntry(k.toString(), v));
      final hash = auth['passwordHash'] as String?;
      final salt = auth['salt'] as String? ?? auth['passwordSalt'] as String?;
      if (!isPortablePasswordMaterial(passwordHash: hash, salt: salt)) {
        return person.copyWith(clearPassword: true);
      }
      return person.copyWith(passwordHash: hash, salt: salt);
    }).toList();
  }

  /// Overwrites local settings from [bundle].
  ///
  /// Restores Firefly credentials when the file includes them; otherwise
  /// leaves the destination connection alone. Restores salted password hashes
  /// and re-enables password login only when every imported person has one.
  Future<void> applyBundle(SettingsBundle bundle) async {
    final device = bundle.device;

    final themeModeName = device['themeMode'] as String?;
    final paletteName = device['paletteType'] as String?;
    final accentName = device['accentType'] as String?;
    final funModeName = device['funMode'] as String?;
    final themeNotifier = _ref.read(themeProvider.notifier);
    themeNotifier.applyStyle(
      themeMode: themeModeName == null
          ? null
          : ThemeMode.values.firstWhere(
              (m) => m.name == themeModeName,
              orElse: () => ThemeMode.system,
            ),
      paletteType: paletteName == null
          ? null
          : ThemePaletteType.values.firstWhere(
              (p) => p.name == paletteName,
              orElse: () => ThemePaletteType.classic,
            ),
      accentType: accentName == null
          ? null
          : AccentColorType.values.firstWhere(
              (a) => a.name == accentName,
              orElse: () => AccentColorType.blue,
            ),
    );
    if (funModeName != null) {
      themeNotifier.setFunMode(
        FunMode.values.firstWhere(
          (m) => m.name == funModeName,
          orElse: () => FunMode.none,
        ),
      );
    }

    final localeCode = device['locale'] as String?;
    if (localeCode != null) {
      await _ref
          .read(localeProvider.notifier)
          .setLocale(AppLocale.fromCode(localeCode));
    }

    final periodName = device['defaultDashboardPeriod'] as String?;
    if (periodName != null) {
      final period = DashboardPeriod.values.firstWhere(
        (p) => p.name == periodName,
        orElse: () => DashboardPeriod.thisMonth,
      );
      await _ref
          .read(defaultDashboardPeriodProvider.notifier)
          .setPeriod(period);
    }

    final pageSize = device['transactionPageSize'];
    if (pageSize is int) {
      await _ref
          .read(transactionPageSizeProvider.notifier)
          .setPageSize(pageSize);
    }

    final writeAhead = device['recurrenceWriteAheadDays'];
    if (writeAhead is int) {
      await _ref.read(writeAheadDaysProvider.notifier).setDays(writeAhead);
    }

    final undoLimit = device['undoHistoryLimit'];
    if (undoLimit is int) {
      await _ref.read(undoHistoryProvider.notifier).setLimit(undoLimit);
    }

    final firefly = bundle.firefly;
    if (firefly != null && firefly.isValid) {
      if (_ref.read(deploymentConfigProvider).isServer) {
        final client = _ref.read(serverSessionProvider.notifier).client;
        if (client != null && client.sessionToken != null) {
          await client.putFirefly(
            url: firefly.serverUrl,
            token: firefly.apiToken,
            allowInsecure: firefly.allowInsecure,
          );
        }
      } else {
        await _ref
            .read(authProvider.notifier)
            .applyImportedCredentials(
              serverUrl: firefly.serverUrl,
              apiToken: firefly.apiToken,
              authMode: firefly.authMode == 'oauth2'
                  ? AuthMode.oauth2
                  : AuthMode.token,
              allowInsecure: firefly.allowInsecure,
            );
      }
    }

    await _ref
        .read(peopleProvider.notifier)
        .importSettings(
          people: bundle.people.people,
          accountOwnerships: bundle.people.accountOwnerships,
          requirePasswordLogin: bundle.people.requirePasswordLogin,
        );

    final classifications = <String, AccountCategory>{};
    for (final e in bundle.accountClassifications.entries) {
      final category = AccountCategory.fromName(e.value);
      if (category != null) classifications[e.key] = category;
    }
    await _ref
        .read(accountClassificationProvider.notifier)
        .replaceAll(classifications);

    final sideMenuJson = bundle.sideMenu;
    if (sideMenuJson != null) {
      _ref
          .read(sideMenuConfigProvider.notifier)
          .replaceConfig(SideMenuConfig.fromJson(sideMenuJson));
    }

    final accountColumnsJson = bundle.accountColumns;
    if (accountColumnsJson != null) {
      _ref
          .read(accountColumnConfigProvider.notifier)
          .replaceConfig(AccountColumnConfig.fromJson(accountColumnsJson));
    }

    final txColumnsJson = bundle.transactionColumns;
    if (txColumnsJson != null) {
      _ref
          .read(transactionColumnConfigProvider.notifier)
          .replaceConfig(TransactionColumnConfig.fromJson(txColumnsJson));
    }

    final viewModeName = bundle.viewMode;
    if (viewModeName != null) {
      final mode = ViewMode.values.firstWhere(
        (m) => m.name == viewModeName,
        orElse: () => ViewMode.standard,
      );
      await _ref.read(viewModeProvider.notifier).setMode(mode);
    }

    final tight = bundle.tightRowsColumns;
    if (tight != null) {
      final columns = tight
          .map(
            (name) => TightRowColumn.values.firstWhere(
              (c) => c.name == name,
              orElse: () => TightRowColumn.date,
            ),
          )
          .toSet();
      await _ref.read(tightRowsColumnsProvider.notifier).setColumns(columns);
    }

    final prognosisJson = bundle.prognosis;
    if (prognosisJson != null) {
      final inclusionRaw =
          prognosisJson['inclusion'] as Map<String, dynamic>? ?? const {};
      final inclusion = PrognosisInclusionOptions(
        includeScheduledTransactions:
            inclusionRaw['includeScheduledTransactions'] as bool? ?? true,
        includeRecurringTransactions:
            inclusionRaw['includeRecurringTransactions'] as bool? ?? true,
        includeBills: inclusionRaw['includeBills'] as bool? ?? true,
        includeIncome: inclusionRaw['includeIncome'] as bool? ?? true,
        includeExpenses: inclusionRaw['includeExpenses'] as bool? ?? true,
        includeTransfers: inclusionRaw['includeTransfers'] as bool? ?? true,
        includeCreditCards: inclusionRaw['includeCreditCards'] as bool? ?? true,
        includeLiabilities: inclusionRaw['includeLiabilities'] as bool? ?? true,
      );
      final modeName = prognosisJson['mode'] as String?;
      final horizonName = prognosisJson['horizon'] as String?;
      final margin = prognosisJson['marginPercent'];
      _ref
          .read(prognosisSettingsProvider.notifier)
          .replaceAll(
            PrognosisSettings(
              mode: PrognosisViewMode.values.firstWhere(
                (m) => m.name == modeName,
                orElse: () => PrognosisViewMode.expected,
              ),
              horizon: PrognosisHorizon.values.firstWhere(
                (h) => h.name == horizonName,
                orElse: () => PrognosisHorizon.endOfNextMonth,
              ),
              inclusion: inclusion,
              marginPercent: margin is num ? margin.toDouble() : 15,
            ),
          );
    }
  }
}

final settingsExportImportProvider = Provider<SettingsExportImport>((ref) {
  return SettingsExportImport(ref);
});
