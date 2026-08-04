import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_prognosis.dart';
import 'theme_provider.dart';

class PrognosisSettings {
  final PrognosisViewMode mode;
  final PrognosisHorizon horizon;
  final PrognosisInclusionOptions inclusion;
  final double marginPercent;

  const PrognosisSettings({
    required this.mode,
    required this.horizon,
    required this.inclusion,
    required this.marginPercent,
  });

  PrognosisSettings copyWith({
    PrognosisViewMode? mode,
    PrognosisHorizon? horizon,
    PrognosisInclusionOptions? inclusion,
    double? marginPercent,
  }) {
    return PrognosisSettings(
      mode: mode ?? this.mode,
      horizon: horizon ?? this.horizon,
      inclusion: inclusion ?? this.inclusion,
      marginPercent: marginPercent ?? this.marginPercent,
    );
  }

  PrognosisOptions toOptions({DateTime? reference}) {
    return PrognosisOptions(
      mode: mode,
      horizon: horizon,
      inclusion: inclusion,
      marginPercent: marginPercent,
      reference: reference,
    );
  }
}

class PrognosisSettingsNotifier extends Notifier<PrognosisSettings> {
  late SharedPreferences _prefs;

  static const _defaults = PrognosisInclusionOptions();

  @override
  PrognosisSettings build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return PrognosisSettings(
      mode: _readMode(),
      horizon: _readHorizon(),
      inclusion: PrognosisInclusionOptions(
        includeScheduledTransactions:
            _prefs.getBool('prognosisIncludeScheduledTransactions') ??
            _defaults.includeScheduledTransactions,
        includeRecurringTransactions:
            _prefs.getBool('prognosisIncludeRecurringTransactions') ??
            _defaults.includeRecurringTransactions,
        includeBills:
            _prefs.getBool('prognosisIncludeBills') ?? _defaults.includeBills,
        includeIncome:
            _prefs.getBool('prognosisIncludeIncome') ?? _defaults.includeIncome,
        includeExpenses:
            _prefs.getBool('prognosisIncludeExpenses') ??
            _defaults.includeExpenses,
        includeTransfers:
            _prefs.getBool('prognosisIncludeTransfers') ??
            _defaults.includeTransfers,
        includeCreditCards:
            _prefs.getBool('prognosisIncludeCreditCards') ??
            _prefs.getBool('prognosisIncludeCreditCardPayments') ??
            _defaults.includeCreditCards,
        includeLiabilities:
            _prefs.getBool('prognosisIncludeLiabilities') ??
            _defaults.includeLiabilities,
      ),
      marginPercent: _prefs.getDouble('prognosisMarginPercent') ?? 15,
    );
  }

  PrognosisViewMode _readMode() {
    final raw = _prefs.getString('prognosisViewMode');
    return PrognosisViewMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => PrognosisViewMode.expected,
    );
  }

  PrognosisHorizon _readHorizon() {
    final raw = _prefs.getString('prognosisHorizon');
    return PrognosisHorizon.values.firstWhere(
      (horizon) => horizon.name == raw,
      orElse: () => PrognosisHorizon.endOfNextMonth,
    );
  }

  void setMode(PrognosisViewMode mode) {
    state = state.copyWith(mode: mode);
    _prefs.setString('prognosisViewMode', mode.name);
  }

  void setHorizon(PrognosisHorizon horizon) {
    state = state.copyWith(horizon: horizon);
    _prefs.setString('prognosisHorizon', horizon.name);
  }

  void setInclusion(PrognosisInclusionOptions inclusion) {
    state = state.copyWith(inclusion: inclusion);
    _prefs.setBool(
      'prognosisIncludeScheduledTransactions',
      inclusion.includeScheduledTransactions,
    );
    _prefs.setBool(
      'prognosisIncludeRecurringTransactions',
      inclusion.includeRecurringTransactions,
    );
    _prefs.setBool('prognosisIncludeBills', inclusion.includeBills);
    _prefs.setBool('prognosisIncludeIncome', inclusion.includeIncome);
    _prefs.setBool('prognosisIncludeExpenses', inclusion.includeExpenses);
    _prefs.setBool('prognosisIncludeTransfers', inclusion.includeTransfers);
    _prefs.setBool('prognosisIncludeCreditCards', inclusion.includeCreditCards);
    _prefs.setBool(
      'prognosisIncludeCreditCardPayments',
      inclusion.includeCreditCards,
    );
    _prefs.setBool('prognosisIncludeLiabilities', inclusion.includeLiabilities);
  }

  void setMarginPercent(double value) {
    final clamped = value.clamp(0, 50).toDouble();
    state = state.copyWith(marginPercent: clamped);
    _prefs.setDouble('prognosisMarginPercent', clamped);
  }

  /// Overwrites all prognosis settings (settings import).
  void replaceAll(PrognosisSettings settings) {
    setMode(settings.mode);
    setHorizon(settings.horizon);
    setInclusion(settings.inclusion);
    setMarginPercent(settings.marginPercent);
  }
}

final prognosisSettingsProvider =
    NotifierProvider<PrognosisSettingsNotifier, PrognosisSettings>(
      PrognosisSettingsNotifier.new,
    );
