import 'dart:convert';

import 'package:fireraccoon/providers/backup_providers.dart';
import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/widgets/firefly_backup_section.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireraccoon/providers/theme_provider.dart';

import '../helpers/dialog_test_helpers.dart';
import '../helpers/localized_test_app.dart';
import '../helpers/mock_firefly_service.dart';

class _MemoryBackupStore implements BackupStore {
  final Map<String, Map<String, List<int>>> backups = {};

  @override
  Future<void> put(String backupId, String fileName, List<int> bytes) async {
    backups.putIfAbsent(backupId, () => {})[fileName] = bytes;
  }

  @override
  Future<List<int>?> get(String backupId, String fileName) async =>
      backups[backupId]?[fileName];

  @override
  Future<List<String>> listBackupIds() async =>
      backups.keys.toList()..sort((a, b) => b.compareTo(a));

  @override
  Future<void> deleteBackup(String backupId) async {
    backups.remove(backupId);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  BackupStore? store,
  FireflyService? api,
}) async {
  SharedPreferences.setMockInitialValues({'funMode': 'none'});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiServiceProvider.overrideWithValue(api ?? FakeFireflyService()),
        backupsDirectoryProvider.overrideWithValue(null),
        if (store != null) backupStoreProvider.overrideWithValue(store),
      ],
      child: buildLocalizedTestApp(
        child: const SingleChildScrollView(child: FireflyBackupSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Lets the toast a backup raises expire.
///
/// Its hide is a timer rather than a frame, so pumpAndSettle returns with it
/// still pending and the test fails on the leftover rather than on anything it
/// asserts.
Future<void> _letToastPass(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUp(AppLogger.configure);
  tearDown(AppLogger.resetForTest);

  testWidgets('says so where there is nowhere to keep a backup', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.textContaining('nowhere to keep a backup'), findsOneWidget);
    expect(find.text('Take a backup'), findsNothing);
  });

  testWidgets('offers to take one when there is somewhere to put it', (
    tester,
  ) async {
    await _pump(tester, store: _MemoryBackupStore());

    expect(find.text('Take a backup'), findsOneWidget);
    expect(find.text('No backups yet'), findsOneWidget);
  });

  testWidgets('taking one lists it with what it holds', (tester) async {
    final store = _MemoryBackupStore();
    await _pump(tester, store: store);

    await tester.tap(find.text('Take a backup'));
    await tester.pumpAndSettle();
    await _letToastPass(tester);

    expect(find.text('No backups yet'), findsNothing);
    expect(find.textContaining('0 transactions, 0 accounts'), findsOneWidget);
    expect(store.backups, hasLength(1));
  });

  testWidgets('a backup missing a part is marked as incomplete', (
    tester,
  ) async {
    final store = _MemoryBackupStore();
    await store.put(
      '20260101T000000+0000',
      kBackupManifestFile,
      utf8.encode(
        jsonEncode({
          'id': '20260101T000000+0000',
          'taken_at': '2026-01-01T12:00:00Z',
          'timezone': {'name': 'UTC', 'offset_minutes': 0},
          'counts': {'transactions': 3, 'accounts': 2},
          'entries': [
            {'name': 'snapshot.json', 'bytes': 2048},
            {'name': 'csv/rules.csv', 'bytes': 0, 'error': 'HTTP 500'},
          ],
        }),
      ),
    );

    await _pump(tester, store: store);

    expect(find.textContaining('Parts missing'), findsOneWidget);
    expect(find.textContaining('3 transactions, 2 accounts'), findsOneWidget);
    expect(find.textContaining('2 files, 2.0 kB'), findsOneWidget);
  });

  testWidgets('deleting asks first and then removes it', (tester) async {
    final store = _MemoryBackupStore();
    await _pump(tester, store: store);
    await tester.tap(find.text('Take a backup'));
    await tester.pumpAndSettle();
    await _letToastPass(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Delete this backup?'), findsOneWidget);
    await confirmDialogWithChallenge(tester);
    await _letToastPass(tester);

    expect(store.backups, isEmpty);
    expect(find.text('No backups yet'), findsOneWidget);
  });

  testWidgets('a failed read is reported rather than left blank', (
    tester,
  ) async {
    await _pump(
      tester,
      store: _MemoryBackupStore(),
      api: FakeFireflyService()..throwOn = Exception('Firefly is down'),
    );

    await tester.tap(find.text('Take a backup'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not take a backup'), findsOneWidget);
    await _letToastPass(tester);
  });

  testWidgets('restoring an unchanged ledger says there is nothing to do', (
    tester,
  ) async {
    final store = _MemoryBackupStore();
    await _pump(tester, store: store);
    await tester.tap(find.text('Take a backup'));
    await tester.pumpAndSettle();
    await _letToastPass(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('already matches'), findsOneWidget);
    await _letToastPass(tester);
  });

  testWidgets('a backup from another ledger is refused', (tester) async {
    final store = _MemoryBackupStore();
    await store.put(
      '20260101T000000+0000',
      kBackupManifestFile,
      utf8.encode(
        jsonEncode({
          'id': '20260101T000000+0000',
          'taken_at': '2026-01-01T12:00:00Z',
          'owner': {'id': '99', 'email': 'someone@else.test'},
          'entries': [
            {'name': 'snapshot.json', 'bytes': 2},
          ],
        }),
      ),
    );
    await store.put(
      '20260101T000000+0000',
      kBackupSnapshotFile,
      utf8.encode('{}'),
    );

    await _pump(tester, store: store);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('different Firefly user'), findsOneWidget);
    await _letToastPass(tester);
  });

  testWidgets('a restore shows what it would change before it writes', (
    tester,
  ) async {
    final store = _MemoryBackupStore();
    final api = FakeFireflyService();
    await _pump(tester, store: store, api: api);
    await tester.tap(find.text('Take a backup'));
    await tester.pumpAndSettle();
    await _letToastPass(tester);
    // The ledger loses a row after the backup was taken.
    final id = (await store.listBackupIds()).single;
    final snapshot =
        jsonDecode(utf8.decode((await store.get(id, kBackupSnapshotFile))!))
            as Map<String, Object?>;
    (snapshot['categories']! as List).add({'id': '7', 'name': 'Food'});
    await store.put(id, kBackupSnapshotFile, utf8.encode(jsonEncode(snapshot)));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('1 to put back'), findsOneWidget);
    expect(find.textContaining('new identifiers'), findsOneWidget);
    expect(api.createdCategories, isEmpty);

    await confirmDialogWithChallenge(tester);
    await tester.pumpAndSettle();

    expect(api.createdCategories, ['Food']);
    expect(find.textContaining('Restored 1 rows'), findsOneWidget);
    await _letToastPass(tester);
  });

  testWidgets('refreshing picks up a backup taken elsewhere', (tester) async {
    final store = _MemoryBackupStore();
    await _pump(tester, store: store);
    expect(find.text('No backups yet'), findsOneWidget);

    // What an agent taking one over MCP leaves behind: the same store, written
    // to by another process, with nothing to tell this screen about it.
    await store.put(
      '20260101T000000+0000',
      kBackupManifestFile,
      utf8.encode(
        jsonEncode({
          'id': '20260101T000000+0000',
          'taken_at': '2026-01-01T12:00:00Z',
          'timezone': {'name': 'UTC', 'offset_minutes': 0},
          'counts': {'transactions': 4, 'accounts': 1},
          'entries': [
            {'name': 'snapshot.json', 'bytes': 1024},
          ],
        }),
      ),
    );

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(find.text('No backups yet'), findsNothing);
    expect(find.textContaining('4 transactions, 1 accounts'), findsOneWidget);
  });

  testWidgets('a running backup shows a bar, and stops showing one after', (
    tester,
  ) async {
    final api = FakeFireflyService()
      ..responseDelay = const Duration(milliseconds: 80);
    await _pump(tester, store: _MemoryBackupStore(), api: api);

    await tester.tap(find.text('Take a backup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('Reading'), findsOneWidget);

    await tester.pumpAndSettle();
    await _letToastPass(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('the label says what is running and how far along', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      buildLocalizedTestApp(
        child: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      backupActivityLabel(
        context,
        const BackupActivity(running: true, stage: 'transactions'),
      ),
      'Reading transactions…',
    );
    expect(
      backupActivityLabel(
        context,
        const BackupActivity(running: true, stage: 'csv:rules', fraction: 0.42),
      ),
      contains('42%'),
    );
    expect(
      backupActivityLabel(
        context,
        const BackupActivity(running: true, restoreStep: 3, restoreTotal: 12),
      ),
      'Restoring 3 of 12',
    );
  });
}
