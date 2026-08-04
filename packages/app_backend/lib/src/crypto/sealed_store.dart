import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

/// AES-256-GCM sealed filesystem under [dataDir], unlocked by a password.
///
/// Layout:
/// - `store.header` — salt + wrapped DEK (not the password)
/// - arbitrary relative paths written as ciphertext via [write] / [read]
class SealedStore {
  SealedStore._(this._dataDir, this._dataKey);

  static const _headerName = 'store.header';
  static const _pbkdf2Iterations = 210000;
  static const _saltLength = 16;
  static const _dekLength = 32;

  final Directory _dataDir;
  final SecretKey _dataKey;
  final AesGcm _aes = AesGcm.with256bits();

  Directory get dataDir => _dataDir;

  /// True when [dataDirPath] already contains a sealed store header.
  static bool exists(String dataDirPath) {
    final headerFile = File(p.join(dataDirPath, _headerName));
    return headerFile.existsSync();
  }

  /// Creates a new store when [dataDir] has no header, otherwise unlocks it.
  static Future<SealedStore> open({
    required String dataDirPath,
    required String password,
  }) async {
    if (password.isEmpty) {
      throw ArgumentError('password must not be empty');
    }
    final dataDir = Directory(dataDirPath);
    if (!dataDir.existsSync()) {
      await dataDir.create(recursive: true);
    }

    final headerFile = File(p.join(dataDir.path, _headerName));
    if (!headerFile.existsSync()) {
      return _create(
        dataDir: dataDir,
        password: password,
        headerFile: headerFile,
      );
    }
    return _unlock(
      dataDir: dataDir,
      password: password,
      headerFile: headerFile,
    );
  }

  static Future<SealedStore> _create({
    required Directory dataDir,
    required String password,
    required File headerFile,
  }) async {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => random.nextInt(256)),
    );
    final dekBytes = Uint8List.fromList(
      List<int>.generate(_dekLength, (_) => random.nextInt(256)),
    );
    final kek = await _deriveKek(password, salt);
    final aes = AesGcm.with256bits();
    final wrapped = await aes.encrypt(
      dekBytes,
      secretKey: kek,
      aad: utf8.encode('fireracoon-dek-v1'),
    );
    final header = <String, Object?>{
      'v': 1,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _pbkdf2Iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(wrapped.nonce),
      'mac': base64Encode(wrapped.mac.bytes),
      'wrappedDek': base64Encode(wrapped.cipherText),
    };
    await headerFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(header),
    );
    return SealedStore._(dataDir, SecretKey(dekBytes));
  }

  static Future<SealedStore> _unlock({
    required Directory dataDir,
    required String password,
    required File headerFile,
  }) async {
    final header =
        jsonDecode(await headerFile.readAsString()) as Map<String, dynamic>;
    if (header['v'] != 1) {
      throw StateError('Unsupported store header version: ${header['v']}');
    }
    final salt = base64Decode(header['salt'] as String);
    final kek = await _deriveKek(password, salt);
    final aes = AesGcm.with256bits();
    try {
      final dekBytes = await aes.decrypt(
        SecretBox(
          base64Decode(header['wrappedDek'] as String),
          nonce: base64Decode(header['nonce'] as String),
          mac: Mac(base64Decode(header['mac'] as String)),
        ),
        secretKey: kek,
        aad: utf8.encode('fireracoon-dek-v1'),
      );
      return SealedStore._(dataDir, SecretKey(dekBytes));
    } on SecretBoxAuthenticationError {
      throw StateError(
        'DATA_PASSWORD does not unlock DATA_DIR (wrong password).',
      );
    }
  }

  static Future<SecretKey> _deriveKek(String password, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  File _fileFor(String relativePath) {
    final normalized = p.normalize(relativePath);
    if (normalized.startsWith('..') || p.isAbsolute(normalized)) {
      throw ArgumentError('invalid relative path: $relativePath');
    }
    return File(p.join(_dataDir.path, '$normalized.enc'));
  }

  /// Encrypts [bytes] and writes them under [relativePath].enc.
  Future<void> write(String relativePath, List<int> bytes) async {
    final file = _fileFor(relativePath);
    await file.parent.create(recursive: true);
    final box = await _aes.encrypt(
      bytes,
      secretKey: _dataKey,
      aad: utf8.encode(relativePath),
    );
    final payload = <String, Object?>{
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'ciphertext': base64Encode(box.cipherText),
    };
    await file.writeAsString(jsonEncode(payload));
  }

  /// Reads and decrypts [relativePath], or returns null if missing.
  Future<Uint8List?> read(String relativePath) async {
    final file = _fileFor(relativePath);
    if (!file.existsSync()) return null;
    final payload =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final clear = await _aes.decrypt(
      SecretBox(
        base64Decode(payload['ciphertext'] as String),
        nonce: base64Decode(payload['nonce'] as String),
        mac: Mac(base64Decode(payload['mac'] as String)),
      ),
      secretKey: _dataKey,
      aad: utf8.encode(relativePath),
    );
    return Uint8List.fromList(clear);
  }

  Future<void> writeJson(String relativePath, Object? value) {
    return write(
      relativePath,
      utf8.encode(const JsonEncoder.withIndent('  ').convert(value)),
    );
  }

  Future<Object?> readJson(String relativePath) async {
    final bytes = await read(relativePath);
    if (bytes == null) return null;
    return jsonDecode(utf8.decode(bytes));
  }

  Future<void> delete(String relativePath) async {
    final file = _fileFor(relativePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
