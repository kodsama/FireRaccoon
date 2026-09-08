import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/providers/firefly_connection_provider.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/store/credential_store_locked_exception.dart';
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

/// A connection whose state the test decides.
class _FixedConnection extends FireflyConnectionNotifier {
  _FixedConnection(this.status);

  final FireflyConnectionStatus status;

  @override
  FireflyConnectionStatus build() => status;
}
