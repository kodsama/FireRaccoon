import 'package:fireraccoon/router/accounts_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountsRoute', () {
    test('location omits showInactive by default', () {
      expect(AccountsRoute.location(), '/accounts');
    });

    test('location includes showInactive when enabled', () {
      expect(
        AccountsRoute.location(showInactive: true),
        '/accounts?showInactive=true',
      );
    });

    test('showInactiveFromUri reads query param', () {
      expect(
        AccountsRoute.showInactiveFromUri(
          Uri.parse('/accounts?showInactive=true'),
        ),
        isTrue,
      );
      expect(
        AccountsRoute.showInactiveFromUri(Uri.parse('/accounts')),
        isFalse,
      );
    });
  });
}
