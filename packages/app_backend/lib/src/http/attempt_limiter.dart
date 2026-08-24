/// Counts failed attempts per identity and refuses once there are too many.
///
/// Guessing a password over HTTP is only expensive if something makes it
/// expensive. The key derivation costs the server as much as the attacker, so
/// it caps the rate and nothing else: a password worth guessing is still worth
/// guessing a few hundred thousand times.
///
/// Held in memory on purpose. Persisting it would let anyone who can reach the
/// endpoint grow the encrypted store, and a restart clearing the counters costs
/// an attacker a restart they cannot ask for.
class AttemptLimiter {
  AttemptLimiter({
    required this.maxAttempts,
    required this.lockout,
    required this.window,
  });

  /// Failures allowed inside [window] before [check] starts refusing.
  final int maxAttempts;

  /// How long a refusal lasts once the allowance is spent.
  final Duration lockout;

  /// Failures older than this stop counting, so an occasional typo never
  /// accumulates into a lockout.
  final Duration window;

  final Map<String, List<DateTime>> _failures = {};
  final Map<String, DateTime> _lockedUntil = {};

  /// How long [identity] must wait, or null when it may try now.
  Duration? retryAfter(String identity, {required DateTime now}) {
    final until = _lockedUntil[identity];
    if (until == null) return null;
    if (!until.isAfter(now)) {
      _lockedUntil.remove(identity);
      _failures.remove(identity);
      return null;
    }
    return until.difference(now);
  }

  /// Records a failure, locking [identity] out once the allowance is spent.
  void recordFailure(String identity, {required DateTime now}) {
    final recent =
        (_failures[identity] ?? <DateTime>[])
            .where((at) => now.difference(at) < window)
            .toList()
          ..add(now);
    _failures[identity] = recent;
    if (recent.length >= maxAttempts) {
      _lockedUntil[identity] = now.add(lockout);
    }
  }

  /// Forgets [identity]'s failures, which is what a success means.
  void recordSuccess(String identity) {
    _failures.remove(identity);
    _lockedUntil.remove(identity);
  }
}
