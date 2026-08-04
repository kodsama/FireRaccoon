import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/router/projection_route.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('ProjectionPeriodX', () {
    test('months and labels map correctly', () {
      expect(ProjectionPeriod.m3.months, 3);
      expect(ProjectionPeriod.m6.months, 6);
      expect(ProjectionPeriod.y1.months, 12);
      expect(ProjectionPeriod.y3.months, 36);
      expect(ProjectionPeriod.y1.label, '1 Year');
      expect(ProjectionPeriod.y3.label, '3 Years');
    });
  });

  group('ProjectionRoute parsing', () {
    test('uses defaults for invalid query values', () {
      final params = ProjectionRoute.paramsFromUri(
        Uri.parse('/projection?type=invalid&period=invalid&chart=invalid'),
      );

      expect(params.type, ProjectionType.savings);
      expect(params.months, 6);
      expect(params.chartStyle, ProjectionChartStyle.fan);
      expect(params.whatIfPercent, 0);
    });

    test('clamps what-if, rate and volatility', () {
      final params = ProjectionRoute.paramsFromUri(
        Uri.parse('/projection?whatif=80&rate=50&vol=0&period=y3'),
      );

      expect(params.months, 36);
      expect(params.whatIfPercent, 40);
      expect(params.annualReturnPercent, 30);
      expect(params.volatilityPercent, 1);
    });

    test('location omits default params and keeps non-defaults', () {
      expect(ProjectionRoute.location(), '/projection');
      expect(
        ProjectionRoute.location(
          period: ProjectionPeriod.m3,
          type: ProjectionType.portfolio,
          chart: ProjectionChartStyle.lines,
          whatIf: 10,
          rate: 9.5,
          vol: 20,
        ),
        '/projection?period=m3&type=portfolio&whatif=10&rate=9.5&vol=20.0&chart=lines',
      );
    });

    test('state wrappers delegate to uri parsers', () {
      final state = _RouteStateStub(
        Uri.parse('/projection?period=y1&type=compound'),
      );
      expect(ProjectionRoute.periodFrom(state), ProjectionPeriod.y1);
      expect(ProjectionRoute.paramsFrom(state).type, ProjectionType.compound);
    });
  });
}

class _RouteStateStub extends Fake implements GoRouterState {
  _RouteStateStub(this._uri);
  final Uri _uri;

  @override
  Uri get uri => _uri;
}
