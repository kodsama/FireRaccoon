import 'package:fireraccoon/providers/cosmos_gate_provider.dart';
import 'package:fireraccoon/providers/cosmos_session_provider.dart';
import 'package:fireraccoon/store/cosmos_login.dart';
import 'package:fireraccoon/store/cosmos_session.dart';
import 'package:fireraccoon/store/cosmos_session_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps the session in memory so the gate can be driven without a keychain.
class _MemoryStore extends CosmosSessionStore {
  _MemoryStore({this.saved}) : super(storage: null);

  CosmosSession? saved;

  @override
  Future<CosmosSession?> load() async => saved;

  @override
  Future<void> save(CosmosSession session) async => saved = session;

  @override
  Future<void> clear() async => saved = null;
}

/// A sign-in that answers whatever the test wants, and counts the asking.
class _FakeLogin implements CosmosLogin {
  _FakeLogin({this.renewal, this.supported = true});

  final CosmosSession? renewal;
  final bool supported;
  var renewals = 0;
  final staleCookies = <String?>[];
  Object? renewalError;

  @override
  bool get isSupported => supported;

  @override
  Future<CosmosSession?> signIn(BuildContext context, Uri routeUrl) async =>
      null;

  @override
  Future<CosmosSession?> renew(Uri routeUrl, {String? staleCookie}) async {
    renewals++;
    staleCookies.add(staleCookie);
    final error = renewalError;
    if (error != null) throw error;
    return renewal;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Lets the store read and the renewal run to their end.
  Future<void> settle() => pumpEventQueue(times: 10);

  /// The address a refused request was bound for, which is what the client
  /// hands the gate.
  final route = Uri.parse('https://cash.example/api/v1/about');

  CosmosSession session({String host = 'cash.example'}) => CosmosSession(
    host: host,
    cookie: 'jwt-value',
    obtainedAt: DateTime.utc(2026, 9, 8),
  );

  ProviderContainer containerWith({
    required _FakeLogin login,
    CosmosSession? stored,
  }) {
    final container = ProviderContainer(
      overrides: [
        cosmosLoginProvider.overrideWithValue(login),
        cosmosSessionStoreProvider.overrideWithValue(
          _MemoryStore(saved: stored),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a refused request is renewed without anybody being asked', () async {
    final renewed = CosmosSession(
      host: 'cash.example',
      cookie: 'fresh-value',
      obtainedAt: DateTime.utc(2026, 9, 9),
    );
    final login = _FakeLogin(renewal: renewed);
    final container = containerWith(login: login, stored: session());

    container.read(cosmosGateProvider.notifier).rejected(route);
    // Renewing straight away, before the store has even answered: the screens
    // that were loading keep loading rather than flashing a message.
    expect(container.read(cosmosGateProvider), CosmosGate.renewing);
    await settle();

    expect(login.renewals, 1);
    expect(container.read(cosmosGateProvider), CosmosGate.open);
    expect(container.read(cosmosSessionProvider), renewed);
  });

  test('the dead cookie is dropped before the renewal runs', () async {
    // Left in place it tells the settings screen someone is signed in to a
    // route that will not let them through.
    final login = _FakeLogin(renewal: null);
    final container = containerWith(login: login, stored: session());
    // Read first, so the session under test is one that had actually landed.
    container.read(cosmosSessionProvider);
    await settle();
    expect(container.read(cosmosSessionProvider), isNotNull);

    container.read(cosmosGateProvider.notifier).rejected(route);
    await settle();

    expect(container.read(cosmosSessionProvider), isNull);
  });

  test('the renewal is told which cookie was refused', () async {
    // The web view keeps its own copy of it, and a route Cosmos declines to
    // open sets no new one, so without this the jar hands the dead cookie
    // straight back and every request refuses it again.
    final login = _FakeLogin(renewal: session());
    final container = containerWith(login: login, stored: session());

    container.read(cosmosGateProvider.notifier).rejected(route);
    await settle();

    expect(login.staleCookies, ['jwt-value']);
  });

  test('a renewal Cosmos will not grant asks a person instead', () async {
    final login = _FakeLogin(renewal: null);
    final container = containerWith(login: login, stored: session());

    container.read(cosmosGateProvider.notifier).rejected(route);
    await settle();

    expect(login.renewals, 1);
    expect(container.read(cosmosGateProvider), CosmosGate.signInRequired);
  });

  test('a renewal that throws asks a person rather than retrying', () async {
    final login = _FakeLogin()..renewalError = StateError('no web view');
    final container = containerWith(login: login, stored: session());

    container.read(cosmosGateProvider.notifier).rejected(route);
    await settle();

    expect(container.read(cosmosGateProvider), CosmosGate.signInRequired);
  });

  test('a renewal that does not hold is not run again', () async {
    // Cosmos hides a shut route behind a plain 404 and sets no cookie for it,
    // so a renewal can hand back a session as dead as the one it replaced.
    // Renewing on every refusal made that a loop, twice a second, forever.
    final login = _FakeLogin(renewal: session());
    final container = containerWith(login: login, stored: session());

    final gate = container.read(cosmosGateProvider.notifier);
    gate.rejected(route);
    await settle();
    expect(login.renewals, 1);
    expect(container.read(cosmosGateProvider), CosmosGate.open);

    gate.rejected(route);
    await settle();

    expect(login.renewals, 1);
    expect(container.read(cosmosGateProvider), CosmosGate.signInRequired);
  });

  test('a request that got through earns another quiet renewal', () async {
    // Otherwise a session that works now and runs out in an hour would put up
    // a sign-in button rather than renewing itself.
    final login = _FakeLogin(renewal: session());
    final container = containerWith(login: login, stored: session());

    final gate = container.read(cosmosGateProvider.notifier);
    gate.rejected(route);
    await settle();
    gate.accepted();

    gate.rejected(route);
    await settle();

    expect(login.renewals, 2);
  });

  test('nothing to renew from means asking straight away', () async {
    // With no session for this host there was never a sign-in on this device,
    // so there is no Cosmos login left behind for a quiet renewal to ride on.
    final login = _FakeLogin(renewal: session());
    final container = containerWith(login: login);

    container.read(cosmosGateProvider.notifier).rejected(route);
    await settle();

    expect(login.renewals, isZero);
    expect(container.read(cosmosGateProvider), CosmosGate.signInRequired);
  });

  test('a session for another host is not one to renew from', () async {
    final login = _FakeLogin(renewal: session());
    final container = containerWith(
      login: login,
      stored: session(host: 'elsewhere.example'),
    );

    container.read(cosmosGateProvider.notifier).rejected(route);
    await settle();

    expect(login.renewals, isZero);
    expect(container.read(cosmosGateProvider), CosmosGate.signInRequired);
  });

  test('a platform with no web view asks rather than pretending', () async {
    final login = _FakeLogin(supported: false);
    final container = containerWith(login: login, stored: session());

    container.read(cosmosGateProvider.notifier).rejected(route);
    await settle();

    expect(login.renewals, isZero);
    expect(container.read(cosmosGateProvider), CosmosGate.signInRequired);
  });

  test('every request meeting the same door renews once', () async {
    // A dozen providers load at once and all of them are refused. One renewal
    // reconnects them all; twelve would open twelve web views.
    final login = _FakeLogin(renewal: session());
    final container = containerWith(login: login, stored: session());

    final gate = container.read(cosmosGateProvider.notifier);
    for (var i = 0; i < 12; i++) {
      gate.rejected(route);
    }
    await settle();

    expect(login.renewals, 1);
  });

  test('once a person is owed a sign-in, nothing keeps asking', () async {
    // The connection poll meets the same door every thirty seconds, and each
    // of those must not start another renewal.
    final login = _FakeLogin(renewal: null);
    final container = containerWith(login: login, stored: session());

    final gate = container.read(cosmosGateProvider.notifier);
    gate.rejected(route);
    await settle();
    gate.rejected(route);
    gate.rejected(route);
    await settle();

    expect(login.renewals, 1);
  });

  test('a hand-driven sign-in opens the gate too', () async {
    final login = _FakeLogin(renewal: null);
    final container = containerWith(login: login, stored: session());
    container.read(cosmosGateProvider.notifier).rejected(route);
    await settle();
    expect(container.read(cosmosGateProvider), CosmosGate.signInRequired);

    await container.read(cosmosSessionProvider.notifier).signedIn(session());
    await settle();

    expect(container.read(cosmosGateProvider), CosmosGate.open);
  });

  test('a corrected server address opens the gate again', () async {
    // Correcting an address that had been refused left every request blocked
    // on a sign-in for the old host, and nothing was ever sent that could
    // prove the new one works.
    final login = _FakeLogin(renewal: null);
    final container = containerWith(login: login, stored: session());

    final gate = container.read(cosmosGateProvider.notifier);
    gate.rejected(route);
    await settle();
    expect(container.read(cosmosGateProvider), CosmosGate.signInRequired);

    gate.addressChanged();

    expect(container.read(cosmosGateProvider), CosmosGate.open);
  });

  test('an address with no host is nothing to renew against', () async {
    final login = _FakeLogin(renewal: session());
    final container = containerWith(login: login, stored: session());

    container.read(cosmosGateProvider.notifier).rejected(Uri.parse('/api/v1'));
    await settle();

    expect(login.renewals, isZero);
    expect(container.read(cosmosGateProvider), CosmosGate.open);
  });
}
