import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon/providers/default_period_provider.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon/utils/period_defaults.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('period_defaults', () {
    test('expenseParamsFromDashboardPeriod maps this month', () {
      final params = expenseParamsFromDashboardPeriod(
        DashboardPeriod.thisMonth,
      );
      expect(params.period, ExpensePeriod.month);
      expect(params.from, isNull);
      expect(params.to, isNull);
    });

    test(
      'expenseParamsFromDashboardPeriod maps last 2 years to custom dates',
      () {
        final params = expenseParamsFromDashboardPeriod(
          DashboardPeriod.last2Years,
          reference: DateTime(2026, 7, 9),
        );
        expect(params.period, ExpensePeriod.month);
        expect(params.from, DateTime(2024, 7, 9));
        expect(params.to, DateTime(2026, 7, 9));
      },
    );

    test('dashboardPeriodFromPrefs falls back to this month', () {
      expect(dashboardPeriodFromPrefs(null), DashboardPeriod.thisMonth);
      expect(dashboardPeriodFromPrefs('invalid'), DashboardPeriod.thisMonth);
      expect(
        dashboardPeriodFromPrefs('lastQuarter'),
        DashboardPeriod.lastQuarter,
      );
    });
  });

  group('DefaultPeriodNotifier', () {
    test('persists selected period', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(defaultDashboardPeriodProvider),
        DashboardPeriod.thisMonth,
      );

      await container
          .read(defaultDashboardPeriodProvider.notifier)
          .setPeriod(DashboardPeriod.lastMonth);

      expect(
        container.read(defaultDashboardPeriodProvider),
        DashboardPeriod.lastMonth,
      );
      expect(prefs.getString('defaultDashboardPeriod'), 'lastMonth');
    });
  });
}
