import 'package:fireraccoon_engine/fireraccoon_engine.dart';

/// Raised when Cosmos Cloud turned a request away at its own door.
///
/// Extends [FireflyApiException] so the engine's send loop rethrows it
/// untouched instead of retrying: Cosmos answers a request it will not route
/// the same way however often it is asked. [unreachable] is true because that
/// is what happened whatever the status code said, so nothing downstream
/// reports a Firefly III that refused a request it never saw.
class CosmosSignInRequiredException extends FireflyApiException {
  CosmosSignInRequiredException(this.host)
    : super(
        'Cosmos Cloud did not route the request to Firefly III at $host. '
        'Signing in to Cosmos opens the route again.',
        unreachable: true,
      );

  /// The route host Cosmos refused, which is also the host a sign-in is for.
  final String host;

  @override
  String toString() => message;
}
