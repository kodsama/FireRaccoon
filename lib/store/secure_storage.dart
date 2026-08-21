import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The secure storage every FireRacoon secret goes through.
///
/// macOS asks for the legacy login keychain instead of the data protection one.
/// `kSecUseDataProtectionKeychain` requires the application-identifier
/// entitlement, which only signs with a development certificate; debug builds
/// are ad-hoc signed and CI produces an unsigned release, so neither has it.
/// Requesting it fails every write with errSecMissingEntitlement (-34018). The
/// login keychain is reachable once the app is unsandboxed, which is what the
/// debug entitlements already arrange.
const FlutterSecureStorage appSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);
