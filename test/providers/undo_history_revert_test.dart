import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/providers/undo_history_provider.dart';
import 'package:fireraccoon/widgets/transaction_entity_card.dart'
    show transactionUndoPayload;
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_firefly_service.dart';

/// A history that keeps nothing between containers, which is all these need:
/// the file store writes to the real filesystem.
class _MemoryStore implements UndoHistoryStore {
  String? _raw;

  @override
  Future<String?> read() async => _raw;

  @override
  Future<void> write(String contents) async => _raw = contents;
}

Future<ProviderContainer> _container(FireflyService api) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      apiServiceProvider.overrideWithValue(api),
      sharedPreferencesProvider.overrideWithValue(prefs),
      undoHistoryStoreProvider.overrideWithValue(_MemoryStore()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Transaction _transaction() => Transaction(
  id: '4711',
  type: 'withdrawal',
  date: DateTime(2026, 9, 1),
  amount: 120,
  description: 'Hotel',
  sourceName: 'Checking',
  destinationName: 'Trip.com',
  categoryName: 'Holiday > Housing',
  currencySymbol: 'kr',
  currencyCode: 'SEK',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reverting a deletion points the entry at the row that now exists',
    () async {
      final api = FakeFireflyService(transactions: [_transaction()]);
      final container = await _container(api);

      final notifier = container.read(undoHistoryProvider.notifier);
      notifier.record(
        title: 'Transaction deleted',
        details: 'Deleted transaction "Hotel"',
        type: UndoActionType.transactionDelete,
        // No transactionId on the undo side: undoing a deletion writes the row
        // again rather than deleting it twice.
        undoPayload: transactionUndoPayload(_transaction()),
        redoPayload: const {'transactionId': '4711'},
      );
      final deleted = container.read(undoHistoryProvider).entries.single.id;
      notifier.record(
        title: 'Theme changed',
        details: 'Switched to light',
        type: UndoActionType.themeMode,
        undoPayload: const {'mode': 'dark'},
        redoPayload: const {'mode': 'light'},
      );

      await notifier.revert(deleted);

      // Recreating gives the row a new id, so the entry has to follow it or the
      // next thing done to that entry reaches for a row that is gone.
      final entries = container.read(undoHistoryProvider).entries;
      final rewritten = entries.firstWhere((entry) => entry.id == deleted);
      expect(rewritten.undoPayload['id'], 'new-2');
      expect(entries.last.details, 'Reverted: Deleted transaction "Hotel"');
      // Undoing the revert deletes the row that now exists, not the id the
      // row had before it was written again.
      expect(entries.last.undoPayload['transactionId'], 'new-2');
    },
  );

  test('reverting something that is not there does nothing', () async {
    final container = await _container(FakeFireflyService());

    final notifier = container.read(undoHistoryProvider.notifier);
    notifier.record(
      title: 'Theme changed',
      details: 'Switched to light',
      type: UndoActionType.themeMode,
      undoPayload: const {'mode': 'dark'},
      redoPayload: const {'mode': 'light'},
    );

    await notifier.revert('an id nothing here carries');

    expect(container.read(undoHistoryProvider).entries, hasLength(1));
  });
}
