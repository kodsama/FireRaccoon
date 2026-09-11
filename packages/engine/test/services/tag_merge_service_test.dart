import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

class _RecordingApi implements FireflyService {
  _RecordingApi(this.carrying);

  final List<Transaction> carrying;
  final updates = <Transaction>[];
  final deletedTags = <String>[];
  final tagReads = <String>[];
  int failAfterUpdates = -1;

  @override
  Future<List<Transaction>> getTagTransactions(String tagId) async {
    tagReads.add(tagId);
    return carrying;
  }

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    if (failAfterUpdates >= 0 && updates.length >= failAfterUpdates) {
      throw StateError('update failed');
    }
    updates.add(transaction);
    return transaction;
  }

  @override
  Future<void> deleteTag(String tagId) async => deletedTags.add(tagId);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _vacances = Tag(id: '11', name: 'Vacances');
const _holidays = Tag(id: '12', name: 'Holidays');

Transaction _leg({
  required String journalId,
  required String description,
  required List<String> tags,
  double amount = 10,
}) => Transaction(
  id: '1',
  journalId: journalId,
  type: 'withdrawal',
  date: DateTime(2026, 7, 14),
  amount: amount,
  description: description,
  sourceName: 'Checking',
  destinationName: 'Hotel',
  categoryName: '',
  currencySymbol: '€',
  currencyCode: 'EUR',
  tags: tags,
);

/// A group whose second leg is the tagged one, which is how Firefly answers
/// the tag endpoint: the whole group, however few of its legs carry the tag.
Transaction _group({required String id, required List<Transaction> legs}) =>
    legs.first.copyWith(id: id, splits: legs, groupTitle: 'Summer');

void main() {
  group('merging a tag', () {
    test('moves the legs carrying it and leaves the others alone', () async {
      final api = _RecordingApi([
        _group(
          id: '97',
          legs: [
            _leg(
              journalId: '811',
              description: 'Hotel',
              tags: const ['Shared'],
            ),
            _leg(
              journalId: '812',
              description: 'Flights',
              tags: const ['Vacances', 'Shared'],
            ),
          ],
        ),
      ]);

      final result = await TagMergeService(api)
          .merge(from: _vacances, into: _holidays, dryRun: false);

      expect(api.tagReads, ['11']);
      final legs = api.updates.single.resolvedSplits();
      // Every leg goes back out with its own id, or Firefly would delete the
      // journals the write did not name.
      expect(legs.map((leg) => leg.journalId), ['811', '812']);
      expect(legs[0].tags, ['Shared']);
      expect(legs[1].tags, ['Shared', 'Holidays']);
      expect(result.legs, 1);
      expect(result.transactionIds, ['97']);
      expect(result.tagRemoved, isTrue);
      expect(api.deletedTags, ['11']);
    });

    test('a leg carrying both ends up with one of them', () async {
      final api = _RecordingApi([
        _leg(
          journalId: '900',
          description: 'Ferry',
          tags: const ['Vacances', 'Holidays'],
        ),
      ]);

      await TagMergeService(api)
          .merge(from: _vacances, into: _holidays, dryRun: false);

      expect(api.updates.single.resolvedSplits().single.tags, ['Holidays']);
    });

    test('a name that differs only in case is still the same tag', () async {
      final api = _RecordingApi([
        _leg(journalId: '901', description: 'Train', tags: const ['vacances']),
      ]);

      await TagMergeService(api)
          .merge(from: _vacances, into: _holidays, dryRun: false);

      expect(api.updates.single.resolvedSplits().single.tags, ['Holidays']);
    });

    test('a group answered but not tagged is left unwritten', () async {
      // Nothing should put a group here without the tag on it, and a write
      // per group is expensive enough that guessing is not worth it.
      final api = _RecordingApi([
        _leg(journalId: '902', description: 'Museum', tags: const ['Shared']),
      ]);

      final result = await TagMergeService(api)
          .merge(from: _vacances, into: _holidays, dryRun: false);

      expect(api.updates, isEmpty);
      expect(result.legs, 0);
      expect(result.transactionIds, isEmpty);
      // The tag is empty either way, so it still goes.
      expect(api.deletedTags, ['11']);
    });

    test('a dry run writes nothing and still counts the rows', () async {
      final api = _RecordingApi([
        _leg(journalId: '903', description: 'Hotel', tags: const ['Vacances']),
        _leg(journalId: '904', description: 'Ferry', tags: const ['Vacances']),
      ]);

      final result = await TagMergeService(api)
          .merge(from: _vacances, into: _holidays);

      expect(api.updates, isEmpty);
      expect(api.deletedTags, isEmpty);
      expect(result.dryRun, isTrue);
      expect(result.tagRemoved, isFalse);
      expect(result.legs, 2);
      expect(result.transactionIds, ['1', '1']);
    });

    test('a tag cannot be merged into itself', () async {
      final api = _RecordingApi(const []);

      await expectLater(
        TagMergeService(api).merge(from: _vacances, into: _vacances),
        throwsA(isA<ArgumentError>()),
      );
      expect(api.tagReads, isEmpty);
    });

    test('a failure part way says how far it got and keeps the tag', () async {
      final api = _RecordingApi([
        _leg(journalId: '905', description: 'Hotel', tags: const ['Vacances']),
        _leg(journalId: '906', description: 'Ferry', tags: const ['Vacances']),
      ])..failAfterUpdates = 1;

      await expectLater(
        TagMergeService(api)
            .merge(from: _vacances, into: _holidays, dryRun: false),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('1 of 2'), contains('again')),
          ),
        ),
      );
      // Half-moved rows are recoverable by running it again; a tag deleted
      // here would take the other half's only marker with it.
      expect(api.deletedTags, isEmpty);
    });
  });
}
