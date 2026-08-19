import 'dart:convert';

import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage.dart';

const String kAgentKeysStorageKey = 'agent_keys_v1';

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
