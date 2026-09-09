import 'package:fireraccoon_engine/fireraccoon_engine.dart';

/// Raised when the server address answers, but nothing there is Firefly III.
///
/// A reverse proxy that will not route a request answers with its own 404 for
/// every path, which is a different thing from a proxy asking who you are: no
/// credential fixes it and no sign-in creates the route. Cosmos, for one,
/// redirects a caller it wants to authenticate and falls through to Go's plain
/// `404 page not found` for a host it has no route for at all.
///
/// A [FireflyApiException] so the engine's send loop rethrows it untouched,
/// and [unreachable] because Firefly III never saw the request.
class NoRouteToFireflyException extends FireflyApiException {
  NoRouteToFireflyException(this.host)
    : super(
        'Something answers at $host, but it did not route the request to '
        'Firefly III.',
        unreachable: true,
      );

  /// The host that answered without routing.
  final String host;

  @override
  String toString() => message;
}
