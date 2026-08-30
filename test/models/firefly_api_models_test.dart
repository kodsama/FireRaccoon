import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/models/currency.dart';
import 'package:fireraccoon/models/firefly_user.dart';

void main() {
  group('FireflyCurrency', () {
    test('fromJson parses primary currency response', () {
      final currency = FireflyCurrency.fromJson({
        'id': '1',
        'attributes': {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
      });

      expect(currency.id, '1');
      expect(currency.code, 'EUR');
      expect(currency.name, 'Euro');
      expect(currency.symbol, '€');
    });
  });

  group('FireflyUser', () {
    test('fromJson parses user response', () {
      final user = FireflyUser.fromJson({
        'id': '1',
        'attributes': {'email': 'admin@local.test'},
      });

      expect(user.id, '1');
      expect(user.email, 'admin@local.test');
      expect(user.displayName, 'Admin');
    });
  });
}
