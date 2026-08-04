import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/providers/prognosis_settings_provider.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> buildContainer(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads defaults when preferences are missing', () async {
    final container = await buildContainer({});
    final settings = container.read(prognosisSettingsProvider);

    expect(settings.mode, PrognosisViewMode.expected);
    expect(settings.horizon, PrognosisHorizon.endOfNextMonth);
    expect(settings.marginPercent, 15);
    expect(settings.inclusion.includeCreditCards, isTrue);
  });

  test('loads persisted and legacy inclusion keys', () async {
    final container = await buildContainer({
      'prognosisViewMode': 'projected',
      'prognosisHorizon': 'endOfMonth',
      'prognosisIncludeScheduledTransactions': false,
      'prognosisIncludeRecurringTransactions': false,
      'prognosisIncludeBills': false,
      'prognosisIncludeIncome': false,
      'prognosisIncludeExpenses': false,
      'prognosisIncludeTransfers': false,
      'prognosisIncludeCreditCardPayments': false,
      'prognosisIncludeLiabilities': false,
      'prognosisMarginPercent': 22.5,
    });
    final settings = container.read(prognosisSettingsProvider);

    expect(settings.mode, PrognosisViewMode.projected);
    expect(settings.horizon, PrognosisHorizon.endOfMonth);
    expect(settings.inclusion.includeScheduledTransactions, isFalse);
    expect(settings.inclusion.includeRecurringTransactions, isFalse);
    expect(settings.inclusion.includeBills, isFalse);
    expect(settings.inclusion.includeIncome, isFalse);
    expect(settings.inclusion.includeExpenses, isFalse);
    expect(settings.inclusion.includeTransfers, isFalse);
    expect(settings.inclusion.includeCreditCards, isFalse);
    expect(settings.inclusion.includeLiabilities, isFalse);
    expect(settings.marginPercent, 22.5);
  });

  test('setters persist and clamp values', () async {
    final container = await buildContainer({});
    final notifier = container.read(prognosisSettingsProvider.notifier);

    notifier.setMode(PrognosisViewMode.projected);
    notifier.setHorizon(PrognosisHorizon.endOfMonth);
    notifier.setInclusion(
      const PrognosisInclusionOptions(
        includeScheduledTransactions: false,
        includeRecurringTransactions: false,
        includeBills: false,
        includeIncome: false,
        includeExpenses: false,
        includeTransfers: false,
        includeCreditCards: false,
        includeLiabilities: false,
      ),
    );
    notifier.setMarginPercent(99);

    final state = container.read(prognosisSettingsProvider);
    expect(state.mode, PrognosisViewMode.projected);
    expect(state.horizon, PrognosisHorizon.endOfMonth);
    expect(state.inclusion.includeCreditCards, isFalse);
    expect(state.marginPercent, 50);
  });

  test('copyWith and toOptions keep selected values', () {
    const settings = PrognosisSettings(
      mode: PrognosisViewMode.expected,
      horizon: PrognosisHorizon.endOfMonth,
      inclusion: PrognosisInclusionOptions(includeIncome: false),
      marginPercent: 12,
    );
    final updated = settings.copyWith(marginPercent: 20);
    final options = updated.toOptions(reference: DateTime(2026, 7, 8));

    expect(updated.marginPercent, 20);
    expect(options.marginPercent, 20);
    expect(options.inclusion.includeIncome, isFalse);
    expect(options.horizon, PrognosisHorizon.endOfMonth);
  });
}
