import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:fireracoon/providers/agent_keys_provider.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/providers/mcp_provider.dart';
import 'package:fireracoon/services/mcp_service.dart';
import 'package:fireracoon/providers/people_providers.dart';
import '../helpers/static_auth_notifier.dart';
import '../helpers/static_people_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureStorage;

  setUp(() {
    secureStorage = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureStorage,
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('mcpServiceProvider creates and disposes McpService', () {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => StaticAuthNotifier(AuthSettings())),
      ],
    );
    addTearDown(container.dispose);

    final service = container.read(mcpServiceProvider);
    expect(service, isA<McpService>());
    expect(service.running, isFalse);
  });

  test('mcpServiceProvider starts when auth becomes valid', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => StaticAuthNotifier(AuthSettings())),
      ],
    );
    addTearDown(container.dispose);

    container.read(mcpServiceProvider);
    await container
        .read(authProvider.notifier)
        .saveSettings('https://firefly.test', 'token', true);
    await Future<void>.delayed(Duration.zero);

    final service = container.read(mcpServiceProvider);
    expect(service.error, isNull);
  });

  test('mcpServiceProvider routes reported usage into the key store', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => StaticAuthNotifier(
            AuthSettings(
              serverUrl: 'https://firefly.test',
              apiToken: 'token',
              isHydrated: true,
            ),
          ),
        ),
        peopleProvider.overrideWith(
          () => StaticPeopleNotifier([testPerson('p1', 'Ada')]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(agentKeysProvider.future);
    await container.read(agentKeysProvider.notifier).issue('Claude Desktop');
    final id = (await container.read(agentKeysProvider.future)).single.id;

    final service = container.read(mcpServiceProvider);
    expect(service.onKeyUsed, isNotNull);
    final at = DateTime.utc(2026, 5, 1, 12);
    service.onKeyUsed!(id, at);
    await Future<void>.delayed(Duration.zero);

    expect(
      (await container.read(agentKeysProvider.future)).single.lastUsedAt,
      at,
    );
  });

  test('mcpServiceProvider stops when auth becomes invalid', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => StaticAuthNotifier(
            AuthSettings(
              serverUrl: 'https://firefly.test',
              apiToken: 'token',
              isHydrated: true,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final service = container.read(mcpServiceProvider);
    await container.read(authProvider.notifier).clearSettings();
    await Future<void>.delayed(Duration.zero);

    expect(service.running, isFalse);
  });
}
