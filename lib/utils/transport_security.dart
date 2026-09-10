/// Whether [url] carries the connection in the clear.
///
/// Scheme only. A hostname that happens to resolve to a local address says
/// nothing about whether the bytes are encrypted, and treating it as if it did
/// is how a token ends up on a network someone else can read.
bool isUnencryptedUrl(String url) {
  final scheme = Uri.tryParse(url.trim())?.scheme.toLowerCase();
  return scheme == 'http';
}

/// Raised when a plain-http server is given without the caller having said, in
/// as many words, that they mean it.
///
/// The refusal lives at the store rather than at the connection test, because
/// a URL reaches the store from a settings import and from an OAuth sign-in as
/// well as from the form that tests first.
class InsecureTransportRefused implements Exception {
  const InsecureTransportRefused(this.url);

  final String url;

  @override
  String toString() =>
      '$url is a plain http:// address. Turn on Allow HTTP connections to use '
      'it, and know that the token and every answer travel in the clear.';
}

/// Refuses [url] unless [allowInsecure] says the person chose this.
///
/// [dialledByServer] lifts the refusal, because then this process never opens
/// that connection. A web build in server mode talks to its own origin over
/// whatever protocol the page was served with, and the address named here is
/// one the server resolves on its own network. Refusing it browser-side made
/// an internal backend impossible to save: the only address that works is the
/// one the refusal was aimed at.
void requireEncryptedTransport(
  String url, {
  required bool allowInsecure,
  bool dialledByServer = false,
}) {
  if (allowInsecure || dialledByServer) return;
  if (isUnencryptedUrl(url)) throw InsecureTransportRefused(url);
}
