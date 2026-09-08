/// Raised when the platform credential store would not hand the connection back.
///
/// Another state that is not a fault: the connection was saved and is still
/// there, but the keychain has relocked, its prompt was dismissed, or the
/// session it belongs to has timed out. Typed so the screens can say that and
/// offer to ask again, rather than showing an exception to someone whose only
/// problem is a locked keychain.
class CredentialStoreLockedException implements Exception {
  const CredentialStoreLockedException();

  @override
  String toString() =>
      'The credential store would not answer. Unlock it and try again.';
}
