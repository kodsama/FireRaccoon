/// Typed failure from the Firefly III HTTP client.
class FireflyApiException implements Exception {
  FireflyApiException(
    this.message, {
    this.operation,
    this.cause,
    this.statusCode,
    this.unreachable = false,
    this.fieldErrors = const <String, String>{},
  });

  final String message;
  final String? operation;
  final Object? cause;
  final int? statusCode;

  /// True when the request never got a reply: the host did not resolve, the
  /// connection was refused, or it timed out.
  ///
  /// Set at the transport, because that is the only place that still knows.
  /// A failure raised further up carries no status either, so treating a bare
  /// [statusCode] of null as "unreachable" reported a refused 404 as a server
  /// nobody could reach.
  final bool unreachable;

  /// What Firefly said about each field it refused, keyed the way Firefly names
  /// them (`repetitions.0.moment`). Empty unless a write came back `422`.
  final Map<String, String> fieldErrors;

  @override
  String toString() {
    final op = operation == null ? '' : ' ($operation)';
    // A status code means Firefly answered and refused. Calling that a network
    // error sent people off to check their connection over a rejected field.
    if (statusCode != null) {
      return 'Firefly III refused the request$op ($statusCode): $message';
    }
    return 'Network error$op: $message';
  }
}
