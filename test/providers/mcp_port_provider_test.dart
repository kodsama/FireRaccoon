import 'package:fireraccoon/providers/mcp_port_provider.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerWith(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('defaults to the port agents are configured with', () async {
    final container = await containerWith({});

    expect(container.read(mcpBasePortProvider), kDefaultMcpBasePort);
  });

  test('a chosen port is kept', () async {
    final container = await containerWith({});

    await container.read(mcpBasePortProvider.notifier).setBasePort(9100);

    expect(container.read(mcpBasePortProvider), 9100);
  });

  test('a stored port comes back', () async {
    final container = await containerWith({'mcpBasePort': 9100});

    expect(container.read(mcpBasePortProvider), 9100);
  });

  test('a port nothing could bind is brought into range', () async {
    // Below 1024 needs privileges nobody should be granting a finance client,
    // and the walk of ten has to fit under the ceiling.
    final container = await containerWith({});
    final notifier = container.read(mcpBasePortProvider.notifier);

    await notifier.setBasePort(80);
    expect(container.read(mcpBasePortProvider), kMinMcpBasePort);

    await notifier.setBasePort(65535);
    expect(container.read(mcpBasePortProvider), kMaxMcpBasePort);
    expect(kMaxMcpBasePort + kMcpPortRange, lessThanOrEqualTo(65535));
  });

  test(
    'a stored port out of range is brought in rather than trusted',
    () async {
      final container = await containerWith({'mcpBasePort': 70000});

      expect(container.read(mcpBasePortProvider), kMaxMcpBasePort);
    },
  );

  test('resetting forgets the preference, not just the value', () async {
    // A stored copy of today's default would pin the port if the default ever
    // moved, which is the one thing a reset is supposed to prevent.
    SharedPreferences.setMockInitialValues({'mcpBasePort': 9100});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container.read(mcpBasePortProvider.notifier).reset();

    expect(container.read(mcpBasePortProvider), kDefaultMcpBasePort);
    expect(prefs.getInt('mcpBasePort'), isNull);
  });
}
