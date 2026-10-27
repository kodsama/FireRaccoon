import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/providers/undo_history_provider.dart';
import 'package:fireraccoon/widgets/transaction_entity_card.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/localized_test_app.dart';
import '../helpers/mock_firefly_service.dart';

class _MemoryStore implements UndoHistoryStore {
  String? _raw;

  @override
  Future<String?> read() async => _raw;

  @override
  Future<void> write(String contents) async => _raw = contents;
}

final _reconciled = Transaction(
  id: '4711',
  journalId: '9001',
  type: 'withdrawal',
  date: DateTime(2026, 9, 1),
  amount: 120,
  description: 'Hotel',
  sourceName: 'Checking',
  destinationName: 'Payee A',
  categoryName: '',
  currencySymbol: 'kr',
  currencyCode: 'SEK',
  sourceId: '1',
  destinationId: 'A',
  reconciled: true,
);

Future<void> _save(
  WidgetTester tester,
  FakeFireflyService api,
  Transaction updated,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        sharedPreferencesProvider.overrideWithValue(prefs),
        undoHistoryStoreProvider.overrideWithValue(_MemoryStore()),
      ],
      child: buildLocalizedTestApp(
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () =>
                saveTransactionEntity(context, ref, null, _reconciled, updated),
            child: const Text('Save'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new payee on a reconciled row is stored and reconciled', (
    tester,
  ) async {
    final api = FakeFireflyService();
    await _save(
      tester,
      api,
      _reconciled.copyWith(
        description: 'Hotel, two nights',
        destinationName: 'Payee B',
        destinationId: 'B',
      ),
    );

    expect(api.updatedTransactions, hasLength(2));
    final change = api.updatedTransactions.first;
    final split = change.toApiPayload(isUpdate: true)['transactions'][0] as Map;
    expect(split['destination_id'], 'B');
    expect(change.reconciled, isFalse);
    expect(api.updatedTransactions.last.reconciled, isTrue);
  });

  testWidgets('a description edit on a reconciled row stays one write', (
    tester,
  ) async {
    final api = FakeFireflyService();
    await _save(tester, api, _reconciled.copyWith(description: 'Hotel stay'));

    expect(api.updatedTransactions, hasLength(1));
    expect(api.updatedTransactions.single.reconciled, isTrue);
  });
}
