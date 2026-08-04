import 'biometric_auth_facade.dart';

export 'biometric_auth_facade.dart';

/// Thin wrapper around platform biometrics so tests can inject a fake.
abstract class BiometricAuth {
  /// True when the device can prompt for biometrics or a device credential.
  Future<bool> get isAvailable;

  /// Prompts the system biometric / device-credential UI.
  /// Returns `true` on success, `false` when the user cancels or auth fails
  /// without throwing.
  Future<bool> authenticate({required String localizedReason});
}

/// Production implementation. Unavailable platforms (web, missing hardware)
/// report false rather than crashing the UI.
class LocalBiometricAuth implements BiometricAuth {
  LocalBiometricAuth({LocalAuthenticationFactory? factory})
    : _factory = factory ?? defaultLocalAuthenticationFactory;

  final LocalAuthenticationFactory _factory;

  @override
  Future<bool> get isAvailable async {
    try {
      final auth = _factory();
      return await auth.isDeviceSupported() || await auth.canCheckBiometrics;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      final auth = _factory();
      final available =
          await auth.isDeviceSupported() || await auth.canCheckBiometrics;
      if (!available) return false;
      // Allow device PIN/passcode fallback: Windows Hello doesn't support
      // biometricOnly, and users without enrolled biometrics still unlock.
      return await auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}
