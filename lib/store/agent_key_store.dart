import 'dart:convert';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage.dart';

const String kAgentKeysStorageKey = 'agent_keys_v1';

/// Describes a key-store failure with the platform's status code kept.
///
/// The code is the part that names the cause: `-34018` is a missing
/// entitlement, `-25300` a missing item, `-25293` a refused authorisation.
/// Without it the reader is left guessing at exactly the point they need to
/// act, and the app logger records an error's type but never its text.
String describeAgentKeyFailure(Object error) {
  if (error is PlatformException) {
    final detail = error.message ?? '';
    return detail.isEmpty
        ? 'Keychain error ${error.code}'
        : 'Keychain error ${error.code}: $detail';
  }
  return '$error';
}

/// Persists MCP agent keys for local mode, in the platform keychain.
///
/// Secrets are kept so their owner can read a key back instead of reissuing it.
/// The Firefly PAT already lives in this same keychain and grants strictly more,
/// so this adds no exposure that was not already there. Key material never
/// leaves through a settings export. Server mode keeps its keys in the sealed
/// store instead, reached through `RemoteServerClient`.
class AgentKeyStore {
  AgentKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? appSecureStorage;

  final FlutterSecureStorage _storage;

  Future<List<AgentKey>> load() async {
    final raw = await _storage.read(key: kAgentKeysStorageKey);
    if (raw == null || raw.isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map) ?AgentKey.fromJson(entry.cast<String, Object?>()),
    ];
  }

  Future<void> save(List<AgentKey> keys) async {
    await _storage.write(
      key: kAgentKeysStorageKey,
      value: jsonEncode([for (final key in keys) key.toJson()]),
    );
  }

  Future<void> clear() => _storage.delete(key: kAgentKeysStorageKey);
}
