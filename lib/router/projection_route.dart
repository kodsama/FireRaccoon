import 'package:go_router/go_router.dart';

import '../models/projection.dart';
import 'route_query.dart';

enum ProjectionPeriod { m3, m6, y1, y3 }

extension ProjectionPeriodX on ProjectionPeriod {
  int get months => switch (this) {
    ProjectionPeriod.m3 => 3,
    ProjectionPeriod.m6 => 6,
    ProjectionPeriod.y1 => 12,
    ProjectionPeriod.y3 => 36,
  };

  String get label => switch (this) {
    ProjectionPeriod.m3 => '3 Months',
    ProjectionPeriod.m6 => '6 Months',
    ProjectionPeriod.y1 => '1 Year',
    ProjectionPeriod.y3 => '3 Years',
  };
}

class ProjectionRoute {
  static const path = '/projection';

  static const _defaults = ProjectionParams();

  /// Deep link to the prognosis screen.
  ///
  /// Query params (`period`, `type`, `whatif`, …) are kept for parser
  /// compatibility and tests, but [PrognosisScreen] reads settings from
  /// [prognosisSettingsProvider] — not from the URL. Callers should use the
  /// bare path unless they intentionally preserve a bookmark shape.
  static String location({
    ProjectionPeriod period = ProjectionPeriod.m6,
    ProjectionType type = ProjectionType.savings,
    int whatIf = 0,
    double rate = 7.0,
    double vol = 12.0,
    ProjectionChartStyle chart = ProjectionChartStyle.fan,
  }) {
    final params = <String, String?>{
      if (period != ProjectionPeriod.m6) 'period': period.name,
      if (type != ProjectionType.savings) 'type': type.name,
      if (whatIf != 0) 'whatif': whatIf.toString(),
      if (rate != _defaults.annualReturnPercent)
        'rate': rate.toStringAsFixed(1),
      if (vol != _defaults.volatilityPercent) 'vol': vol.toStringAsFixed(1),
      if (chart != ProjectionChartStyle.fan) 'chart': chart.name,
    };
    // Prefer bare path for in-app navigation; only emit query when non-default
    // (legacy bookmark shape — ignored by PrognosisScreen).
    if (params.isEmpty) return path;
    return RouteQuery.build(path, params);
  }

  static ProjectionPeriod periodFrom(GoRouterState state) =>
      periodFromUri(state.uri);

  static ProjectionPeriod periodFromUri(Uri uri) {
    return RouteQuery.enumFrom(
      uri,
      'period',
      ProjectionPeriod.values,
      ProjectionPeriod.m6,
    );
  }

  static ProjectionParams paramsFrom(GoRouterState state) =>
      paramsFromUri(state.uri);

  static ProjectionParams paramsFromUri(Uri uri) {
    final period = periodFromUri(uri);
    final type = RouteQuery.enumFrom(
      uri,
      'type',
      ProjectionType.values,
      ProjectionType.savings,
    );
    final chart = RouteQuery.enumFrom(
      uri,
      'chart',
      ProjectionChartStyle.values,
      ProjectionChartStyle.fan,
    );
    final whatIf = int.tryParse(uri.queryParameters['whatif'] ?? '') ?? 0;
    final rate =
        double.tryParse(uri.queryParameters['rate'] ?? '') ??
        _defaults.annualReturnPercent;
    final vol =
        double.tryParse(uri.queryParameters['vol'] ?? '') ??
        _defaults.volatilityPercent;

    return ProjectionParams(
      type: type,
      months: period.months,
      whatIfPercent: whatIf.clamp(0, 40),
      annualReturnPercent: rate.clamp(0, 30),
      volatilityPercent: vol.clamp(1, 50),
      chartStyle: chart,
    );
  }
}
