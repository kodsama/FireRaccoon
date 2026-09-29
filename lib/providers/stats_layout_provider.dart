import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../router/route_query.dart';
import '../router/stats_route.dart';
import 'theme_provider.dart';

/// How far down Stats breaks each type: the types alone, or what is in them.
enum StatsLevel { types, groups }

/// How Stats lays out the types shown. Kept on the device rather than in the
/// link, so the page opens the way it was last left.
class StatsLayout {
  /// One chart for every type shown, or one chart each.
  final bool merged;
  final StatsLevel level;

  const StatsLayout({this.merged = false, this.level = StatsLevel.groups});
}

class StatsLayoutNotifier extends Notifier<StatsLayout> {
  static const _mergedKey = 'statsMerged';
  static const _levelKey = 'statsLevel';

  late SharedPreferences _prefs;

  @override
  StatsLayout build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final level = _prefs.getString(_levelKey);
    return StatsLayout(
      merged: _prefs.getBool(_mergedKey) ?? false,
      level: StatsLevel.values.firstWhere(
        (value) => value.name == level,
        orElse: () => StatsLevel.groups,
      ),
    );
  }

  void setMerged(bool merged) {
    state = StatsLayout(merged: merged, level: state.level);
    _prefs.setBool(_mergedKey, merged);
  }

  void setLevel(StatsLevel level) {
    state = StatsLayout(merged: state.merged, level: level);
    _prefs.setString(_levelKey, level.name);
  }
}

final statsLayoutProvider = NotifierProvider<StatsLayoutNotifier, StatsLayout>(
  StatsLayoutNotifier.new,
);

/// Where Stats was last left, so the side menu opens it there again rather
/// than on the defaults: the period, types, filters and charts as they were.
class StatsLastLocation {
  static const _key = 'statsLastChoice';

  final SharedPreferences _prefs;

  const StatsLastLocation(this._prefs);

  String get location => _prefs.getString(_key) ?? StatsRoute.path;

  /// The header search is left out, since the menu clears it on every other
  /// page it opens.
  void remember(Uri uri) {
    final params = Map.of(uri.queryParametersAll)..remove(RouteQuery.searchKey);
    final location = Uri(
      path: StatsRoute.path,
      queryParameters: params.isEmpty ? null : params,
    ).toString();
    if (_prefs.getString(_key) != location) _prefs.setString(_key, location);
  }
}

final statsLastLocationProvider = Provider<StatsLastLocation>(
  (ref) => StatsLastLocation(ref.watch(sharedPreferencesProvider)),
);
