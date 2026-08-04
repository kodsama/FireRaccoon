// coverage:ignore-file — platform channel / conditional import shim
/// Minimal surface of platform local-auth used by [LocalBiometricAuth].
abstract class LocalAuthenticationFacade {
  Future<bool> get canCheckBiometrics;
  Future<bool> isDeviceSupported();
  Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
    bool persistAcrossBackgrounding = false,
  });
}

typedef LocalAuthenticationFactory = LocalAuthenticationFacade Function();

LocalAuthenticationFacade defaultLocalAuthenticationFactory() =>
    const UnavailableLocalAuthenticationFacade();

class UnavailableLocalAuthenticationFacade
    implements LocalAuthenticationFacade {
  const UnavailableLocalAuthenticationFacade();

  @override
  Future<bool> get canCheckBiometrics async => false;

  @override
  Future<bool> isDeviceSupported() async => false;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
    bool persistAcrossBackgrounding = false,
  }) async => false;
}
