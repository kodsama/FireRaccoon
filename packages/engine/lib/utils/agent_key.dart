import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Tag on every issued MCP agent key. Makes a leaked secret recognizable in
/// logs and greppable in MCP client configs.
const String kAgentKeyTag = 'frcn_';

/// Characters of the random part kept in the clear for display, so a person can
/// tell two keys apart in Settings without the secret being recoverable.
const int kAgentKeyDisplayLength = 6;

/// How stale a key's `lastUsedAt` must be before a fresh use is recorded.
///
/// The stamp answers "is this key still in use", not "trace every call", so a
/// chatty agent must not force a store write per request.
const Duration kAgentKeyUsageInterval = Duration(minutes: 1);

const int _kSecretBytes = 32;

/// A person an agent key can be bound to, reduced to the fields key resolution
/// needs. Keeps this file independent of the Flutter `Person` model.
class AgentKeyPerson {
  const AgentKeyPerson({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;

  /// `admin`, `user`, or `viewer`.
  final String role;
}

/// What an authenticated MCP agent may do, resolved from the person its key is
/// bound to. Keys carry no scopes of their own: revoking access to a person
/// revokes it for every agent acting as them.
class AgentIdentity {
  const AgentIdentity({
    required this.keyId,
    required this.personId,
    required this.personName,
    required this.role,
  });

  final String keyId;
  final String personId;
  final String personName;

  /// Role name kept as a string so the pure-Dart engine stays free of the
  /// app's `PersonRole` enum, which pulls in Flutter.
  final String role;

  /// Mirrors `canWriteFinancialData` in the app and `canWrite` in the backend.
  bool get canWrite => role == 'admin' || role == 'user';

  Map<String, Object?> toJson() => {
    'key_id': keyId,
    'person_id': personId,
    'person_name': personName,
    'role': role,
    'can_write': canWrite,
  };
}

/// A stored agent key.
///
/// The secret is kept so its owner can read it back rather than reissue a key
/// they mislaid. That is safe here and only here: the store already holds the
/// Firefly PAT, which grants strictly more than any agent key, so an attacker
/// who can read one can already read the other. Do not copy this shape to a
/// store that does not already contain a more powerful secret.
///
/// [hash] stays the thing authentication compares against, so a record whose
/// secret was dropped by an older version still works.
class AgentKey {
  const AgentKey({
    required this.id,
    required this.personId,
    required this.label,
    required this.hash,
    required this.displayPrefix,
    required this.createdAt,
    this.secret,
    this.lastUsedAt,
    this.revokedAt,
  });

  final String id;
  final String personId;
  final String label;
  final String hash;
  final String displayPrefix;
  final DateTime createdAt;

  /// Readable only by this key's owner, and never included in a listing or a
  /// settings backup. Null for keys issued before secrets were retained.
  final String? secret;

  final DateTime? lastUsedAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  AgentKey copyWith({DateTime? lastUsedAt, DateTime? revokedAt}) {
    return AgentKey(
      id: id,
      personId: personId,
      label: label,
      hash: hash,
      displayPrefix: displayPrefix,
      createdAt: createdAt,
      secret: secret,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }

  /// Full record for the app's secure storage or the server's sealed store.
  /// Never for a response body or a backup: use [toPublicJson].
  Map<String, Object?> toJson() => {
    'id': id,
    'personId': personId,
    'label': label,
    'hash': hash,
    'displayPrefix': displayPrefix,
    'createdAt': createdAt.toIso8601String(),
    if (secret != null) 'secret': secret,
    if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.toIso8601String(),
    if (revokedAt != null) 'revokedAt': revokedAt!.toIso8601String(),
  };

  /// Public shape for listings: everything except [hash] and [secret]. Reading
  /// a secret is a separate, owner-only step by design, so one listing cannot
  /// spray every credential at once.
  Map<String, Object?> toPublicJson() => {
    'id': id,
    'personId': personId,
    'label': label,
    'displayPrefix': displayPrefix,
    'createdAt': createdAt.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
    'revokedAt': revokedAt?.toIso8601String(),
    'active': isActive,
  };

  static AgentKey? fromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final personId = json['personId'] as String?;
    final hash = json['hash'] as String?;
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (id == null || personId == null || hash == null || createdAt == null) {
      return null;
    }
    final secret = json['secret'] as String?;
    return AgentKey(
      id: id,
      personId: personId,
      label: json['label'] as String? ?? '',
      hash: hash,
      displayPrefix: json['displayPrefix'] as String? ?? '',
      createdAt: createdAt,
      secret: (secret != null && secret.isNotEmpty) ? secret : null,
      lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? ''),
      revokedAt: DateTime.tryParse(json['revokedAt'] as String? ?? ''),
    );
  }
}

/// A freshly issued key. [secret] is shown to the person once and then dropped;
/// [record] is what the caller persists.
class IssuedAgentKey {
  const IssuedAgentKey({required this.secret, required this.record});

  final String secret;
  final AgentKey record;
}

/// Digests an agent key secret for storage and comparison.
///
/// A plain SHA-256 rather than PBKDF2: the secret is 256 bits of CSPRNG output,
/// so there is no dictionary to slow down, and MCP `initialize` would otherwise
/// pay six figures of iterations on every new connection.
String hashAgentKey(String secret) =>
    sha256.convert(utf8.encode(secret.trim())).toString();

/// Mints a key bound to [personId]. Callers supply [now] so the record's
/// timestamps stay testable.
IssuedAgentKey issueAgentKey({
  required String personId,
  required String label,
  required String id,
  required DateTime now,
  Random? random,
}) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(_kSecretBytes, (_) => rng.nextInt(256));
  final body = base64UrlEncode(bytes).replaceAll('=', '');
  final secret = '$kAgentKeyTag$body';
  return IssuedAgentKey(
    secret: secret,
    record: AgentKey(
      id: id,
      personId: personId,
      label: label.trim(),
      hash: hashAgentKey(secret),
      displayPrefix: body.substring(0, kAgentKeyDisplayLength),
      createdAt: now,
      secret: secret,
    ),
  );
}

/// Whether a use at [at] is worth writing over a key's existing [lastUsedAt].
///
/// Both the desktop app and the server throttle through here so the two modes
/// agree on how precise a usage stamp is. A stamp that would move backwards is
/// refused: clock skew must not make a key look less recently used.
bool shouldRecordAgentKeyUse(DateTime? lastUsedAt, DateTime at) {
  if (lastUsedAt == null) return true;
  return at.difference(lastUsedAt) >= kAgentKeyUsageInterval;
}

/// Resolves [secret] to the identity it grants, or null when the key is
/// malformed, unknown, revoked, or bound to a person who no longer exists.
AgentIdentity? resolveAgentKey(
  String? secret, {
  required Iterable<AgentKey> keys,
  required AgentKeyPerson? Function(String personId) person,
}) {
  if (secret == null) return null;
  final trimmed = secret.trim();
  if (!trimmed.startsWith(kAgentKeyTag)) return null;
  final candidate = hashAgentKey(trimmed);

  AgentKey? match;
  // Every active key is compared even after a hit, so resolution time does not
  // reveal the matched key's position in the store.
  for (final key in keys) {
    if (key.isActive && _constantTimeEquals(key.hash, candidate)) {
      match ??= key;
    }
  }
  if (match == null) return null;

  final owner = person(match.personId);
  if (owner == null) return null;
  return AgentIdentity(
    keyId: match.id,
    personId: owner.id,
    personName: owner.name,
    role: owner.role,
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
