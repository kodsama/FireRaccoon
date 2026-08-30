import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/services/biometric_auth.dart';

import '../helpers/fake_biometric_auth.dart';

void main() {
  test(
    'LocalBiometricAuth reports unavailable when facade is unavailable',
    () async {
      final auth = LocalBiometricAuth(
        factory: () => FakeLocalAuthenticationFacade(
          canCheck: false,
          deviceSupported: false,
        ),
      );
      expect(await auth.isAvailable, isFalse);
      expect(await auth.authenticate(localizedReason: 'test'), isFalse);
    },
  );

  test('LocalBiometricAuth authenticates through the facade', () async {
    final auth = LocalBiometricAuth(
      factory: () => FakeLocalAuthenticationFacade(authenticateResult: true),
    );
    expect(await auth.isAvailable, isTrue);
    expect(await auth.authenticate(localizedReason: 'Unlock'), isTrue);
  });

  test(
    'LocalBiometricAuth returns false when facade authentication fails',
    () async {
      final auth = LocalBiometricAuth(
        factory: () => FakeLocalAuthenticationFacade(authenticateResult: false),
      );
      expect(await auth.authenticate(localizedReason: 'Unlock'), isFalse);
    },
  );
}
