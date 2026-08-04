import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/l10n/app_localizations.dart';
import 'package:fireracoon/l10n/l10n_extensions.dart';
import 'package:fireracoon/utils/locale_formatting.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

void main() {
  late AppLocalizations l10n;
  late LocaleFormatting format;

  setUp(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    format = LocaleFormatting(const Locale('en'));
  });

  group('localizedDashboardComparisonLabel', () {
    test('maps this year to previous year', () {
      expect(
        localizedDashboardComparisonLabel(
          l10n,
          format,
          period: DashboardPeriod.thisYear,
        ),
        'previous year',
      );
    });

    test('maps this month to previous month', () {
      expect(
        localizedDashboardComparisonLabel(
          l10n,
          format,
          period: DashboardPeriod.thisMonth,
        ),
        'previous month',
      );
    });

    test('formats custom range comparison as dates', () {
      expect(
        localizedDashboardComparisonLabel(
          l10n,
          format,
          period: DashboardPeriod.thisYear,
          customFrom: DateTime(2026, 3, 10),
          customTo: DateTime(2026, 3, 20),
        ),
        '2026-02-27 – 2026-03-09',
      );
    });
  });

  group('formatDeltaLabel', () {
    test('shows up arrow for positive percent change', () {
      const delta = DeltaResult(
        kind: DeltaKind.percent,
        percent: 31.0,
        isPositive: true,
      );

      expect(
        formatDeltaLabel(
          l10n,
          format,
          delta,
          comparisonPeriodLabel: 'previous year',
        ),
        '↑ 31.0% vs previous year',
      );
    });

    test('shows down arrow for negative percent change', () {
      const delta = DeltaResult(
        kind: DeltaKind.percent,
        percent: -6.6,
        isPositive: true,
      );

      expect(
        formatDeltaLabel(
          l10n,
          format,
          delta,
          comparisonPeriodLabel: 'previous year',
        ),
        '↓ 6.6% vs previous year',
      );
    });
  });
}
