import 'dart:async';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/cosmos_login.dart';
import '../store/cosmos_login_factory.dart';
import '../store/cosmos_session.dart';
import 'cosmos_session_provider.dart';

final _log = AppLogger.scoped('providers.cosmosGate');

/// The sign-in this build can run.
///
/// A provider so a test can hand over one that opens no web view.
final cosmosLoginProvider = Provider<CosmosLogin>(
  (ref) => resolveCosmosLogin(),
);

/// Where the Cosmos door stands.
enum CosmosGate {
  /// Not in the way: either no Cosmos route is involved, or the session in
  /// hand is being accepted.
  open,

  /// Cosmos refused, and a fresh session is being fetched without bothering
  /// anyone.
  renewing,

  /// The renewal needed a person after all.
  signInRequired,
}

/// Keeps a Cosmos route session alive without asking.
///
/// A route session runs out long before the Cosmos login behind it does, so
/// the usual renewal is a redirect through Cosmos and straight back with
/// nothing typed. Doing that here is why signing in is a rare event rather
/// than something that greets people whenever they open the app.
///
/// Deliberately depends on nothing that depends on it. The refused address
/// arrives with the refusal rather than being read back out of the credentials,
/// because the credentials notifier reports refusals to this one: reading it
/// from here closed the loop and Riverpod refused the whole connection test
/// with a circular dependency, which read as a server nobody could reach.
class CosmosGateNotifier extends Notifier<CosmosGate> {
  bool _renewing = false;
  bool _disposed = false;

  /// A renewal has run and nothing has yet proved that it worked.
  ///
  /// The one thing standing between a renewal and a loop. Cosmos hides a shut
  /// route behind a plain 404 and sets no cookie for it, so a renewal that
  /// reads the jar afterwards can hand back a session as dead as the one it
  /// replaced. Refused, dropped, renewed again: twice a second, forever.
  bool _renewalSpent = false;

  /// The session the last renewal minted, so a session arriving from a person
  /// is told apart from one this notifier put there itself.
  CosmosSession? _renewed;

  @override
  CosmosGate build() {
    ref.onDispose(() => _disposed = true);
    ref.listen(cosmosSessionProvider, (_, session) {
      if (session == null) return;
      // However a session arrived, renewed here or signed in by hand, it is
      // the answer to whatever this was waiting for.
      _set(CosmosGate.open);
      // Somebody has just signed in, which is a fresh start: whatever the last
      // renewal did says nothing about this session.
      if (session != _renewed) _renewalSpent = false;
    });
    return CosmosGate.open;
  }

  void _set(CosmosGate gate) {
    if (_disposed || state == gate) return;
    state = gate;
  }

  /// Cosmos routed a request, which is the only proof a session works.
  ///
  /// Called for every answer that came from behind the door rather than from
  /// the door itself, so it stays a field write and nothing more.
  void accepted() {
    if (!_renewalSpent) return;
    _renewalSpent = false;
    _renewed = null;
  }

  /// The server address changed, so whatever was decided is about a door this
  /// app no longer knocks on.
  ///
  /// Told rather than watched, because the credentials notifier reports
  /// refusals to this one and listening back would close the loop. Without it,
  /// correcting an address that had been refused left every request blocked on
  /// a sign-in for the old host, and nothing was ever sent that could prove
  /// the new one works.
  void addressChanged() {
    _renewalSpent = false;
    _renewed = null;
    _set(CosmosGate.open);
  }

  /// Cosmos refused to route a request bound for [url].
  ///
  /// Renews at most once at a time, and only from [CosmosGate.open]: every
  /// request in flight meets the same closed door, and each of them asking for
  /// its own renewal would open a web view per request.
  void rejected(Uri url) {
    final routeUrl = Uri(
      scheme: url.scheme,
      host: url.host,
      port: url.hasPort ? url.port : null,
      path: '/',
    );
    if (routeUrl.host.isEmpty) return;
    if (_renewing || state != CosmosGate.open) return;
    if (_renewalSpent) {
      _log.info('The renewal did not hold; a person has to sign in');
      _set(CosmosGate.signInRequired);
      return;
    }
    _renewing = true;
    // Said before anything is decided, so the screens that were loading keep
    // loading instead of flashing a not-connected message on the way back.
    _set(CosmosGate.renewing);
    unawaited(_renew(routeUrl));
  }

  Future<void> _renew(Uri routeUrl) async {
    try {
      // The store is a keychain trip. A request refused in the first moments
      // of a launch must not be told nobody ever signed in on the strength of
      // a read still in flight.
      await ref.read(cosmosSessionProvider.notifier).hydrated;
      if (_disposed) return;

      final session = ref.read(cosmosSessionProvider);
      final login = ref.read(cosmosLoginProvider);
      // Renewing rides on the Cosmos login left behind by the last sign-in.
      // With no session for this host there was never a sign-in on this
      // device, so there is nothing to ride on.
      if (session == null ||
          !session.appliesTo(routeUrl) ||
          !login.isSupported) {
        _set(CosmosGate.signInRequired);
        return;
      }

      // Dropped before the renewal rather than after it: the cookie is already
      // dead, and leaving it in place would tell the settings screen someone is
      // signed in to a route that will not let them through.
      final refused = session.cookie;
      ref.read(cosmosSessionProvider.notifier).expired();

      final renewed = await login.renew(routeUrl, staleCookie: refused);
      if (_disposed) return;
      if (renewed == null) {
        _log.info('Cosmos wanted a person; the quiet renewal did not land');
        _set(CosmosGate.signInRequired);
        return;
      }
      _log.info('Cosmos session renewed for ${renewed.host} without asking');
      _renewed = renewed;
      _renewalSpent = true;
      // The connection poll is watching for a session to arrive and re-checks
      // itself, so nothing here has to reach for it.
      await ref.read(cosmosSessionProvider.notifier).signedIn(renewed);
      if (_disposed) return;
      _set(CosmosGate.open);
    } on Object catch (error, stackTrace) {
      _log.warning('The Cosmos renewal could not run', error, stackTrace);
      _set(CosmosGate.signInRequired);
    } finally {
      _renewing = false;
    }
  }
}

final cosmosGateProvider = NotifierProvider<CosmosGateNotifier, CosmosGate>(
  CosmosGateNotifier.new,
);
