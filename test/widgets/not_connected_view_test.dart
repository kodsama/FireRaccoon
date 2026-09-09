import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/providers/cosmos_gate_provider.dart';
import 'package:fireraccoon/providers/firefly_connection_provider.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/store/credential_store_locked_exception.dart';
import 'package:fireraccoon/store/no_route_to_firefly_exception.dart';
import 'package:fireraccoon/widgets/not_connected_view.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/localized_test_app.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    String? funMode,
  }) async {
    SharedPreferences.setMockInitialValues({'funMode': funMode ?? 'none'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: buildLocalizedTestApp(child: child),
      ),
    );
    await tester.pump();
  }

  testWidgets('a disconnected server is a state, not an error', (tester) async {
    await pump(
      tester,
      const LoadFailureView(
        error: FireflyNotConnectedException(),
        message: 'Error loading data: something went wrong',
      ),
    );

    expect(find.text('Uh oh, no server yet'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    // The whole point: none of the exception prose reaches the screen.
    expect(find.textContaining('Error loading data'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('a server the app cannot reach is said to be, not blamed on the '
      'call that noticed', (tester) async {
    // A 404 from a request that never had a working connection behind it
    // describes the symptom. The disconnected server is the reason, and it is
    // the one worth saying.
    SharedPreferences.setMockInitialValues({'funMode': 'none'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          fireflyConnectionProvider.overrideWith(
            () => _FixedConnection(FireflyConnectionStatus.unreachable),
          ),
        ],
        child: buildLocalizedTestApp(
          child: LoadFailureView(
            error: Exception('Failed to load transactions: 404'),
            message: 'Error loading data: 404',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(NotConnectedView), findsOneWidget);
    expect(find.textContaining('404'), findsNothing);
  });

  testWidgets('a real failure still shows its message', (tester) async {
    await pump(
      tester,
      LoadFailureView(
        error: Exception('boom'),
        message: 'Error loading data: boom',
      ),
    );

    expect(find.text('Error loading data: boom'), findsOneWidget);
    expect(find.byType(NotConnectedView), findsNothing);
  });

  testWidgets('a locked keychain is a state, not an error', (tester) async {
    await pump(
      tester,
      const LoadFailureView(
        error: CredentialStoreLockedException(),
        message: 'Error loading data: something went wrong',
      ),
    );

    expect(find.text('Waiting on your keychain'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    // The connection is saved and still there, so nothing here should read as
    // a lost setup or a crash.
    expect(find.textContaining('Error loading data'), findsNothing);
    expect(find.byType(NotConnectedView), findsNothing);
  });

  testWidgets('asking again reads the credentials once more', (tester) async {
    SharedPreferences.setMockInitialValues({'funMode': 'none'});
    final prefs = await SharedPreferences.getInstance();
    var reads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(() => _CountingAuthNotifier(() => reads++)),
        ],
        child: buildLocalizedTestApp(child: const CredentialsLockedView()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Try again'));
    await tester.pump();

    // Without this the only thing that ever looks again is the connection
    // poll, so someone who has just unlocked the keychain sits and waits.
    expect(reads, 1);
  });

  testWidgets(
    'a shut Cosmos door offers the sign-in, not the settings screen',
    (tester) async {
      // The server is right and the token is right. Sending someone to Settings
      // to correct an address has them changing the one thing that was fine.
      SharedPreferences.setMockInitialValues({'funMode': 'none'});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            cosmosGateProvider.overrideWith(
              () => _FixedGate(CosmosGate.signInRequired),
            ),
            authProvider.overrideWith(
              () => _FixedAuth(
                AuthSettings(
                  serverUrl: 'https://cash.example',
                  apiToken: 'token',
                  isHydrated: true,
                ),
              ),
            ),
          ],
          child: buildLocalizedTestApp(
            child: LoadFailureView(
              error: Exception('Failed to load transactions: 404'),
              message: 'Error loading data: 404',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CosmosGateView), findsOneWidget);
      expect(find.text('Cosmos wants a sign-in'), findsOneWidget);
      expect(find.byType(NotConnectedView), findsNothing);
      expect(find.textContaining('404'), findsNothing);
    },
  );

  testWidgets('an address that is not the ledger points at the address', (
    tester,
  ) async {
    // No credential fixes a route that is not there and no sign-in creates
    // one, so offering a Cosmos sign-in here sent people round a loop.
    await pump(
      tester,
      LoadFailureView(
        error: NoRouteToFireflyException('cash.example'),
        message: 'Error loading data: 404',
      ),
    );

    expect(find.text('That address is not your ledger'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.byType(CosmosGateView), findsNothing);
    expect(find.textContaining('404'), findsNothing);
  });

  testWidgets('the address wins over a gate waiting on a sign-in', (
    tester,
  ) async {
    // The gate can be left asking for a sign-in from an earlier refusal. An
    // address that answers without routing is the more specific answer.
    SharedPreferences.setMockInitialValues({'funMode': 'none'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cosmosGateProvider.overrideWith(
            () => _FixedGate(CosmosGate.signInRequired),
          ),
        ],
        child: buildLocalizedTestApp(
          child: LoadFailureView(
            error: NoRouteToFireflyException('cash.example'),
            message: 'Error loading data: 404',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(NoRouteView), findsOneWidget);
    expect(find.byType(CosmosGateView), findsNothing);
  });

  testWidgets('Raccoon Mode gets its own copy', (tester) async {
    await pump(tester, const NotConnectedView(), funMode: 'raccoon');

    expect(find.text('Uh oh, the bins are empty'), findsOneWidget);
    expect(find.text('Uh oh, no server yet'), findsNothing);
  });
}

/// Counts the re-reads the locked view asks for, without a keychain.
class _CountingAuthNotifier extends AuthNotifier {
  _CountingAuthNotifier(this.onRead);

  final void Function() onRead;

  @override
  AuthSettings build() =>
      AuthSettings(isHydrated: true, storageUnavailable: true);

  @override
  Future<void> retryCredentialRead() async => onRead();
}

/// A gate whose state the test decides.
class _FixedGate extends CosmosGateNotifier {
  _FixedGate(this.gate);

  final CosmosGate gate;

  @override
  CosmosGate build() => gate;
}

/// Credentials the test decides, without a keychain behind them.
class _FixedAuth extends AuthNotifier {
  _FixedAuth(this.settings);

  final AuthSettings settings;

  @override
  AuthSettings build() => settings;
}

/// A connection whose state the test decides.
class _FixedConnection extends FireflyConnectionNotifier {
  _FixedConnection(this.status);

  final FireflyConnectionStatus status;

  @override
  FireflyConnectionStatus build() => status;
}
