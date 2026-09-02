import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/firefly_csv_dataset.dart';
import '../utils/date_range.dart';
import 'backup_crypto.dart';
import 'data_export_service.dart';
import 'firefly_csv_export_service.dart';
import 'firefly_service.dart';

/// Schema version of a backup, separate from the snapshot's own.
///
/// 2 records a digest per file, so a check can tell a file that changed from
/// one that only changed size. Backups written at 1 have no digests and are
/// checked on what they do carry.
const int kBackupSchemaVersion = 2;

/// Share of a backup's wall clock the snapshot takes, for turning two phases
/// into one number.
///
/// Measured against a 19,420-transaction ledger on Firefly 6.6.6: 78 seconds
/// reading entities and pages, then 85 seconds exporting CSV. Both halves grow
/// with the same ledger, so the near-even split travels better than either
/// half's internals do.
const double kSnapshotShareOfBackup = 0.48;

/// How far a backup has got.
class BackupProgress {
  const BackupProgress({required this.stage, this.fraction});

  /// What is being read: an entity name, `csv:<data set>`, or `manifest`.
  final String stage;

  /// 0..1, or null while the work is not yet countable.
  ///
  /// A page walk cannot say how many pages there are until the first one comes
  /// back. Null says so rather than inventing a denominator that would make the
  /// bar jump backwards when the real one arrives.
  final double? fraction;
}

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
    this.sha256,
  });

  factory BackupEntry.fromJson(Map<String, Object?> json) => BackupEntry(
    name: json['name'] as String? ?? '',
    bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    rows: (json['rows'] as num?)?.toInt(),
    error: json['error'] as String?,
    sha256: json['sha256'] as String?,
  );

  /// Path inside the backup, e.g. `snapshot.json` or `csv/rules.csv`.
  final String name;
  final int bytes;

  /// Rows below the CSV header, null for anything that is not a CSV.
  final int? rows;

  /// Why this part is missing, null when it is not.
  final String? error;

  /// Digest of the bytes as stored, absent on backups written before schema 2.
  ///
  /// Over the stored bytes rather than the plaintext, so a sealed backup can be
  /// checked without its password.
  final String? sha256;

  bool get ok => error == null;

  Map<String, Object?> toJson() => {
    'name': name,
    'bytes': bytes,
    if (rows != null) 'rows': rows,
    if (error != null) 'error': error,
    if (sha256 != null) 'sha256': sha256,
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
    this.seal,
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
      seal: json['encryption'] == null
          ? null
          : BackupSeal.fromJson(
              (json['encryption']! as Map).cast<String, Object?>(),
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

  /// How the payload was sealed, null when it was written in the clear.
  ///
  /// The manifest itself is never sealed: a list of backups has to be readable
  /// to be a list, and this holds counts and a moment rather than the ledger.
  final BackupSeal? seal;
  final int schemaVersion;

  bool get encrypted => seal != null;

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
    'encrypted': encrypted,
    if (seal != null) 'encryption': seal!.toJson(),
    'total_bytes': totalBytes,
    'covers': covers,
    'excludes': excludes,
    'entries': [for (final entry in entries) entry.toJson()],
  };
}

/// What a check of a backup's own files found.
class BackupIntegrity {
  const BackupIntegrity({
    required this.problems,
    this.readableFiles = 0,
    this.manifest,
  });

  /// Everything wrong with it, one line each. Empty means intact.
  final List<String> problems;
  final int readableFiles;
  final BackupManifest? manifest;

  bool get intact => problems.isEmpty;

  Map<String, Object?> toJson() => {
    'intact': intact,
    'readable_files': readableFiles,
    'problems': problems,
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
  /// [onProgress] reports what is being read and how far along it is, for a
  /// caller that has to show a ledger this size is moving rather than stuck.
  /// [password] seals the payload as it is written. The manifest stays in the
  /// clear so a list of backups is still a list; everything carrying ledger
  /// data is sealed.
  Future<BackupManifest> create({
    DateTime? takenAt,
    String? password,
    void Function(BackupProgress progress)? onProgress,
  }) async {
    final at = takenAt ?? DateTime.now();
    final id = await _freeId(backupIdFor(at));
    final seal = (password == null || password.isEmpty)
        ? null
        : BackupSeal.create();
    final cipher = seal == null
        ? null
        : await BackupCipher.derive(password!, seal);
    void report(String stage, double? fraction) =>
        onProgress?.call(BackupProgress(stage: stage, fraction: fraction));

    report('owner', 0);
    final owner = await _api.getCurrentUser();

    // The ledger's own bounds, not the service default: a backup that quietly
    // covered the last year would be discovered at restore time.
    final snapshot = await DataExportService(_api).export(
      from: kFireflyLedgerStart,
      to: kFireflyLedgerEnd,
      takenAt: at,
      onProgress: (stage, fraction) => report(
        stage,
        fraction == null ? null : fraction * kSnapshotShareOfBackup,
      ),
    );
    final entries = <BackupEntry>[];
    entries.add(
      await _write(
        id,
        kBackupSnapshotFile,
        jsonEncode(snapshot.toJson()),
        cipher: cipher,
      ),
    );

    final window = _transactionWindow(snapshot, at);
    // Eight exports of one request each, plus a year at a time for the
    // transactions, which is what the second half of the time goes on.
    final chunks = window.to.year - window.from.year + 1;
    final exportUnits = 8 + chunks;
    var exportsDone = 0;
    final files = await FireflyCsvExportService(_api).exportAll(
      from: window.from,
      to: window.to,
      onDataset: (dataset) => report(
        'csv:${dataset.apiValue}',
        kSnapshotShareOfBackup +
            (1 - kSnapshotShareOfBackup) * (exportsDone / exportUnits),
      ),
      onChunk: () => exportsDone++,
    );
    for (final file in files) {
      final name = '$kBackupCsvDirectory/${file.dataset.fileName}';
      entries.add(
        file.ok
            ? await _write(
                id,
                name,
                file.contents,
                rows: file.rowCount,
                cipher: cipher,
              )
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
      seal: seal,
    );
    report('manifest', 1);
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
  ///
  /// Throws [BackupPasswordException] when the backup is sealed and the
  /// password is missing or wrong, rather than answering null: "there is no
  /// snapshot" and "you gave the wrong password" are different problems and a
  /// caller has to tell them apart.
  Future<Map<String, Object?>?> snapshot(
    String backupId, {
    String? password,
  }) async {
    final contents = await file(
      backupId,
      kBackupSnapshotFile,
      password: password,
    );
    if (contents == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException {
      return null;
    }
    return decoded is Map ? decoded.cast<String, Object?>() : null;
  }

  Future<String?> file(
    String backupId,
    String fileName, {
    String? password,
  }) async {
    final bytes = await _store.get(backupId, fileName);
    if (bytes == null) return null;
    if (!isSealedBackupFile(bytes)) return utf8.decode(bytes);
    final manifest = await read(backupId);
    final seal = manifest?.seal;
    if (seal == null) {
      throw const BackupPasswordException(
        'This backup is sealed but its manifest does not say how, so nothing '
        'can open it.',
      );
    }
    if (password == null || password.isEmpty) {
      throw const BackupPasswordException('This backup is password protected.');
    }
    final cipher = await BackupCipher.derive(password, seal);
    return utf8.decode(await cipher.open(fileName, bytes));
  }

  Future<void> delete(String backupId) => _store.deleteBackup(backupId);

  /// Whether a backup is still the backup its manifest describes.
  ///
  /// Checks what is on disk against what was written: every part present, the
  /// sizes unchanged, and the payload opening with the password given. This says
  /// nothing about whether the ledger has moved on since; that is what a restore
  /// plan is for.
  Future<BackupIntegrity> check(String backupId, {String? password}) async {
    final manifest = await read(backupId);
    if (manifest == null) {
      return const BackupIntegrity(problems: ['No manifest to check against']);
    }
    final problems = <String>[];
    var readable = 0;
    for (final entry in manifest.entries) {
      if (!entry.ok) {
        problems.add('${entry.name} was never written: ${entry.error}');
        continue;
      }
      final bytes = await _store.get(backupId, entry.name);
      if (bytes == null) {
        problems.add('${entry.name} is missing');
        continue;
      }
      if (bytes.length != entry.bytes) {
        problems.add(
          '${entry.name} is ${bytes.length} bytes, '
          'the manifest says ${entry.bytes}',
        );
        continue;
      }
      final digest = entry.sha256;
      if (digest != null && sha256.convert(bytes).toString() != digest) {
        problems.add('${entry.name} has changed since it was written');
        continue;
      }
      if (!isSealedBackupFile(bytes)) {
        readable++;
        continue;
      }
      // Sealed: the only way to know it opens is to open it.
      try {
        await file(backupId, entry.name, password: password);
        readable++;
      } on BackupPasswordException catch (error) {
        problems.add('${entry.name} would not open: ${error.message}');
      }
    }
    return BackupIntegrity(
      problems: problems,
      readableFiles: readable,
      manifest: manifest,
    );
  }

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
    BackupCipher? cipher,
  }) async {
    final plain = utf8.encode(contents);
    final bytes = cipher == null ? plain : await cipher.seal(name, plain);
    await _store.put(id, name, bytes);
    // The stored size and digest, which is what a reader will find on disk,
    // not what it was before sealing.
    return BackupEntry(
      name: name,
      bytes: bytes.length,
      rows: rows,
      sha256: sha256.convert(bytes).toString(),
    );
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
