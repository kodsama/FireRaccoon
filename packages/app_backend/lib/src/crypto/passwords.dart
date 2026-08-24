import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto_pkg;
import 'package:cryptography/cryptography.dart';

/// PBKDF2 helpers aligned with the Flutter client's password_policy.
///
/// The count an attacker with a stolen store pays per guess. OWASP's figure for
/// PBKDF2-HMAC-SHA256 is 600k, and raising it is only safe because the stored
/// hash records the count it was derived with.
const int kPbkdf2Iterations = 600000;

/// What a hash with no recorded count was derived at.
const int kLegacyPbkdf2Iterations = 100000;

/// Stored form: `pbkdf2-sha256$<iterations>$<base64 digest>`.
///
/// Storing the digest alone meant the count was whatever the constant happened
/// to be when the hash was read, so raising it would have turned every existing
/// password into a wrong one.
String encodePasswordHash(int iterations, String digestBase64) =>
    'pbkdf2-sha256\$$iterations\$$digestBase64';

({int iterations, String digest}) decodePasswordHash(String stored) {
  final parts = stored.split(r'$');
  if (parts.length != 3 || parts.first != 'pbkdf2-sha256') {
    return (iterations: kLegacyPbkdf2Iterations, digest: stored);
  }
  return (
    iterations: int.tryParse(parts[1]) ?? kLegacyPbkdf2Iterations,
    digest: parts[2],
  );
}

const int _kDerivedKeyLength = 32;
const int _kSaltLength = 16;

class PasswordHash {
  const PasswordHash({required this.hash, required this.salt});

  final String hash;
  final String salt;
}

/// [iterations] exists for tests, which would otherwise pay production cost for
/// every password they set. The count is recorded in the hash, so one made here
/// verifies at the count that made it.
Future<PasswordHash> hashPassword(
  String password, {
  int iterations = kPbkdf2Iterations,
}) async {
  final random = Random.secure();
  final saltBytes = Uint8List.fromList(
    List<int>.generate(_kSaltLength, (_) => random.nextInt(256)),
  );
  final hashBytes = await _pbkdf2(password, saltBytes, iterations);
  return PasswordHash(
    hash: encodePasswordHash(iterations, base64Encode(hashBytes)),
    salt: base64Encode(saltBytes),
  );
}

Future<bool> verifyPassword({
  required String password,
  required String hash,
  required String salt,
}) async {
  final stored = decodePasswordHash(hash);
  final saltBytes = base64Decode(salt);
  final actual = await _pbkdf2(password, saltBytes, stored.iterations);
  final expected = base64Decode(stored.digest);
  if (actual.length != expected.length) return false;
  var diff = 0;
  for (var i = 0; i < actual.length; i++) {
    diff |= actual[i] ^ expected[i];
  }
  return diff == 0;
}

Future<List<int>> _pbkdf2(
  String password,
  List<int> salt,
  int iterations,
) async {
  // Use cryptography package PBKDF2 for consistency with sealed store.
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: _kDerivedKeyLength * 8,
  );
  final key = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
  final data = await key.extract();
  return data.bytes;
}

String hashSessionToken(String token) {
  return crypto_pkg.sha256.convert(utf8.encode(token)).toString();
}

String newId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

String newSessionToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
