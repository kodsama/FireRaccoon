/// Raised when something asks Firefly III for data before a server is connected.
///
/// This is a state, not a fault. Nothing broke: the app has nowhere to ask yet,
/// because nobody has finished setting up. It is typed so callers can say that
/// plainly instead of putting an exception message in front of someone who has
/// simply not connected a server, and so MCP can answer an agent with a state
/// it can act on rather than an opaque tool failure.
class FireflyNotConnectedException implements Exception {
  const FireflyNotConnectedException([this.message = _default]);

  static const _default =
      'Not connected to Firefly III. Open Settings and connect your server.';

  final String message;

  @override
  String toString() => message;
}
