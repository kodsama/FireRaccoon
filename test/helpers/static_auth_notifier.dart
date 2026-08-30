import 'package:fireraccoon/providers/auth_provider.dart';

/// Auth notifier that skips async storage/env loading for deterministic tests.
class StaticAuthNotifier extends AuthNotifier {
  StaticAuthNotifier(
    this.settings, {
    super.storage,
    super.httpClient,
    this.hydrated = true,
  });

  final AuthSettings settings;

  /// Hydrated by default: most tests want credentials already resolved. Pass
  /// false to hold a container in the state a launch is in while the keychain
  /// has yet to answer.
  final bool hydrated;

  @override
  AuthSettings build() => AuthSettings(
    serverUrl: settings.serverUrl,
    apiToken: settings.apiToken,
    authMode: settings.authMode,
    allowInsecure: settings.allowInsecure,
    isHydrated: hydrated,
    storageUnavailable: settings.storageUnavailable,
  );

  @override
  Future<void> clearSettings() async {
    state = AuthSettings(isHydrated: true);
  }
}
