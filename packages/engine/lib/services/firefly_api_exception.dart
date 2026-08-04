/// Typed failure from the Firefly III HTTP client.
class FireflyApiException implements Exception {
  FireflyApiException(
    this.message, {
    this.operation,
    this.cause,
    this.statusCode,
  });

  final String message;
  final String? operation;
  final Object? cause;
  final int? statusCode;

  @override
  String toString() {
    final op = operation == null ? '' : ' ($operation)';
    return 'Network error$op: $message';
  }
}
