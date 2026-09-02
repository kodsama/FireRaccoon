import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Thrown when a sealed backup will not open.
class BackupPasswordException implements Exception {
  const BackupPasswordException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What a sealed backup's manifest carries so it can be opened again.
///
/// The salt and the count, never the password. The count is read back from the
/// manifest rather than from the constant below: raising the constant would
/// otherwise make every backup already written permanently unopenable, which is
/// how a stronger default turns into lost data.
class BackupSeal {
  const BackupSeal({required this.salt, required this.iterations});

  factory BackupSeal.fromJson(Map<String, Object?> json) => BackupSeal(
    salt: base64Decode(json['salt'] as String? ?? ''),
    iterations:
        (json['iterations'] as num?)?.toInt() ?? kBackupPbkdf2Iterations,
  );

  /// A fresh salt for a new backup.
  factory BackupSeal.create() {
    final random = Random.secure();
    return BackupSeal(
      salt: Uint8List.fromList(
        List<int>.generate(16, (_) => random.nextInt(256)),
      ),
      iterations: kBackupPbkdf2Iterations,
    );
  }

  final List<int> salt;
  final int iterations;

  Map<String, Object?> toJson() => {
    'algorithm': 'aes-256-gcm',
    'kdf': 'pbkdf2-hmac-sha256',
    'iterations': iterations,
    'salt': base64Encode(salt),
  };
}

/// Cost of turning a backup password into a key.
///
/// The same count the settings export and the server's sealed store use, so
/// there is one answer to how hard FireRaccoon makes a guess.
const int kBackupPbkdf2Iterations = 210000;

/// Marks a payload file as sealed. Four bytes, so a reader can tell without
/// parsing what a wrong guess would have to decrypt.
const List<int> kSealedBackupMagic = [0x46, 0x52, 0x42, 0x31]; // 'FRB1'

/// True when [bytes] is a sealed payload rather than plain JSON or CSV.
bool isSealedBackupFile(List<int> bytes) {
  if (bytes.length < kSealedBackupMagic.length) return false;
  for (var i = 0; i < kSealedBackupMagic.length; i++) {
    if (bytes[i] != kSealedBackupMagic[i]) return false;
  }
  return true;
}

/// Seals and opens the files inside one backup.
///
/// One key per backup, derived once from the password and the manifest's salt.
/// Deriving per file at 210,000 rounds would cost about a second each, and a
/// backup has eleven of them; the nonce is what keeps the files distinct.
///
/// The file's own name is the associated data, so a sealed snapshot cannot be
/// passed off as a sealed export of something else.
class BackupCipher {
  BackupCipher._(this._key);

  static final AesGcm _aes = AesGcm.with256bits();
  static const int _macLength = 16;

  final SecretKey _key;

  static Future<BackupCipher> derive(String password, BackupSeal seal) async {
    if (password.isEmpty) {
      throw const BackupPasswordException('A password is required.');
    }
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: seal.iterations,
      bits: 256,
    );
    return BackupCipher._(
      await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: seal.salt,
      ),
    );
  }

  /// `FRB1 | nonce length | nonce | mac | ciphertext`.
  ///
  /// Bytes rather than base64: a snapshot of a real ledger runs to megabytes,
  /// and encoding it as text would add a third again for nothing.
  Future<List<int>> seal(String fileName, List<int> plaintext) async {
    final box = await _aes.encrypt(
      plaintext,
      secretKey: _key,
      aad: utf8.encode(fileName),
    );
    return <int>[
      ...kSealedBackupMagic,
      box.nonce.length,
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ];
  }

  Future<List<int>> open(String fileName, List<int> sealed) async {
    if (!isSealedBackupFile(sealed)) return sealed;
    final nonceLength = sealed[kSealedBackupMagic.length];
    final nonceStart = kSealedBackupMagic.length + 1;
    final macStart = nonceStart + nonceLength;
    final cipherStart = macStart + _macLength;
    if (sealed.length < cipherStart) {
      throw const BackupPasswordException(
        'This file is marked sealed but is too short to be one.',
      );
    }
    try {
      return await _aes.decrypt(
        SecretBox(
          sealed.sublist(cipherStart),
          nonce: sealed.sublist(nonceStart, macStart),
          mac: Mac(sealed.sublist(macStart, cipherStart)),
        ),
        secretKey: _key,
        aad: utf8.encode(fileName),
      );
    } on SecretBoxAuthenticationError {
      throw const BackupPasswordException(
        'That password does not open this backup, or the file has been '
        'altered since it was written.',
      );
    }
  }
}
