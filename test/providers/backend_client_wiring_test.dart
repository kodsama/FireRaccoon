import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/providers/cosmos_gate_provider.dart';
import 'package:fireraccoon/providers/cosmos_session_provider.dart';
import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/store/cosmos_login.dart';
import 'package:fireraccoon/store/cosmos_session.dart';
import 'package:fireraccoon/store/cosmos_session_store.dart';
import 'package:fireraccoon/store/no_route_to_firefly_exception.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/static_auth_notifier.dart';

/// What the app does with what the proxy in front of Firefly answers.
///
/// Driven through the real service and the real client rather than a stand-in,
/// because this wiring is what has broken: the refusal that never reached the
/// gate, and the credentials notifier reading the gate that read it back.
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

/// A sign-in nothing in these tests is meant to reach.
class _NoLogin implements CosmosLogin {
  var renewals = 0;

  @override
  bool get isSupported => true;

  @override
  Future<CosmosSession?> signIn(BuildContext context, Uri routeUrl) async =>
      null;

  @override
  Future<CosmosSession?> renew(Uri routeUrl, {String? staleCookie}) async {
    renewals++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = CosmosSession(
    host: 'cash.example',
    cookie: 'jwt-value',
    obtainedAt: DateTime.utc(2026, 9, 8),
  );

  ProviderContainer containerWith({
    required MockClient client,
    required _MemoryStore store,
    _NoLogin? login,
  }) {
    final container = ProviderContainer(
      overrides: [
        backendHttpClientProvider.overrideWithValue(client),
        cosmosSessionStoreProvider.overrideWithValue(store),
        cosmosLoginProvider.overrideWithValue(login ?? _NoLogin()),
        authProvider.overrideWith(
          () => StaticAuthNotifier(
            AuthSettings(serverUrl: 'https://cash.example', apiToken: 'token'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Drives one load without awaiting a future that may never complete: a
  /// renewal in flight deliberately leaves providers loading.
  Future<AsyncValue<Object?>> load(ProviderContainer container) async {
    final sub = container.listen(primaryCurrencyProvider, (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue(times: 20);
    return container.read(primaryCurrencyProvider);
  }

  test('a proxy that will not route reaches the screens as such', () async {
    final container = containerWith(
      client: MockClient(
        (_) async => http.Response(
          '404 page not found\n',
          404,
          headers: {'content-type': 'text/plain; charset=utf-8'},
        ),
      ),
      store: _MemoryStore(saved: session),
    );

    final result = await load(container);

    expect(result.error, isA<NoRouteToFireflyException>());
  });

  test('an absent route does not send anybody to a sign-in', () async {
    // No credential creates a route that is not there, so a renewal here is a
    // web view opened for nothing and a button that comes straight back.
    final login = _NoLogin();
    final container = containerWith(
      client: MockClient(
        (_) async => http.Response(
          '404 page not found',
          404,
          headers: {'content-type': 'text/plain'},
        ),
      ),
      store: _MemoryStore(saved: session),
      login: login,
    );

    await load(container);

    expect(login.renewals, isZero);
    expect(container.read(cosmosGateProvider), CosmosGate.open);
  });

  test('a Cosmos sign-in redirect does reach the gate', () async {
    final login = _NoLogin();
    final container = containerWith(
      client: MockClient(
        (_) async => http.Response(
          '',
          302,
          headers: {
            'location':
                'https://cosmos.example/cosmos-ui/openid'
                '?client_id=__route_Firefly-III',
          },
        ),
      ),
      store: _MemoryStore(saved: session),
      login: login,
    );

    await load(container);

    expect(login.renewals, 1);
    expect(container.read(cosmosGateProvider), CosmosGate.signInRequired);
  });

  test('the session Cosmos rolls forward is kept', () async {
    // The difference between a client that stays signed in like a browser and
    // one that expires a fortnight after the sign-in.
    final store = _MemoryStore(saved: session);
    final container = containerWith(
      client: MockClient(
        (_) async => http.Response(
          '{"data":{"attributes":{"code":"EUR","symbol":"\u20ac","name":"Euro",'
          '"decimal_places":2}}}',
          200,
          headers: {
            'content-type': 'application/json',
            'set-cookie': 'jwttoken=rolled-value; Path=/; HttpOnly',
          },
        ),
      ),
      store: store,
    );
    container.read(cosmosSessionProvider);
    await pumpEventQueue(times: 10);

    await load(container);

    expect(container.read(cosmosSessionProvider)!.cookie, 'rolled-value');
    expect(store.saved!.cookie, 'rolled-value');
  });
}
