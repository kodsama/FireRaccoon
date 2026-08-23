import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import 'auth_provider.dart';

enum FireflyConnectionStatus { disconnected, checking, connected, unreachable }

@visibleForTesting
const kFireflyConnectionPollInterval = Duration(seconds: 30);

/// Once the connection has been stable for a few probes, poll less often.
@visibleForTesting
const kFireflyConnectionStableInterval = Duration(minutes: 2);

@visibleForTesting
const kFireflyConnectionStableThreshold = 3;

class FireflyConnectionNotifier extends Notifier<FireflyConnectionStatus> {
  static final _log = AppLogger.scoped('providers.connection');
  Timer? _timer;
  int _checkGeneration = 0;
  int _consecutiveSuccesses = 0;
  Duration _pollInterval = kFireflyConnectionPollInterval;
  bool _rereadingCredentials = false;

  @override
  FireflyConnectionStatus build() {
    ref.onDispose(() {
      _log.finer('Disposing connection notifier and stopping poll timer');
      _timer?.cancel();
      _timer = null;
    });

    ref.listen(authProvider, (_, _) {
      _resetPollBackoff();
      Future.microtask(() => _probe(showChecking: true));
    }, fireImmediately: true);

    _startTimer(kFireflyConnectionPollInterval);
    _log.fine('Started Firefly connection polling every 30s');

    final auth = ref.read(authProvider);
    if (!auth.isHydrated) return FireflyConnectionStatus.checking;
    return auth.isValid
        ? FireflyConnectionStatus.checking
        : FireflyConnectionStatus.disconnected;
  }

  void refresh() {
    _resetPollBackoff();
    _probe(showChecking: true);
  }

  void _startTimer(Duration interval) {
    _timer?.cancel();
    _pollInterval = interval;
    _timer = Timer.periodic(interval, (_) => _probe(showChecking: false));
  }

  void _resetPollBackoff() {
    _consecutiveSuccesses = 0;
    if (_pollInterval != kFireflyConnectionPollInterval) {
      _startTimer(kFireflyConnectionPollInterval);
    }
  }

  void _probe({required bool showChecking}) {
    final generation = ++_checkGeneration;
    final auth = ref.read(authProvider);
    _log.finer(
      'Connection probe started (generation=$generation, showChecking=$showChecking)',
    );

    if (!auth.isHydrated) {
      state = FireflyConnectionStatus.checking;
      _log.finer('Probe skipped because auth is not hydrated yet');
      return;
    }

    if (auth.storageUnavailable) {
      // The keychain would not answer at startup. It may well answer now, once
      // its password has been typed, and this poll is the only thing that would
      // ever look again: without it the app stays disconnected until a relaunch.
      state = FireflyConnectionStatus.checking;
      if (!_rereadingCredentials) {
        _rereadingCredentials = true;
        _log.info('Credentials were unreadable; reading them again');
        Future.microtask(() async {
          try {
            await ref.read(authProvider.notifier).retryCredentialRead();
          } finally {
            _rereadingCredentials = false;
          }
        });
      }
      return;
    }

    if (!auth.isValid) {
      state = FireflyConnectionStatus.disconnected;
      _log.info('Probe marked status disconnected (missing credentials)');
      return;
    }

    if (showChecking || state == FireflyConnectionStatus.disconnected) {
      state = FireflyConnectionStatus.checking;
    }

    Future.microtask(() async {
      final ok = await ref
          .read(authProvider.notifier)
          .testConnection(auth.serverUrl, auth.apiToken, auth.allowInsecure);
      if (generation != _checkGeneration) return;

      state = ok
          ? FireflyConnectionStatus.connected
          : FireflyConnectionStatus.unreachable;
      if (ok) {
        _log.fine('Connection probe succeeded');
        _consecutiveSuccesses++;
        // Back off polling once the connection is clearly stable; the status
        // is informational sidebar text.
        if (_consecutiveSuccesses >= kFireflyConnectionStableThreshold &&
            _pollInterval != kFireflyConnectionStableInterval) {
          _log.fine('Connection stable; backing off poll interval');
          _startTimer(kFireflyConnectionStableInterval);
        }
      } else {
        _log.warning('Connection probe failed (endpoint unreachable)');
        _resetPollBackoff();
      }
    });
  }
}

final fireflyConnectionProvider =
    NotifierProvider<FireflyConnectionNotifier, FireflyConnectionStatus>(
      FireflyConnectionNotifier.new,
    );
