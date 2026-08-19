import 'dart:convert';

import 'package:fireracoon/models/people_models.dart';
import 'package:fireracoon/providers/agent_keys_provider.dart';
import 'package:fireracoon/providers/mcp_provider.dart';
import 'package:fireracoon/providers/people_providers.dart';
import 'package:fireracoon/services/mcp_service.dart';
import 'package:fireracoon/theme/app_theme.dart';
import 'package:fireracoon/utils/app_feedback.dart';
import 'package:fireracoon/widgets/mcp_settings_section.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/dialog_test_helpers.dart';
import '../helpers/localized_test_app.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/static_people_notifier.dart';

/// Records what the section put on the clipboard.
final _clipboard = <String>[];

/// Runs [body] with the desktop platform in force.
///
/// flutter_test checks that foundation debug variables are unset before tearDown
/// runs, so the override cannot outlive the test body.
Future<void> onDesktop(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _pumpSection(
  WidgetTester tester, {
  List<Person>? people,
  McpService? service,
  AgentKeysNotifier Function()? keys,
}) async {
  configureLargeScreen(tester);
  addTearDown(tester.view.resetPhysicalSize);

  final owned = service ?? McpService();
  addTearDown(owned.dispose);
  // Settle the service into a known state. With no keys it reports itself idle
  // without spawning an isolate, which is what the status line should say; left
  // untouched it would read "Starting..." forever.
  await owned.sync(
    fireflyUrl: 'http://localhost:8080',
    fireflyToken: 'token',
    agentKeys: const [],
    people: const [],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        peopleProvider.overrideWith(
          () => StaticPeopleNotifier(people ?? [testPerson('p1', 'Ada')]),
        ),
        mcpServiceProvider.overrideWithValue(owned),
        if (keys != null) agentKeysProvider.overrideWith(keys),
      ],
      child: buildLocalizedTestApp(
        child: const Scaffold(
          body: SingleChildScrollView(child: McpSettingsSection()),
        ),
      ),
    ),
  );
  await settleIgnoringOverflow(tester);
}

/// Creates a key through the UI and returns the secret it revealed.
Future<String> _createKey(WidgetTester tester, String label) async {
  await tester.tap(find.text('Create key'));
  await settleIgnoringOverflow(tester);
  await tester.enterText(find.byType(TextField), label);
  await tester.tap(find.widgetWithText(FilledButton, 'Create'));
  await settleIgnoringOverflow(tester);

  final secret = tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((w) => w.data ?? '')
      .firstWhere((text) => text.startsWith('frcn_'));

  await tester.tap(find.widgetWithText(FilledButton, 'Done'));
  await settleIgnoringOverflow(tester);
  return secret;
}

Future<void> _revoke(WidgetTester tester) async {
  await tester.tap(find.text('Revoke').first);
  await settleIgnoringOverflow(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
  await settleIgnoringOverflow(tester);
}

/// Opens the key picker behind the section's copy action.
Future<void> _openConnectionPicker(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Copy connection details'));
  await settleIgnoringOverflow(tester);
}

/// Chooses the picker option titled [label].
///
/// Scoped to the dialog: every key label also sits in the list behind it.
Future<void> _pickConnectionKey(WidgetTester tester, String label) async {
  await tester.tap(
    find.ancestor(
      of: find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text(label),
      ),
      matching: find.byType(SimpleDialogOption),
    ),
  );
  await settleIgnoringOverflow(tester);
}

/// Clears a failure message, which by design stays until it is dismissed.
Future<void> _clearToast(WidgetTester tester) async {
  dismissToast();
  await tester.pump();
}

/// A server that reports itself bound without opening a socket.
///
/// The real service only learns a port from an isolate that binds one, and a
/// widget test has no business spawning that.
class _FixedMcpService extends McpService {
  _FixedMcpService({this.boundPort = 8787, this.failure});

  final int boundPort;

  /// Set to stand in for a server that could not start.
  final String? failure;

  @override
  int? get port => failure == null ? boundPort : null;

  @override
  bool get running => failure == null;

  @override
  bool get needsAgentKey => false;

  @override
  String? get error => failure;

  @override
  Future<void> sync({
    required String fireflyUrl,
    required String fireflyToken,
    required List<AgentKey> agentKeys,
    required List<AgentKeyPerson> people,
    int basePort = 8787,
  }) async {}
}

AgentKeyView _view(
  String id,
  String label, {
  bool hasSecret = true,
  DateTime? lastUsedAt,
  DateTime? revokedAt,
}) => AgentKeyView(
  id: id,
  personId: 'p1',
  label: label,
  displayPrefix: 'frcn_$id',
  createdAt: DateTime.utc(2026, 1, 2),
  lastUsedAt: lastUsedAt,
  revokedAt: revokedAt,
  hasSecret: hasSecret,
);

/// Agent keys with scripted outcomes.
///
/// The real notifier reads and writes the platform keychain, which cannot be
/// made to fail on demand, and each failure here is a message the person has to
/// see rather than a silent no-op.
class _ScriptedAgentKeys extends AgentKeysNotifier {
  _ScriptedAgentKeys({
    this.views = const <AgentKeyView>[],
    this.secrets = const <String, String>{},
    this.failure,
  });

  final List<AgentKeyView> views;

  /// Secret per key id. A key absent from here reads back as null, which is what
  /// a key issued before secrets were retained looks like.
  final Map<String, String> secrets;

  /// Thrown by whichever action a test triggers. One switch is enough because
  /// each test drives a single action.
  final Object? failure;

  @override
  Future<List<AgentKeyView>> build() async => views;

  @override
  Future<String> issue(String label) async {
    if (failure case final error?) throw error;
    return 'frcn_issued_secret';
  }

  @override
  Future<String?> revealSecret(String keyId) async {
    if (failure case final error?) throw error;
    return secrets[keyId];
  }

  @override
  Future<void> revoke(String keyId) async {
    if (failure case final error?) throw error;
  }

  @override
  Future<void> forget(String keyId) async {
    if (failure case final error?) throw error;
  }
}

/// Unbound until [bind] is called, standing in for the first key ever issued.
///
/// On a fresh install nothing has started the server yet, so issuing a key is
/// what binds the port, and it binds after the dialog showing that key is
/// already on screen.
class _LateBindingMcpService extends McpService {
  int? _port;

  @override
  int? get port => _port;

  @override
  bool get running => _port != null;

  @override
  bool get needsAgentKey => _port == null;

  @override
  String? get error => null;

  void bind(int port) {
    _port = port;
    notifyListeners();
  }

  @override
  Future<void> sync({
    required String fireflyUrl,
    required String fireflyToken,
    required List<AgentKey> agentKeys,
    required List<AgentKeyPerson> people,
    String? agentKeysError,
    int basePort = 8787,
  }) async {}
}

/// Fails to load at all, standing in for a keychain that will not open.
///
/// An [Error] rather than an exception on purpose: Riverpod retries a failed
/// build with backoff unless the failure is an Error, and while it retries the
/// state is still loading, so anything else would never reach the error branch.
class _FailingAgentKeys extends AgentKeysNotifier {
  @override
  Future<List<AgentKeyView>> build() async {
    throw StateError('keychain locked');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _clipboard.clear();
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            _clipboard.add((call.arguments as Map)['text'] as String? ?? '');
          }
          if (call.method == 'Clipboard.getData') {
            return <String, Object?>{'text': ''};
          }
          return null;
        });
  });

  testWidgets('an idle server shows why and offers no address to copy', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(tester);

      expect(find.text('MCP server'), findsOneWidget);
      expect(
        find.text('No agent keys yet, so the server is idle'),
        findsOneWidget,
      );
      expect(find.text('Not running'), findsOneWidget);
      expect(find.text('initialize.params.apiKey'), findsOneWidget);
      expect(find.text('No agent keys yet'), findsOneWidget);

      final copy = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Copy connection details'),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        copy.onPressed,
        isNull,
        reason: 'nothing to connect to while the server is down',
      );
    });
  });

  testWidgets('creating a key reveals it once and then lists it', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(tester);

      final secret = await _createKey(tester, 'Claude Desktop');

      expect(secret, startsWith('frcn_'));
      expect(find.text('Claude Desktop'), findsOneWidget);
      expect(find.text('No agent keys yet'), findsNothing);
      // The prefix identifies the row, and it has not been used yet.
      expect(find.textContaining('Never used'), findsOneWidget);
      expect(find.textContaining(secret.substring(5, 11)), findsOneWidget);
    });
  });

  testWidgets('the first key gets its handshake once the port binds', (
    tester,
  ) async {
    await onDesktop(() async {
      final service = _LateBindingMcpService();
      await _pumpSection(tester, service: service);

      await tester.tap(find.text('Create key'));
      await settleIgnoringOverflow(tester);
      await tester.enterText(find.byType(TextField), 'Claude Desktop');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settleIgnoringOverflow(tester);

      // Nothing to connect to yet: issuing this key is what starts the server.
      // Scoped to the dialog, since the section behind it carries the same
      // label on a button that is disabled while the port is unbound.
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Copy connection details'),
        ),
        findsNothing,
      );

      service.bind(8787);
      await settleIgnoringOverflow(tester);

      // Reading the port once left the first key ever issued with only a bare
      // secret, which is the config nobody finishes assembling by hand.
      final snippet = tester
          .widgetList<SelectableText>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(SelectableText),
            ),
          )
          .map((w) => w.data ?? '')
          .firstWhere((text) => text.contains('127.0.0.1'));
      expect(snippet, contains('8787'));
      expect(snippet, contains('frcn_'));
      expect(snippet, isNot(contains('PASTE_YOUR_AGENT_KEY')));

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Copy connection details'),
        ),
      );
      await settleIgnoringOverflow(tester);
      expect(_clipboard.last, contains('8787'));

      // The copy toast dismisses itself; leave it pending and the binding
      // fails the test on a live timer.
      await tester.pump(const Duration(seconds: 4));
    });
  });

  testWidgets('a blank label cannot create a key', (tester) async {
    await onDesktop(() async {
      await _pumpSection(tester);

      await tester.tap(find.text('Create key'));
      await settleIgnoringOverflow(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settleIgnoringOverflow(tester);

      // Still on the prompt, nothing issued.
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settleIgnoringOverflow(tester);
      expect(find.text('No agent keys yet'), findsOneWidget);
    });
  });

  testWidgets('a key can be reopened after creation', (tester) async {
    await onDesktop(() async {
      await _pumpSection(tester);
      final secret = await _createKey(tester, 'Claude Desktop');

      await tester.tap(find.byIcon(Icons.visibility));
      await settleIgnoringOverflow(tester);

      expect(find.text(secret), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Copy'), findsWidgets);
    });
  });

  testWidgets('copying from the reveal puts the secret on the clipboard', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(tester);
      final secret = await _createKey(tester, 'Claude Desktop');
      await tester.tap(find.byIcon(Icons.visibility));
      await settleIgnoringOverflow(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Copy').first);
      await settleIgnoringOverflow(tester);

      expect(_clipboard, contains(secret));
      expect(find.text('Agent key copied'), findsOneWidget);

      // The confirmation schedules its own dismissal; let it run or the test
      // ends with a pending timer.
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Agent key copied'), findsNothing);
    });
  });

  testWidgets('revoking strikes the row and swaps its actions', (tester) async {
    await onDesktop(() async {
      await _pumpSection(tester);
      await _createKey(tester, 'temporary');

      await _revoke(tester);

      expect(find.text('Revoke'), findsNothing);
      expect(find.byIcon(Icons.visibility), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.key_off), findsOneWidget);
      expect(find.textContaining('Revoked'), findsOneWidget);
    });
  });

  testWidgets('forgetting a revoked key clears the row', (tester) async {
    await onDesktop(() async {
      await _pumpSection(tester);
      await _createKey(tester, 'temporary');
      await _revoke(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await settleIgnoringOverflow(tester);

      expect(find.text('temporary'), findsNothing);
      expect(find.text('No agent keys yet'), findsOneWidget);
    });
  });

  testWidgets('revoked keys are listed below active ones', (tester) async {
    await onDesktop(() async {
      await _pumpSection(tester);
      await _createKey(tester, 'first');
      await _createKey(tester, 'second');
      await _createKey(tester, 'third');

      // Revoke the middle key: it must move to the bottom, not stay put.
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('second'),
            matching: find.byType(ListTile),
          ),
          matching: find.text('Revoke'),
        ),
      );
      await settleIgnoringOverflow(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
      await settleIgnoringOverflow(tester);

      double y(String label) => tester.getTopLeft(find.text(label)).dy;
      expect(y('first'), lessThan(y('third')));
      expect(y('third'), lessThan(y('second')));
    });
  });

  testWidgets('a key reports the person and role it acts as', (tester) async {
    await onDesktop(() async {
      await _pumpSection(
        tester,
        people: [testPerson('p1', 'Grace', role: PersonRole.viewer)],
      );

      await _createKey(tester, 'read only agent');

      expect(find.textContaining('Acts as Grace (viewer)'), findsOneWidget);
    });
  });

  testWidgets('with no People configured a key acts as the device', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(tester, people: const []);

      await _createKey(tester, 'solo agent');

      expect(
        find.textContaining('Acts as This device (admin)'),
        findsOneWidget,
      );
    });
  });

  test('mcpConnectionSnippet fills the key in so nothing needs editing', () {
    final snippet =
        jsonDecode(mcpConnectionSnippet(port: 9123, agentKey: 'frcn_alpha'))
            as Map<String, Object?>;

    expect(snippet['transport'], 'tcp');
    expect(snippet['host'], '127.0.0.1');
    expect(snippet['port'], 9123);
    final initialize = snippet['initialize'] as Map<String, Object?>;
    expect(initialize['method'], 'initialize');
    final params = initialize['params'] as Map<String, Object?>;
    expect(params['protocolVersion'], '2025-06-18');
    expect(params['apiKey'], 'frcn_alpha');
  });

  test('mcpConnectionSnippet marks where the key goes when there is none', () {
    final snippet = mcpConnectionSnippet(port: 9123);

    // A blank or absent apiKey would look like a working config and fail at the
    // handshake, so the gap has to be obvious to whoever pastes it.
    expect(snippet, contains('"apiKey": "PASTE_YOUR_AGENT_KEY"'));
    expect(snippet, isNot(contains('frcn_')));
  });

  testWidgets('a running server shows its address and offers it to copy', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(tester, service: _FixedMcpService(boundPort: 9123));

      expect(find.text('127.0.0.1:9123'), findsOneWidget);
      expect(find.text('Not running'), findsNothing);
      expect(find.text('Running on port 9123'), findsOneWidget);
      expect(find.text(':9123'), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.hub));
      expect(icon.color, tester.element(find.byIcon(Icons.hub)).colors.success);

      final copy = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Copy connection details'),
      );
      expect(copy.onPressed, isNotNull);
    });
  });

  testWidgets('a server that failed to start says why and looks wrong', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(
        tester,
        service: _FixedMcpService(failure: 'no free port in 8787..8796'),
      );

      expect(find.text('Failed: no free port in 8787..8796'), findsOneWidget);
      expect(find.text('Not running'), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.hub));
      expect(icon.color, tester.element(find.byIcon(Icons.hub)).colors.danger);
    });
  });

  testWidgets('the connection snippet can be taken without a key', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(tester, service: _FixedMcpService(boundPort: 9123));

      await _openConnectionPicker(tester);
      expect(find.text('Which key should it use?'), findsOneWidget);
      expect(find.text('PASTE_YOUR_AGENT_KEY'), findsOneWidget);

      await _pickConnectionKey(tester, 'Without a key');
      expect(find.textContaining('"port": 9123'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Copy'));
      await settleIgnoringOverflow(tester);

      expect(_clipboard.single, contains('"apiKey": "PASTE_YOUR_AGENT_KEY"'));
      expect(find.text('Connection details copied'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await settleIgnoringOverflow(tester);
      expect(find.text('Connection details copied'), findsNothing);
    });
  });

  testWidgets('the picker offers only keys whose secret can still be read', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(
        tester,
        service: _FixedMcpService(boundPort: 9123),
        keys: () => _ScriptedAgentKeys(
          views: [
            _view('k1', 'Alpha'),
            _view('k2', 'Legacy', hasSecret: false),
            _view('k3', 'Retired', revokedAt: DateTime.utc(2026, 2, 1)),
          ],
          secrets: const {'k1': 'frcn_alpha_secret'},
        ),
      );

      await _openConnectionPicker(tester);

      Finder inPicker(String label) => find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text(label),
      );
      expect(inPicker('Alpha'), findsOneWidget);
      // Offering either of these would produce a snippet that cannot be filled
      // in, or one for a key that no longer opens anything.
      expect(inPicker('Legacy'), findsNothing);
      expect(inPicker('Retired'), findsNothing);

      await _pickConnectionKey(tester, 'Alpha');

      expect(
        find.textContaining('"apiKey": "frcn_alpha_secret"'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a chosen key that cannot be read back stops the snippet', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(
        tester,
        service: _FixedMcpService(boundPort: 9123),
        keys: () => _ScriptedAgentKeys(views: [_view('k1', 'Alpha')]),
      );

      await _openConnectionPicker(tester);
      await _pickConnectionKey(tester, 'Alpha');

      expect(
        find.text(
          'This key was created before keys could be read back. '
          'Revoke it and create a new one.',
        ),
        findsOneWidget,
      );
      // A snippet with a placeholder here would look like the key was used.
      expect(find.textContaining('"apiKey"'), findsNothing);

      await _clearToast(tester);
    });
  });

  testWidgets('a keychain failure while reading the chosen key surfaces', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(
        tester,
        service: _FixedMcpService(boundPort: 9123),
        keys: () => _ScriptedAgentKeys(
          views: [_view('k1', 'Alpha')],
          failure: Exception('keychain locked'),
        ),
      );

      await _openConnectionPicker(tester);
      await _pickConnectionKey(tester, 'Alpha');

      expect(find.textContaining('keychain locked'), findsOneWidget);
      expect(find.textContaining('"apiKey"'), findsNothing);

      await _clearToast(tester);
    });
  });

  testWidgets('a key issued while the server runs comes with a handshake', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(tester, service: _FixedMcpService(boundPort: 9123));

      await tester.tap(find.text('Create key'));
      await settleIgnoringOverflow(tester);
      await tester.enterText(find.byType(TextField), 'Claude Desktop');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settleIgnoringOverflow(tester);

      final secret = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((w) => w.data ?? '')
          .firstWhere((text) => text.startsWith('frcn_'));
      expect(find.textContaining('"transport": "tcp"'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Copy connection details'),
        ),
      );
      await settleIgnoringOverflow(tester);

      // The whole point of the second copy target: the secret is already in
      // place, so nothing is left to paste by hand.
      expect(_clipboard.single, contains('"apiKey": "$secret"'));
      expect(_clipboard.single, contains('"port": 9123'));
      expect(find.text('Connection details copied'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await settleIgnoringOverflow(tester);
    });
  });

  testWidgets('a key that failed to issue says so instead of opening blank', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(
        tester,
        keys: () => _ScriptedAgentKeys(failure: Exception('keychain locked')),
      );

      await tester.tap(find.text('Create key'));
      await settleIgnoringOverflow(tester);
      await tester.enterText(find.byType(TextField), 'Claude Desktop');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settleIgnoringOverflow(tester);

      expect(find.textContaining('keychain locked'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('No agent keys yet'), findsOneWidget);

      await _clearToast(tester);
    });
  });

  testWidgets('a reveal that failed says so instead of opening blank', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(
        tester,
        keys: () => _ScriptedAgentKeys(
          views: [_view('k1', 'Alpha')],
          failure: Exception('keychain locked'),
        ),
      );

      await tester.tap(find.byIcon(Icons.visibility));
      await settleIgnoringOverflow(tester);

      expect(find.textContaining('keychain locked'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await _clearToast(tester);
    });
  });

  testWidgets('a key with no readable secret says to reissue it', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(
        tester,
        keys: () => _ScriptedAgentKeys(views: [_view('k1', 'Alpha')]),
      );

      await tester.tap(find.byIcon(Icons.visibility));
      await settleIgnoringOverflow(tester);

      expect(
        find.text(
          'This key was created before keys could be read back. '
          'Revoke it and create a new one.',
        ),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);

      await _clearToast(tester);
    });
  });

  testWidgets('a revoke that failed leaves the key working and says so', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(
        tester,
        keys: () => _ScriptedAgentKeys(
          views: [_view('k1', 'Alpha')],
          failure: Exception('keychain locked'),
        ),
      );

      await _revoke(tester);

      expect(find.textContaining('keychain locked'), findsOneWidget);
      // Reporting a revocation that did not happen is the dangerous outcome.
      expect(find.text('Revoke'), findsOneWidget);
      expect(find.byIcon(Icons.vpn_key), findsOneWidget);

      await _clearToast(tester);
    });
  });

  testWidgets('a forget that failed keeps the row and says so', (tester) async {
    await onDesktop(() async {
      await _pumpSection(
        tester,
        keys: () => _ScriptedAgentKeys(
          views: [_view('k1', 'Retired', revokedAt: DateTime.utc(2026, 2, 1))],
          failure: Exception('keychain locked'),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await settleIgnoringOverflow(tester);

      expect(find.textContaining('keychain locked'), findsOneWidget);
      expect(find.text('Retired'), findsOneWidget);

      await _clearToast(tester);
    });
  });

  testWidgets('cancelling the revoke prompt leaves the key working', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(tester);
      await _createKey(tester, 'Claude Desktop');

      await tester.tap(find.text('Revoke'));
      await settleIgnoringOverflow(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settleIgnoringOverflow(tester);

      expect(find.text('Revoke agent key?'), findsNothing);
      expect(find.byIcon(Icons.vpn_key), findsOneWidget);
      expect(find.byIcon(Icons.key_off), findsNothing);
      expect(find.textContaining('Never used'), findsOneWidget);
    });
  });

  testWidgets('a key that has been used reports when', (tester) async {
    await onDesktop(() async {
      await _pumpSection(
        tester,
        keys: () => _ScriptedAgentKeys(
          views: [_view('k1', 'Alpha', lastUsedAt: DateTime.utc(2026, 3, 4))],
        ),
      );

      // Whether a client ever connected is the first thing anyone debugging one
      // looks for, so it must replace the "never used" line.
      expect(find.textContaining('Last used Mar 4, 2026'), findsOneWidget);
      expect(find.textContaining('Never used'), findsNothing);
    });
  });

  testWidgets('the label can be submitted from the keyboard', (tester) async {
    await onDesktop(() async {
      await _pumpSection(tester);

      await tester.tap(find.text('Create key'));
      await settleIgnoringOverflow(tester);
      await tester.enterText(find.byType(TextField), 'Keyboard agent');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleIgnoringOverflow(tester);

      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await settleIgnoringOverflow(tester);

      expect(find.text('Keyboard agent'), findsOneWidget);
    });
  });

  testWidgets('a keychain that will not open is reported, not shown empty', (
    tester,
  ) async {
    await onDesktop(() async {
      await _pumpSection(tester, keys: _FailingAgentKeys.new);

      expect(find.textContaining('keychain locked'), findsOneWidget);
      // Neither of these may appear: an unreadable list is not an empty one, and
      // creating a key on top of it could collide with what is already stored.
      expect(find.text('No agent keys yet'), findsNothing);
      expect(find.text('Create key'), findsNothing);
    });
  });
}
