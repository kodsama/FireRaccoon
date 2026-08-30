import 'package:fireraccoon/services/biometric_auth.dart';

class FakeBiometricAuth implements BiometricAuth {
  FakeBiometricAuth({this.available = true, this.authenticateResult = true});

  bool available;
  bool authenticateResult;
  int authenticateCalls = 0;
  String? lastReason;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateCalls++;
    lastReason = localizedReason;
    return authenticateResult;
  }
}

class FakeLocalAuthenticationFacade implements LocalAuthenticationFacade {
  FakeLocalAuthenticationFacade({
    this.canCheck = true,
    this.deviceSupported = true,
    this.authenticateResult = true,
  });

  bool canCheck;
  bool deviceSupported;
  bool authenticateResult;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
    bool persistAcrossBackgrounding = false,
  }) async => authenticateResult;
}
