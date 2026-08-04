// coverage:ignore-file — platform channel / conditional import shim
import 'package:local_auth/local_auth.dart';

import 'biometric_auth_facade_stub.dart';

export 'biometric_auth_facade_stub.dart';

LocalAuthenticationFacade defaultLocalAuthenticationFactory() =>
    PluginLocalAuthenticationFacade();

class PluginLocalAuthenticationFacade implements LocalAuthenticationFacade {
  PluginLocalAuthenticationFacade({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> get canCheckBiometrics => _auth.canCheckBiometrics;

  @override
  Future<bool> isDeviceSupported() => _auth.isDeviceSupported();

  @override
  Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
    bool persistAcrossBackgrounding = false,
  }) {
    return _auth.authenticate(
      localizedReason: localizedReason,
      biometricOnly: biometricOnly,
      persistAcrossBackgrounding: persistAcrossBackgrounding,
    );
  }
}
