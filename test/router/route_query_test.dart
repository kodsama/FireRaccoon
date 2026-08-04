import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/router/route_query.dart';

void main() {
  group('RouteQuery search', () {
    test('withSearch adds and removes q parameter', () {
      expect(
        RouteQuery.withSearch(Uri.parse('/accounts'), 'rent'),
        '/accounts?q=rent',
      );
      expect(
        RouteQuery.withSearch(Uri.parse('/accounts?q=rent'), ''),
        '/accounts',
      );
      expect(
        RouteQuery.withSearch(Uri.parse('/accounts?q=rent'), '   '),
        '/accounts',
      );
    });

    test('preserveSearch carries q into destination', () {
      expect(
        RouteQuery.preserveSearch(
          Uri.parse('/transactions?q=coffee'),
          '/transactions?account=Checking',
        ),
        '/transactions?account=Checking&q=coffee',
      );
    });

    test('preserveSearch does not override existing q', () {
      expect(
        RouteQuery.preserveSearch(
          Uri.parse('/transactions?q=coffee'),
          '/transactions?q=tea',
        ),
        '/transactions?q=tea',
      );
    });

    test('searchFrom reads q parameter', () {
      expect(
        RouteQuery.searchFrom(Uri.parse('/budgets?q=groceries')),
        'groceries',
      );
      expect(RouteQuery.searchFrom(Uri.parse('/budgets')), isNull);
    });
  });
}
