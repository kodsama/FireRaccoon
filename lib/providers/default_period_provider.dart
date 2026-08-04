import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../utils/period_defaults.dart';
import 'theme_provider.dart';

class DefaultPeriodNotifier extends Notifier<DashboardPeriod> {
  static const _prefsKey = 'defaultDashboardPeriod';
  static final _log = AppLogger.scoped('providers.default_period');

  @override
  DashboardPeriod build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final value = dashboardPeriodFromPrefs(prefs.getString(_prefsKey));
    _log.finer('Loaded default period preference: $value');
    return value;
  }

  Future<void> setPeriod(DashboardPeriod period) async {
    if (period == state) return;
    state = period;
    await ref.read(sharedPreferencesProvider).setString(_prefsKey, period.name);
    _log.info('Updated default period preference to ${period.name}');
  }
}

final defaultDashboardPeriodProvider =
    NotifierProvider<DefaultPeriodNotifier, DashboardPeriod>(
      DefaultPeriodNotifier.new,
    );
