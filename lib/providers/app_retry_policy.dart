import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/credential_store_locked_exception.dart';

/// When a failed provider is worth building again, and when it is not.
///
/// Riverpod retries a failing provider ten times on its own, backing off to
/// every 6.4 seconds. For a server that is down, or behind a door nobody has
/// opened, that turns one refusal into more than a hundred requests and a
/// screenful of log lines that all say the same thing. The states below do not
/// improve by being asked again, and each of them already has something
/// watching for the moment it does: the connection poll rebuilds every one of
/// these providers as soon as the server answers.
Duration? fireflyProviderRetry(int retryCount, Object error) {
  if (error is FireflyNotConnectedException) return null;
  if (error is CredentialStoreLockedException) return null;
  if (error is FireflyApiException) {
    if (error.unreachable) return null;
    final status = error.statusCode;
    // Firefly answered and refused. A bad token or a missing record is the
    // same on the fourth ask as on the first.
    if (status != null && status >= 400 && status < 500) return null;
  }
  // Everything else is a blip worth a few quick tries rather than forty
  // seconds of them.
  return ProviderContainer.defaultRetry(retryCount, error, maxRetries: 3);
}
