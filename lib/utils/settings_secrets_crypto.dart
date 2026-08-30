import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Thrown when a settings backup secrets blob cannot be unlocked.
class SettingsSecretsUnlockException implements Exception {
  SettingsSecretsUnlockException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// AES-256-GCM + PBKDF2 envelope for settings-backup secrets.
///
/// Same construction as the server sealed store: password never appears in the
/// file; only salt + ciphertext + MAC.
class SettingsSecretsCrypto {
  SettingsSecretsCrypto._();

  static const int version = 1;
  static const int pbkdf2Iterations = 210000;
  static const int saltLength = 16;
  static const String aad = 'fireraccoon-settings-secrets-v1';

  static Future<Map<String, dynamic>> seal({
    required Map<String, dynamic> plaintext,
    required String passphrase,
  }) async {
    if (passphrase.isEmpty) {
      throw ArgumentError('passphrase must not be empty');
    }
    final salt = _randomBytes(saltLength);
    final key = await _deriveKey(passphrase, salt);
    final aes = AesGcm.with256bits();
    final box = await aes.encrypt(
      utf8.encode(jsonEncode(plaintext)),
      secretKey: key,
      aad: utf8.encode(aad),
    );
    return {
      'v': version,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': pbkdf2Iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'ciphertext': base64Encode(box.cipherText),
    };
  }

  static Future<Map<String, dynamic>> unseal({
    required Map<String, dynamic> envelope,
    required String passphrase,
  }) async {
    if (passphrase.isEmpty) {
      throw SettingsSecretsUnlockException('Backup passphrase is required.');
    }
    if (envelope['v'] != version) {
      throw FormatException(
        'Unsupported settings secrets version: ${envelope['v']}',
      );
    }
    final salt = base64Decode(envelope['salt'] as String);
    // Read from the envelope, never from the constant. Sealing writes the count
    // it used, and deriving with a different one fails as a wrong passphrase, so
    // raising the constant would have made every backup already written
    // permanently unopenable. The sealed store learned this the same way.
    final iterations =
        (envelope['iterations'] as num?)?.toInt() ?? pbkdf2Iterations;
    final key = await _deriveKey(passphrase, salt, iterations);
    final aes = AesGcm.with256bits();
    try {
      final clear = await aes.decrypt(
        SecretBox(
          base64Decode(envelope['ciphertext'] as String),
          nonce: base64Decode(envelope['nonce'] as String),
          mac: Mac(base64Decode(envelope['mac'] as String)),
        ),
        secretKey: key,
        aad: utf8.encode(aad),
      );
      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Secrets payload must be a JSON object.');
      }
      return decoded;
    } on SecretBoxAuthenticationError {
      throw SettingsSecretsUnlockException(
        'Incorrect backup passphrase, or the secrets blob is corrupted.',
      );
    }
  }

  static Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt, [
    int iterations = pbkdf2Iterations,
  ]) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
