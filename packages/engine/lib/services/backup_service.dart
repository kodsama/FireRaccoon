import 'dart:convert';

import '../models/firefly_csv_dataset.dart';
import '../utils/date_range.dart';
import 'data_export_service.dart';
import 'firefly_csv_export_service.dart';
import 'firefly_service.dart';

/// Schema version of a backup, separate from the snapshot's own.
const int kBackupSchemaVersion = 1;

const String kBackupManifestFile = 'manifest.json';
const String kBackupSnapshotFile = 'snapshot.json';
const String kBackupCsvDirectory = 'csv';

/// Names a backup by the moment it was taken, in the zone it was taken in.
///
/// `20260901T222736+0200`. The offset is part of the name rather than a field
/// only the manifest carries: a backup taken at 00:30+02:00 and one taken at
/// 23:30+01:00 are half an hour apart, and a name without the offset sorts them
/// a day apart. Written without the separators a file name cannot hold.
String backupIdFor(DateTime takenAt) {
  final at = takenAt.isUtc ? takenAt.toUtc() : takenAt;
  final offset = at.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${at.year.toString().padLeft(4, '0')}${two(at.month)}${two(at.day)}'
      'T${two(at.hour)}${two(at.minute)}${two(at.second)}'
      '$sign${two(minutes ~/ 60)}${two(minutes % 60)}';
}

/// RFC 3339 with the offset kept, which is what makes a stamp readable a year
/// later from another machine in another zone.
String backupTimestampFor(DateTime takenAt) {
  final at = takenAt.isUtc ? takenAt.toUtc() : takenAt;
  final offset = at.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  String two(int value) => value.toString().padLeft(2, '0');
  final zone = at.isUtc
      ? 'Z'
      : '$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
  return '${at.year.toString().padLeft(4, '0')}-${two(at.month)}-'
      '${two(at.day)}T${two(at.hour)}:${two(at.minute)}:${two(at.second)}$zone';
}

/// One file inside a backup, or the data set that failed to become one.
class BackupEntry {
  const BackupEntry({
    required this.name,
    required this.bytes,
    this.rows,
    this.error,
  });

  factory BackupEntry.fromJson(Map<String, Object?> json) => BackupEntry(
    name: json['name'] as String? ?? '',
    bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    rows: (json['rows'] as num?)?.toInt(),
    error: json['error'] as String?,
  );

  /// Path inside the backup, e.g. `snapshot.json` or `csv/rules.csv`.
  final String name;
  final int bytes;

  /// Rows below the CSV header, null for anything that is not a CSV.
  final int? rows;

  /// Why this part is missing, null when it is not.
  final String? error;

  bool get ok => error == null;

  Map<String, Object?> toJson() => {
    'name': name,
    'bytes': bytes,
    if (rows != null) 'rows': rows,
    if (error != null) 'error': error,
  };
}

/// What a backup holds, when it was taken, and whose ledger it came from.
class BackupManifest {
  const BackupManifest({
    required this.id,
    required this.takenAt,
    required this.timeZoneName,
    required this.timeZoneOffset,
    required this.counts,
    required this.entries,
    required this.covers,
    required this.excludes,
    this.ownerId,
    this.ownerEmail,
    this.transactionsFrom,
    this.transactionsTo,
    this.schemaVersion = kBackupSchemaVersion,
  });

  factory BackupManifest.fromJson(Map<String, Object?> json) {
    final zone =
        (json['timezone'] as Map?)?.cast<String, Object?>() ?? const {};
    final owner = (json['owner'] as Map?)?.cast<String, Object?>() ?? const {};
    return BackupManifest(
      id: json['id'] as String? ?? '',
      takenAt:
          DateTime.tryParse(json['taken_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      timeZoneName: zone['name'] as String? ?? '',
      timeZoneOffset: Duration(
        minutes: (zone['offset_minutes'] as num?)?.toInt() ?? 0,
      ),
      counts: {
        for (final entry
            in ((json['counts'] as Map?) ?? const {}).entries.where(
              (e) => e.value is num,
            ))
          '${entry.key}': (entry.value as num).toInt(),
      },
      entries: [
        for (final entry in (json['entries'] as List? ?? const []))
          if (entry is Map) BackupEntry.fromJson(entry.cast<String, Object?>()),
      ],
      covers: [
        for (final name in (json['covers'] as List? ?? const [])) '$name',
      ],
      excludes: [
        for (final name in (json['excludes'] as List? ?? const [])) '$name',
      ],
      ownerId: owner['id'] as String?,
      ownerEmail: owner['email'] as String?,
      transactionsFrom: DateTime.tryParse(
        json['transactions_from'] as String? ?? '',
      ),
      transactionsTo: DateTime.tryParse(
        json['transactions_to'] as String? ?? '',
      ),
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;

  /// The moment the backup started, in the zone it was taken in.
  final DateTime takenAt;

  /// Zone abbreviation as the machine reported it, e.g. `CEST`.
  final String timeZoneName;
  final Duration timeZoneOffset;

  /// Entity counts from the snapshot.
  final Map<String, int> counts;
  final List<BackupEntry> entries;
  final List<String> covers;
  final List<String> excludes;

  /// Firefly user the backup was read as. Restoring into a different one is the
  /// mistake worth catching, and an id is what catches it.
  final String? ownerId;
  final String? ownerEmail;

  final DateTime? transactionsFrom;
  final DateTime? transactionsTo;
  final int schemaVersion;

  /// True when every part was written, so a caller can tell a whole backup from
  /// one that lost a data set on the way.
  bool get complete => entries.every((entry) => entry.ok);

  int get totalBytes => entries.fold(0, (total, entry) => total + entry.bytes);

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'id': id,
    'taken_at': backupTimestampFor(takenAt),
    'timezone': {
      'name': timeZoneName,
      'offset_minutes': timeZoneOffset.inMinutes,
    },
    'owner': {'id': ownerId, 'email': ownerEmail},
    'counts': counts,
    'transactions_from': transactionsFrom?.toIso8601String(),
    'transactions_to': transactionsTo?.toIso8601String(),
    'complete': complete,
    'total_bytes': totalBytes,
    'covers': covers,
    'excludes': excludes,
    'entries': [for (final entry in entries) entry.toJson()],
  };
}

/// Where backups are kept.
///
/// Deliberately files rather than one blob: the parts are read back one at a
/// time, and a restore only ever needs the snapshot.
abstract class BackupStore {
  Future<void> put(String backupId, String fileName, List<int> bytes);
  Future<List<int>?> get(String backupId, String fileName);

  /// Backup ids the store holds, newest first.
  Future<List<String>> listBackupIds();
  Future<void> deleteBackup(String backupId);
}

/// Takes and reads back Firefly backups.
///
/// A backup is two halves. The snapshot is FireRaccoon's own JSON, versioned and
/// restorable through the API. The CSVs are Firefly's own export, which is where
/// rules and budget limits live and which nothing can restore automatically.
/// Neither half reaches the database, the attachments or the instance key, so a
/// destroyed Firefly still needs the volume archive `tool/firefly_backup.sh`
/// takes; what this covers is data lost to a change someone made.
class BackupService {
  BackupService(this._api, this._store);

  final FireflyService _api;
  final BackupStore _store;

  /// Reads the whole ledger and writes it into the store.
  ///
  /// [onStage] reports what is being read, for a caller that wants to say so
  /// while a large ledger walks past.
  Future<BackupManifest> create({
    DateTime? takenAt,
    void Function(String stage)? onStage,
  }) async {
    final at = takenAt ?? DateTime.now();
    final id = await _freeId(backupIdFor(at));

    onStage?.call('owner');
    final owner = await _api.getCurrentUser();

    onStage?.call('snapshot');
    // The ledger's own bounds, not the service default: a backup that quietly
    // covered the last year would be discovered at restore time.
    final snapshot = await DataExportService(
      _api,
    ).export(from: kFireflyLedgerStart, to: kFireflyLedgerEnd, takenAt: at);
    final entries = <BackupEntry>[];
    entries.add(
      await _write(id, kBackupSnapshotFile, jsonEncode(snapshot.toJson())),
    );

    final window = _transactionWindow(snapshot, at);
    final files = await FireflyCsvExportService(_api).exportAll(
      from: window.from,
      to: window.to,
      onDataset: (dataset) => onStage?.call('csv:${dataset.apiValue}'),
    );
    for (final file in files) {
      final name = '$kBackupCsvDirectory/${file.dataset.fileName}';
      entries.add(
        file.ok
            ? await _write(id, name, file.contents, rows: file.rowCount)
            : BackupEntry(name: name, bytes: 0, error: file.error),
      );
    }

    final manifest = BackupManifest(
      id: id,
      takenAt: at,
      timeZoneName: at.timeZoneName,
      timeZoneOffset: at.timeZoneOffset,
      counts: snapshot.counts,
      entries: entries,
      covers: [
        kBackupSnapshotFile,
        for (final dataset in FireflyCsvDataset.values)
          '$kBackupCsvDirectory/${dataset.fileName}',
      ],
      // Named rather than implied: what a backup cannot reach is the part
      // people discover at restore time, when it is too late to arrange.
      excludes: const ['database', 'app_key', 'attachments', 'webhooks'],
      ownerId: owner.id,
      ownerEmail: owner.email,
      transactionsFrom: window.from,
      transactionsTo: window.to,
    );
    await _store.put(
      id,
      kBackupManifestFile,
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
      ),
    );
    return manifest;
  }

  /// Every backup the store holds, newest first, skipping any whose manifest
  /// cannot be read: one unreadable backup is not a reason to answer nothing.
  ///
  /// Ordered by the moment each was taken rather than by name. Two ids sort by
  /// local time, so a backup taken at 00:30+02:00 would otherwise come out ahead
  /// of one taken half an hour earlier at 23:30+01:00.
  Future<List<BackupManifest>> list() async {
    final manifests = <BackupManifest>[];
    for (final id in await _store.listBackupIds()) {
      final manifest = await read(id);
      if (manifest != null) manifests.add(manifest);
    }
    manifests.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return manifests;
  }

  Future<BackupManifest?> read(String backupId) async {
    final bytes = await _store.get(backupId, kBackupManifestFile);
    if (bytes == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    return BackupManifest.fromJson(decoded.cast<String, Object?>());
  }

  /// The snapshot a restore reads, or null when the backup has no readable one.
  Future<Map<String, Object?>?> snapshot(String backupId) async {
    final bytes = await _store.get(backupId, kBackupSnapshotFile);
    if (bytes == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
    return decoded is Map ? decoded.cast<String, Object?>() : null;
  }

  Future<String?> file(String backupId, String fileName) async {
    final bytes = await _store.get(backupId, fileName);
    return bytes == null ? null : utf8.decode(bytes);
  }

  Future<void> delete(String backupId) => _store.deleteBackup(backupId);

  /// [base] unless the store already holds it, then the next free suffix.
  ///
  /// An id is a timestamp to the second, and a second is coarse enough for an
  /// agent taking a backup before each of a run of changes to land twice inside
  /// one. Without this the second backup would overwrite the first, which is the
  /// worst possible failure for the thing being relied on to put data back.
  Future<String> _freeId(String base) async {
    final taken = (await _store.listBackupIds()).toSet();
    if (!taken.contains(base)) return base;
    for (var suffix = 2; suffix <= 99; suffix++) {
      if (!taken.contains('$base-$suffix')) return '$base-$suffix';
    }
    throw StateError('99 backups already share the id $base');
  }

  Future<BackupEntry> _write(
    String id,
    String name,
    String contents, {
    int? rows,
  }) async {
    final bytes = utf8.encode(contents);
    await _store.put(id, name, bytes);
    return BackupEntry(name: name, bytes: bytes.length, rows: rows);
  }

  /// The window the CSV export walks, taken from what the snapshot found.
  ///
  /// Chunking a year at a time over Firefly's full 1970..2038 bounds would be
  /// sixty-eight requests for a ledger that starts in 2019. An empty ledger has
  /// no window to derive, so it gets the year the backup was taken in.
  ({DateTime from, DateTime to}) _transactionWindow(
    FireflyDataExport snapshot,
    DateTime takenAt,
  ) {
    if (snapshot.transactions.isEmpty) {
      final startOfYear = takenAt.isUtc
          ? DateTime.utc(takenAt.year)
          : DateTime(takenAt.year);
      return (from: startOfYear, to: takenAt);
    }
    var from = snapshot.transactions.first.date;
    var to = from;
    for (final transaction in snapshot.transactions) {
      for (final leg in transaction.resolvedSplits()) {
        if (leg.date.isBefore(from)) from = leg.date;
        if (leg.date.isAfter(to)) to = leg.date;
      }
    }
    return (from: from, to: to);
  }
}
