import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../deployment/deployment_providers.dart';
import '../models/people_models.dart';
import '../store/agent_key_store.dart';
import '../store/remote_server_client.dart';
import 'people_providers.dart';
import 'server_session_provider.dart';

/// Owner recorded for keys issued before People exist, when the app grants
/// everyone full access. Once People are set up this owner is no longer in the
/// list, so the key stops resolving; the record is kept rather than deleted,
/// because refusing it is enough and deleting it cannot be undone.
const String kLocalAgentKeyOwnerId = 'local-device';

const String _kLocalOwnerName = 'This device';

/// One agent key as Settings shows it. Never carries the digest or the secret.
class AgentKeyView {
  const AgentKeyView({
    required this.id,
    required this.personId,
    required this.label,
    required this.displayPrefix,
    required this.createdAt,
    this.lastUsedAt,
    this.revokedAt,
    this.hasSecret = false,
  });

  factory AgentKeyView.of(AgentKey key) => AgentKeyView(
    id: key.id,
    personId: key.personId,
    label: key.label,
    displayPrefix: key.displayPrefix,
    createdAt: key.createdAt,
    lastUsedAt: key.lastUsedAt,
    revokedAt: key.revokedAt,
    hasSecret: key.secret != null,
  );

  static AgentKeyView? fromPublicJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (id == null || createdAt == null) return null;
    return AgentKeyView(
      id: id,
      personId: json['personId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      displayPrefix: json['displayPrefix'] as String? ?? '',
      createdAt: createdAt,
      lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? ''),
      revokedAt: DateTime.tryParse(json['revokedAt'] as String? ?? ''),
      // A listing never carries secrets, so ownership is what decides whether a
      // reveal is worth offering; the server has the final say.
      hasSecret: json['hasSecret'] as bool? ?? true,
    );
  }

  final String id;
  final String personId;
  final String label;
  final String displayPrefix;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final DateTime? revokedAt;

  /// False for keys issued before secrets were retained, which can only be
  /// replaced rather than read.
  final bool hasSecret;

  bool get isActive => revokedAt == null;
}

class AgentKeysNotifier extends AsyncNotifier<List<AgentKeyView>> {
  AgentKeysNotifier({AgentKeyStore? store}) : _store = store ?? AgentKeyStore();

  final AgentKeyStore _store;
  static final _log = AppLogger.scoped('providers.agentKeys');

  /// Full local records, for [McpService]. Empty in server mode, where the
  /// backend holds the digests and the app never sees them.
  List<AgentKey> get localRecords => List.unmodifiable(_records);

  var _records = <AgentKey>[];

  @override
  Future<List<AgentKeyView>> build() async {
    if (ref.watch(deploymentConfigProvider).isServer) {
      _records = const [];
      return _loadRemote();
    }
    // Rebuild when a person is removed so their keys stop being offered.
    final peopleState = ref.watch(peopleProvider);
    _records = await _store.load();
    // Never prune against a people list that has not loaded yet, and never
    // against an empty one. People hydrate asynchronously and this provider
    // builds first, so pruning in that window deletes every key bound to a real
    // person; and an app instance that simply has no data yet reports zero
    // people as a settled state, which looks identical. Pruning buys nothing
    // either way, since resolveAgentKey already refuses a key whose person is
    // gone. Deleting the key is the only irreversible half of that pair.
    if (peopleState.isHydrated && peopleState.people.isNotEmpty) {
      _records = await _pruneOrphans(_records, peopleState.people);
    }
    return _localViews();
  }

  Future<List<AgentKeyView>> _loadRemote() async {
    final client = ref.read(serverSessionProvider.notifier).client;
    if (client == null) return const [];
    final raw = await client.fetchAgentKeys();
    return _ordered([
      for (final json in raw) ?AgentKeyView.fromPublicJson(json),
    ]);
  }

  /// Active keys first, revoked ones last, creation order kept within each.
  ///
  /// A revoked key is history: useful to see, but it should never sit between
  /// two keys someone is actually using.
  List<AgentKeyView> _ordered(List<AgentKeyView> views) {
    return [
      for (final view in views)
        if (view.isActive) view,
      for (final view in views)
        if (!view.isActive) view,
    ];
  }

  List<AgentKeyView> _localViews() =>
      _ordered([for (final key in _records) AgentKeyView.of(key)]);

  /// Issues a key for the signed-in person and returns its secret, which stays
  /// readable afterwards through [revealSecret].
  Future<String> issue(String label) async {
    if (label.trim().isEmpty) {
      throw ArgumentError('label is required');
    }
    if (ref.read(deploymentConfigProvider).isServer) {
      final client = ref.read(serverSessionProvider.notifier).client;
      if (client == null) throw StateError('Server client not ready');
      final body = await client.issueAgentKey(label: label.trim());
      state = AsyncData(await _loadRemote());
      return body['secret'] as String? ?? '';
    }

    final issued = issueAgentKey(
      personId: _localOwnerId(),
      label: label.trim(),
      id: _newKeyId(),
      now: DateTime.now().toUtc(),
    );
    _records = [..._records, issued.record];
    await _store.save(_records);
    _log.info('Issued MCP agent key ${issued.record.id}');
    state = AsyncData(_localViews());
    return issued.secret;
  }

  /// Records that [keyId] was used at [at].
  ///
  /// Local mode only: in server mode the backend stamps usage itself, since it
  /// is the side that sees the requests. The MCP isolate already throttles, and
  /// this re-checks so a restart with a stale snapshot cannot rewind the stamp.
  Future<void> recordUsage(String keyId, DateTime at) async {
    if (ref.read(deploymentConfigProvider).isServer) return;
    final index = _records.indexWhere((key) => key.id == keyId);
    if (index < 0) return;
    final stamp = at.toUtc();
    if (!shouldRecordAgentKeyUse(_records[index].lastUsedAt, stamp)) return;

    _records = [..._records]
      ..[index] = _records[index].copyWith(lastUsedAt: stamp);
    await _store.save(_records);
    state = AsyncData(_localViews());
  }

  /// Reads back the secret of [keyId], or null when it cannot be revealed.
  ///
  /// Local mode reads its own store; server mode asks the backend, which
  /// enforces owner-only access.
  Future<String?> revealSecret(String keyId) async {
    if (ref.read(deploymentConfigProvider).isServer) {
      final client = ref.read(serverSessionProvider.notifier).client;
      if (client == null) throw StateError('Server client not ready');
      try {
        final secret = await client.fetchAgentKeySecret(keyId);
        return secret.isEmpty ? null : secret;
      } on RemoteServerException catch (error) {
        if (error.statusCode == 404) return null;
        rethrow;
      }
    }
    for (final key in _records) {
      if (key.id == keyId) return key.secret;
    }
    return null;
  }

  /// Revokes [keyId]. Kept rather than deleted so Settings can still show that
  /// the key existed and when it stopped working.
  Future<void> revoke(String keyId) async {
    if (ref.read(deploymentConfigProvider).isServer) {
      final client = ref.read(serverSessionProvider.notifier).client;
      if (client == null) throw StateError('Server client not ready');
      await client.revokeAgentKey(keyId);
      state = AsyncData(await _loadRemote());
      return;
    }

    final now = DateTime.now().toUtc();
    _records = [
      for (final key in _records)
        if (key.id == keyId && key.isActive)
          key.copyWith(revokedAt: now)
        else
          key,
    ];
    await _store.save(_records);
    _log.info('Revoked MCP agent key $keyId');
    state = AsyncData(_localViews());
  }

  /// Drops a revoked key's record entirely, so it stops cluttering the list.
  ///
  /// Revoked only: forgetting a live key would silently revoke it too, and those
  /// are different intentions worth two separate clicks.
  Future<void> forget(String keyId) async {
    if (ref.read(deploymentConfigProvider).isServer) {
      final client = ref.read(serverSessionProvider.notifier).client;
      if (client == null) throw StateError('Server client not ready');
      await client.forgetAgentKey(keyId);
      state = AsyncData(await _loadRemote());
      return;
    }

    final match = _records.where((key) => key.id == keyId).firstOrNull;
    if (match == null) return;
    if (match.isActive) {
      throw StateError('Revoke the key before forgetting it');
    }
    _records = [
      for (final key in _records)
        if (key.id != keyId) key,
    ];
    await _store.save(_records);
    _log.info('Forgot MCP agent key $keyId');
    state = AsyncData(_localViews());
  }

  String _localOwnerId() {
    final people = ref.read(peopleProvider);
    return people.currentPerson?.id ??
        (people.isEnabled
            ? throw StateError('Sign in to issue an agent key')
            : kLocalAgentKeyOwnerId);
  }

  Future<List<AgentKey>> _pruneOrphans(
    List<AgentKey> keys,
    List<Person> people,
  ) async {
    final owners = {
      for (final person in people) person.id,
      // A key issued before People was turned on belongs to the device, not to
      // anyone in the list. Adding the first person must not delete it.
      kLocalAgentKeyOwnerId,
    };
    final kept = [
      for (final key in keys)
        if (owners.contains(key.personId)) key,
    ];
    if (kept.length != keys.length) {
      _log.info(
        'Pruned ${keys.length - kept.length} orphaned MCP agent key(s)',
      );
      await _store.save(kept);
    }
    return kept;
  }

  String _newKeyId() {
    // Key ids only need to be unique within this store; the secret carries the
    // entropy that matters.
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'key_${micros.toRadixString(36)}';
  }
}

final agentKeysProvider =
    AsyncNotifierProvider<AgentKeysNotifier, List<AgentKeyView>>(
      AgentKeysNotifier.new,
    );

/// People an agent key may resolve to, as the MCP isolate needs them.
final agentKeyPeopleProvider = Provider<List<AgentKeyPerson>>((ref) {
  final people = ref.watch(peopleProvider).people;
  if (people.isEmpty) {
    // No People configured: the app grants full access, so the implicit owner
    // is an admin.
    return const [
      AgentKeyPerson(
        id: kLocalAgentKeyOwnerId,
        name: _kLocalOwnerName,
        role: 'admin',
      ),
    ];
  }
  return [
    for (final person in people)
      AgentKeyPerson(id: person.id, name: person.name, role: person.role.name),
  ];
});
