import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/providers/cosmos_session_provider.dart';
import 'package:fireraccoon/store/cosmos_login.dart';
import 'package:fireraccoon/store/cosmos_session.dart';
import 'package:fireraccoon/store/cosmos_session_store.dart';
import 'package:fireraccoon/widgets/cosmos_sso_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/localized_test_app.dart';
import '../helpers/static_auth_notifier.dart';

/// A web view whose window will not open, which used to leave the button
/// resetting itself and nothing else happening.
class _BrokenLogin implements CosmosLogin {
  @override
  bool get isSupported => true;

  @override
  Future<CosmosSession?> signIn(Uri routeUrl) async =>
      throw const CosmosLoginUnavailable('no window server');
}

/// Stands in for the platform web view, and records what it was asked to open.
class _FakeLogin implements CosmosLogin {
  _FakeLogin({this.session, this.isSupported = true});

  final CosmosSession? session;
  Uri? openedUrl;

  @override
  final bool isSupported;

  @override
  Future<CosmosSession?> signIn(Uri routeUrl) async {
    openedUrl = routeUrl;
    return session;
  }
}

/// A store that keeps the session in memory, so the section can be driven
/// without a keychain.
class _MemoryStore extends CosmosSessionStore {
  _MemoryStore() : super(storage: null);

  CosmosSession? saved;
  var cleared = 0;

  @override
  Future<CosmosSession?> load() async => saved;

  @override
  Future<void> save(CosmosSession session) async => saved = session;

  @override
  Future<void> clear() async {
    cleared++;
    saved = null;
  }
}

void main() {
  final session = CosmosSession(
    host: 'firefly.example',
    cookie: 'jwt-value',
    obtainedAt: DateTime.utc(2026, 9, 8),
  );

  Future<_MemoryStore> pump(
    WidgetTester tester, {
    required CosmosLogin login,
    String serverUrl = 'https://firefly.example',
  }) async {
    final store = _MemoryStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cosmosSessionStoreProvider.overrideWithValue(store),
          authProvider.overrideWith(
            () => StaticAuthNotifier(
              AuthSettings(
                serverUrl: serverUrl,
                apiToken: 'tok',
                isHydrated: true,
              ),
            ),
          ),
        ],
        child: buildLocalizedTestApp(child: CosmosSsoSection(login: login)),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('offers a sign-in when there is no session', (tester) async {
    await pump(tester, login: _FakeLogin(session: session));

    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('signing in stores the session for the route host', (
    tester,
  ) async {
    final login = _FakeLogin(session: session);
    final store = await pump(tester, login: login);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    // The route is what gets opened, not the Cosmos login: Cosmos redirects
    // there itself and only its own callback mints the cookie.
    expect(login.openedUrl, Uri.parse('https://firefly.example'));
    expect(store.saved!.cookie, 'jwt-value');
    expect(find.text('Signed in to firefly.example'), findsOneWidget);
  });

  testWidgets('a window closed early is said so, not stored', (tester) async {
    final store = await pump(tester, login: _FakeLogin(session: null));

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(store.saved, isNull);
    expect(find.text('Sign-in was closed before it finished'), findsOneWidget);
  });

  testWidgets('signing out drops the session', (tester) async {
    final login = _FakeLogin(session: session);
    final store = await pump(tester, login: login);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(store.cleared, 1);
    expect(find.text('Not signed in'), findsOneWidget);
  });

  testWidgets('a platform with no web view says so instead of offering one', (
    tester,
  ) async {
    await pump(tester, login: _FakeLogin(isSupported: false));

    expect(find.text('Sign in'), findsNothing);
    expect(
      find.text('Signing in to Cosmos is not available on this platform'),
      findsOneWidget,
    );
  });

  testWidgets('a window that will not open is said out loud', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cosmosSessionStoreProvider.overrideWithValue(_MemoryStore()),
        ],
        child: buildLocalizedTestApp(
          child: CosmosSignInButton(
            serverUrl: 'https://firefly.example',
            login: _BrokenLogin(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in to Cosmos'));
    await tester.pumpAndSettle();

    // Silence here reads as the app ignoring the click, which is what sent
    // someone looking for a sign-in page that was never going to appear.
    expect(find.textContaining('would not open'), findsOneWidget);
  });

  testWidgets('nothing is shown before a server is configured', (tester) async {
    // The session is minted for a route's host, so there is nothing to sign
    // in to until one is known.
    await pump(tester, login: _FakeLogin(), serverUrl: '');

    expect(find.text('Cosmos SSO'), findsNothing);
  });
}
