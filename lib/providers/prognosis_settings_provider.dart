import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_prognosis.dart';
import 'theme_provider.dart';

class PrognosisSettings {
  final PrognosisHorizon horizon;

  /// The day the forecast runs to on [PrognosisHorizon.customDate]. Kept while
  /// another horizon is chosen, so coming back to it does not ask again.
  final DateTime? customHorizonDate;
  final PrognosisInclusionOptions inclusion;
  final double marginPercent;

  const PrognosisSettings({
    required this.horizon,
    required this.inclusion,
    required this.marginPercent,
    this.customHorizonDate,
  });

  PrognosisSettings copyWith({
    PrognosisHorizon? horizon,
    DateTime? customHorizonDate,
    PrognosisInclusionOptions? inclusion,
    double? marginPercent,
  }) {
    return PrognosisSettings(
      horizon: horizon ?? this.horizon,
      customHorizonDate: customHorizonDate ?? this.customHorizonDate,
      inclusion: inclusion ?? this.inclusion,
      marginPercent: marginPercent ?? this.marginPercent,
    );
  }

  PrognosisOptions toOptions({DateTime? reference}) {
    return PrognosisOptions(
      horizon: horizon,
      customHorizonDate: customHorizonDate,
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
      horizon: _readHorizon(),
      customHorizonDate: _readCustomHorizonDate(),
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

  PrognosisHorizon _readHorizon() {
    final raw = _prefs.getString('prognosisHorizon');
    return PrognosisHorizon.values.firstWhere(
      (horizon) => horizon.name == raw,
      orElse: () => PrognosisHorizon.endOfNextMonth,
    );
  }

  DateTime? _readCustomHorizonDate() {
    final raw = _prefs.getString('prognosisCustomHorizonDate');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  void setHorizon(PrognosisHorizon horizon) {
    state = state.copyWith(horizon: horizon);
    _prefs.setString('prognosisHorizon', horizon.name);
  }

  void setCustomHorizonDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    state = state.copyWith(customHorizonDate: day);
    _prefs.setString('prognosisCustomHorizonDate', day.toIso8601String());
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
    final customDate = settings.customHorizonDate;
    if (customDate != null) setCustomHorizonDate(customDate);
    setHorizon(settings.horizon);
    setInclusion(settings.inclusion);
    setMarginPercent(settings.marginPercent);
  }
}

final prognosisSettingsProvider =
    NotifierProvider<PrognosisSettingsNotifier, PrognosisSettings>(
      PrognosisSettingsNotifier.new,
    );
