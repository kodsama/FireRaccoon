import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../store/cosmos_session.dart';
import '../store/cosmos_session_store.dart';

final _log = AppLogger.scoped('providers.cosmosSession');

final cosmosSessionStoreProvider = Provider<CosmosSessionStore>(
  (ref) => CosmosSessionStore(),
);

/// The Cosmos route session, or null when there is none.
///
/// Held in a notifier rather than read per call because the request path asks
/// for it on every request: a keychain trip per Firefly call would be absurd.
class CosmosSessionNotifier extends Notifier<CosmosSession?> {
  @override
  CosmosSession? build() {
    // The store answers later; until it does there is no session to send, and
    // a request made in that window simply goes without one. Cosmos answers
    // with its login redirect, which is already handled.
    Future.microtask(_load);
    return null;
  }

  CosmosSessionStore get _store => ref.read(cosmosSessionStoreProvider);

  final _hydrated = Completer<void>();

  /// Resolves once the store has been asked, whatever it answered.
  ///
  /// The read is a keychain trip, so for the first moments of a launch there is
  /// no session here even when one is saved. Anything that treats a null
  /// session as "there has never been one" has to wait for this, or it decides
  /// nobody ever signed in on the strength of a read still in flight.
  Future<void> get hydrated => _hydrated.future;

  Future<void> _load() async {
    try {
      final session = await _store.load();
      if (session != null) {
        _log.info('Cosmos session restored for ${session.host}');
      }
      state = session;
    } on Object catch (error, stackTrace) {
      // A store that will not answer is not a store with no session in it, but
      // there is nothing to do about it here beyond going without.
      _log.warning('Could not read the Cosmos session', error, stackTrace);
    } finally {
      if (!_hydrated.isCompleted) _hydrated.complete();
    }
  }

  Future<void> signedIn(CosmosSession session) async {
    state = session;
    _log.info('Cosmos session saved for ${session.host}');
    await _store.save(session);
  }

  Future<void> signedOut() async {
    state = null;
    _log.info('Cosmos session cleared');
    await _store.clear();
  }

  /// Takes the cookie Cosmos has just replaced the session with.
  ///
  /// The whole reason a browser stays signed in for months and this app used
  /// to expire a fortnight after the sign-in: Cosmos rolls the route session
  /// forward on any request once its token is a day old, and only a client
  /// that keeps the new cookie benefits.
  Future<void> rolledForward(String cookie) async {
    final current = state;
    if (current == null || current.cookie == cookie) return;
    _log.info('Cosmos rolled the route session forward for ${current.host}');
    state = CosmosSession(
      host: current.host,
      cookie: cookie,
      obtainedAt: DateTime.now().toUtc(),
    );
    await _store.save(state!);
  }

  /// Drops a session Cosmos has stopped accepting.
  ///
  /// Separate from [signedOut] so the log says which happened: one is a person
  /// choosing, the other is a session running out.
  void expired() {
    if (state == null) return;
    _log.warning('Cosmos turned the request away; the session is gone');
    state = null;
    _store.clear();
  }
}

final cosmosSessionProvider =
    NotifierProvider<CosmosSessionNotifier, CosmosSession?>(
      CosmosSessionNotifier.new,
    );
