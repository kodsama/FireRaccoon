import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/router/route_query.dart';

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

  group('repeated keys', () {
    test('build writes one pair per value and values reads them back', () {
      final link = RouteQuery.build('/stats', {
        'tag': ['Holiday', 'Work, travel'],
        'budget': const <String>[],
        'period': 'year',
      });
      final uri = Uri.parse(link);
      expect(RouteQuery.values(uri, 'tag'), {'Holiday', 'Work, travel'});
      expect(RouteQuery.values(uri, 'budget'), isEmpty);
      expect(uri.queryParameters['period'], 'year');
    });

    test('adding or dropping the search keeps every repeated value', () {
      final uri = Uri.parse('/stats?tag=a&tag=b');
      final searched = Uri.parse(RouteQuery.withSearch(uri, 'rent'));
      expect(RouteQuery.values(searched, 'tag'), {'a', 'b'});
      expect(RouteQuery.searchFrom(searched), 'rent');

      final carried = Uri.parse(
        RouteQuery.preserveSearch(searched, '/transactions?tag=a&tag=b'),
      );
      expect(RouteQuery.values(carried, 'tag'), {'a', 'b'});
      expect(RouteQuery.searchFrom(carried), 'rent');
    });
  });
}
