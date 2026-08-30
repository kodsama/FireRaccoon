import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/router/liabilities_route.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('LiabilitiesRoute', () {
    test('location without account returns base path', () {
      expect(LiabilitiesRoute.location(), '/liabilities');
    });

    test('location with account encodes query parameter', () {
      expect(
        LiabilitiesRoute.location(account: 'Credit Card'),
        '/liabilities?account=Credit+Card',
      );
    });

    test('location includes showInactive when enabled', () {
      expect(
        LiabilitiesRoute.location(showInactive: true),
        '/liabilities?showInactive=true',
      );
    });

    test('showInactiveFromUri reads query parameter', () {
      expect(
        LiabilitiesRoute.showInactiveFromUri(
          Uri.parse('/liabilities?showInactive=true'),
        ),
        isTrue,
      );
    });

    test('accountFromUri reads account query parameter', () {
      expect(
        LiabilitiesRoute.accountFromUri(Uri.parse('/liabilities?account=Loan')),
        'Loan',
      );
    });

    test('accountFrom reads account from router state', () {
      expect(
        LiabilitiesRoute.accountFrom(
          _RouteStateStub(Uri.parse('/liabilities?account=Mortgage')),
        ),
        'Mortgage',
      );
    });
  });
}

class _RouteStateStub extends Fake implements GoRouterState {
  _RouteStateStub(this._uri);
  final Uri _uri;

  @override
  Uri get uri => _uri;
}
