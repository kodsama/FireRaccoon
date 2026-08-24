import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:http/http.dart' as http;

/// PBKDF2 iteration count for new password hashes.
///
/// The number an attacker with a stolen store has to pay per guess. OWASP's
/// figure for PBKDF2-HMAC-SHA256 is 600k, and a count is only worth raising if
/// raising it does not lock everyone out, which is why [encodePasswordHash]
/// stores the count it was derived with.
const int kPbkdf2Iterations = 600000;

/// What a hash with no recorded count was derived at.
///
/// Hashes written before the count was stored are a bare base64 digest. They
/// still verify at the count that produced them, and get rewritten at the
/// current one the next time the password is set.
const int kLegacyPbkdf2Iterations = 100000;

const int _kDerivedKeyLength = 32;
const int _kSaltLength = 16;

/// Result of checking a candidate password against the FireRacoon policy:
/// at least 10 characters, one upper, one lower, one digit, one special char.
class PasswordPolicyResult {
  final bool hasMinLength;
  final bool hasUpper;
  final bool hasLower;
  final bool hasDigit;
  final bool hasSpecial;

  const PasswordPolicyResult({
    required this.hasMinLength,
    required this.hasUpper,
    required this.hasLower,
    required this.hasDigit,
    required this.hasSpecial,
  });

  bool get isValid =>
      hasMinLength && hasUpper && hasLower && hasDigit && hasSpecial;

  /// Requirements that [password] still fails, in display order.
  List<PasswordRequirement> get missingRequirements {
    return [
      if (!hasMinLength) PasswordRequirement.minLength,
      if (!hasUpper) PasswordRequirement.upper,
      if (!hasLower) PasswordRequirement.lower,
      if (!hasDigit) PasswordRequirement.digit,
      if (!hasSpecial) PasswordRequirement.special,
    ];
  }
}

/// Individual clauses of the FireRacoon password policy.
enum PasswordRequirement { minLength, upper, lower, digit, special }

const int kPasswordMinLength = 10;

final RegExp _upperPattern = RegExp('[A-Z]');
final RegExp _lowerPattern = RegExp('[a-z]');
final RegExp _digitPattern = RegExp('[0-9]');
final RegExp _specialPattern = RegExp(r'[^A-Za-z0-9]');

/// Validates [password] against the FireRacoon policy. Pure and synchronous;
/// callers that also want the HIBP breach check should call
/// [isPasswordPwned] separately since that requires a network round trip.
PasswordPolicyResult validatePasswordPolicy(String password) {
  return PasswordPolicyResult(
    hasMinLength: password.length >= kPasswordMinLength,
    hasUpper: _upperPattern.hasMatch(password),
    hasLower: _lowerPattern.hasMatch(password),
    hasDigit: _digitPattern.hasMatch(password),
    hasSpecial: _specialPattern.hasMatch(password),
  );
}

/// A derived password hash and the random salt used to produce it, both
/// base64-encoded for storage alongside the [AppUser] record.
class PasswordHash {
  final String hash;
  final String salt;

  const PasswordHash({required this.hash, required this.salt});
}

/// Stored form of a hash, carrying the count it was derived with.
///
/// `pbkdf2-sha256$<iterations>$<base64 digest>`. Storing only the digest meant
/// the count was whatever the constant happened to be when the hash was read,
/// so raising it would have turned every existing password into a wrong one.
String encodePasswordHash(int iterations, String digestBase64) =>
    'pbkdf2-sha256\$$iterations\$$digestBase64';

/// The count and digest inside a stored hash.
///
/// A bare base64 string is the older form and reads as
/// [kLegacyPbkdf2Iterations], which is what produced it.
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

/// Hashes [password] with PBKDF2-HMAC-SHA256 off the calling isolate.
///
/// The derivation is a hot loop that takes seconds at this count, so running it
/// where the UI lives freezes the window for its whole duration. Every caller
/// already awaits.
Future<PasswordHash> hashPassword(String password, {String? saltBase64}) async {
  final salt = saltBase64 != null
      ? base64Decode(saltBase64)
      : _randomBytes(_kSaltLength);
  final derived = await _deriveOffIsolate(password, salt, kPbkdf2Iterations);
  return PasswordHash(
    hash: encodePasswordHash(kPbkdf2Iterations, base64Encode(derived)),
    salt: base64Encode(salt),
  );
}

/// Recomputes the hash for [password] and compares it in constant time.
///
/// Derived at the count recorded in [hash], not the current default, so a
/// password set before the default moved still opens the account.
Future<bool> verifyPassword(
  String password, {
  required String hash,
  required String salt,
}) async {
  final stored = decodePasswordHash(hash);
  final derived = await _deriveOffIsolate(
    password,
    base64Decode(salt),
    stored.iterations,
  );
  return _constantTimeEquals(base64Encode(derived), stored.digest);
}

/// True when [hash] was derived at fewer rounds than new hashes get.
///
/// Lets a successful sign-in rewrite the stored hash at the current count,
/// which is the only way an old one ever improves.
bool passwordHashIsStale(String hash) =>
    decodePasswordHash(hash).iterations < kPbkdf2Iterations;

Future<Uint8List> _deriveOffIsolate(
  String password,
  List<int> salt,
  int iterations,
) {
  return compute(_derive, (
    password: password,
    salt: Uint8List.fromList(salt),
    iterations: iterations,
  ));
}

/// Derives at the count that produced hashes written before the count was
/// stored, so a test can build one to verify against.
@visibleForTesting
Uint8List legacyDeriveForTest(String password, String saltBase64) {
  return _pbkdf2Hmac256(
    password: utf8.encode(password),
    salt: base64Decode(saltBase64),
    iterations: kLegacyPbkdf2Iterations,
    keyLength: _kDerivedKeyLength,
  );
}

/// Top-level so it can cross an isolate boundary.
Uint8List _derive(({String password, Uint8List salt, int iterations}) request) {
  return _pbkdf2Hmac256(
    password: utf8.encode(request.password),
    salt: request.salt,
    iterations: request.iterations,
    keyLength: _kDerivedKeyLength,
  );
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}

/// PBKDF2 as defined in RFC 8018, instantiated with HMAC-SHA256.
Uint8List _pbkdf2Hmac256({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  required int keyLength,
}) {
  const hashLength = 32; // SHA-256 digest size.
  final hmac = Hmac(sha256, password);
  final blockCount = (keyLength / hashLength).ceil();
  final derived = BytesBuilder();

  for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
    final blockSeed = Uint8List.fromList([
      ...salt,
      (blockIndex >> 24) & 0xff,
      (blockIndex >> 16) & 0xff,
      (blockIndex >> 8) & 0xff,
      blockIndex & 0xff,
    ]);
    var u = Uint8List.fromList(hmac.convert(blockSeed).bytes);
    final block = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var k = 0; k < block.length; k++) {
        block[k] ^= u[k];
      }
    }
    derived.add(block);
  }

  return derived.toBytes().sublist(0, keyLength);
}

/// Checks [password] against the Have I Been Pwned range API using
/// k-anonymity (only a 5-char SHA-1 prefix leaves the device).
///
/// Returns `true` if the password appears in a known breach, `false` if it
/// does not, or `null` when the check could not complete (offline, timeout,
/// non-200 response). Callers should fail open on `null` rather than block
/// account creation when the API is unreachable.
Future<bool?> isPasswordPwned(String password, {http.Client? client}) async {
  final owns = client == null;
  final httpClient = client ?? http.Client();
  try {
    final digest = sha1.convert(utf8.encode(password)).toString().toUpperCase();
    final prefix = digest.substring(0, 5);
    final suffix = digest.substring(5);

    final response = await httpClient
        .get(Uri.parse('https://api.pwnedpasswords.com/range/$prefix'))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;

    for (final line in const LineSplitter().convert(response.body)) {
      final parts = line.split(':');
      if (parts.isNotEmpty && parts.first.trim() == suffix) {
        return true;
      }
    }
    return false;
  } on Object {
    return null;
  } finally {
    if (owns) httpClient.close();
  }
}
