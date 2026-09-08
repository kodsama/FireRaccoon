import 'package:fireraccoon/providers/cosmos_session_provider.dart';
import 'package:fireraccoon/store/cosmos_session.dart';
import 'package:fireraccoon/store/cosmos_session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps the session in memory, so the notifier can be driven without a
/// keychain, and records what it was asked to do.
class _MemoryStore extends CosmosSessionStore {
  _MemoryStore({this.saved, this.failLoad = false}) : super(storage: null);

  CosmosSession? saved;
  final bool failLoad;
  var cleared = 0;

  @override
  Future<CosmosSession?> load() async {
    if (failLoad) throw StateError('store would not answer');
    return saved;
  }

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

  ProviderContainer containerWith(_MemoryStore store) {
    final container = ProviderContainer(
      overrides: [cosmosSessionStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a stored session is restored', () async {
    final container = containerWith(_MemoryStore(saved: session));
    container.listen(cosmosSessionProvider, (_, _) {});

    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
      if (container.read(cosmosSessionProvider) != null) break;
    }

    expect(container.read(cosmosSessionProvider)!.host, 'firefly.example');
  });

  test('a store that will not answer leaves no session, not a crash', () async {
    final container = containerWith(_MemoryStore(failLoad: true));
    container.listen(cosmosSessionProvider, (_, _) {});

    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(container.read(cosmosSessionProvider), isNull);
  });

  test('signing in holds the session and writes it', () async {
    final store = _MemoryStore();
    final container = containerWith(store);
    container.listen(cosmosSessionProvider, (_, _) {});

    await container.read(cosmosSessionProvider.notifier).signedIn(session);

    expect(container.read(cosmosSessionProvider), session);
    expect(store.saved, session);
  });

  test('signing out drops it from both', () async {
    final store = _MemoryStore(saved: session);
    final container = containerWith(store);
    container.listen(cosmosSessionProvider, (_, _) {});

    await container.read(cosmosSessionProvider.notifier).signedOut();

    expect(container.read(cosmosSessionProvider), isNull);
    expect(store.cleared, 1);
  });

  test('an expiry drops it, and only when there was one', () async {
    final store = _MemoryStore();
    final container = containerWith(store);
    container.listen(cosmosSessionProvider, (_, _) {});
    await container.read(cosmosSessionProvider.notifier).signedIn(session);

    container.read(cosmosSessionProvider.notifier).expired();
    expect(container.read(cosmosSessionProvider), isNull);
    expect(store.cleared, 1);

    // Every refused request calls this, and a gated route refuses every one of
    // them at once. Clearing a store that is already clear, once per request,
    // is a keychain write per request.
    container.read(cosmosSessionProvider.notifier).expired();
    expect(store.cleared, 1);
  });
}
