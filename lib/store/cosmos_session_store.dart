import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cosmos_session.dart';
import 'secure_storage.dart';

const String kCosmosSessionStorageKey = 'cosmos_session_v1';

/// Keeps the Cosmos route session next to the Firefly credentials.
///
/// Same store, same keychain item, cleared by the same disconnect. The cookie
/// gets a request past a reverse proxy that stands in front of the ledger, so
/// it is worth no less protection than the token behind it.
class CosmosSessionStore {
  CosmosSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? appSecureStorage;

  final FlutterSecureStorage _storage;

  Future<CosmosSession?> load() async {
    final raw = await _storage.read(key: kCosmosSessionStorageKey);
    if (raw == null || raw.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    return CosmosSession.fromJson(decoded.cast<String, Object?>());
  }

  Future<void> save(CosmosSession session) => _storage.write(
    key: kCosmosSessionStorageKey,
    value: jsonEncode(session.toJson()),
  );

  Future<void> clear() => _storage.delete(key: kCosmosSessionStorageKey);
}
