import 'package:fireracoon/providers/auth_provider.dart';

/// Auth notifier that skips async storage/env loading for deterministic tests.
class StaticAuthNotifier extends AuthNotifier {
  StaticAuthNotifier(this.settings, {super.storage, super.httpClient});

  final AuthSettings settings;

  @override
  AuthSettings build() => AuthSettings(
    serverUrl: settings.serverUrl,
    apiToken: settings.apiToken,
    authMode: settings.authMode,
    allowInsecure: settings.allowInsecure,
    isHydrated: true,
  );

  @override
  Future<void> clearSettings() async {
    state = AuthSettings(isHydrated: true);
  }
}
