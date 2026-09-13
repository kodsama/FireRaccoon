import '../models/tag.dart';
import '../models/transaction.dart';
import 'firefly_service.dart';

/// Moves every transaction from one tag onto another and removes the tag it
/// empties.
///
/// Firefly has no merge endpoint and refuses a rename onto a name already in
/// use, so two tags meaning the same thing can only be reconciled row by row.
/// A tag sits on a journal rather than on the group around it, which is why
/// this rewrites legs and not groups: a split whose second leg carries the tag
/// keeps everything about its first.
class TagMergeService {
  const TagMergeService(this._api);

  final FireflyService _api;

  /// Rewrites every leg carrying [from] to carry [into] instead, then deletes
  /// [from]. Reports what it would do and writes nothing while [dryRun].
  ///
  /// One write per transaction group, and not atomic: a failure part way
  /// leaves the groups already written on [into], keeps [from] in place, and
  /// says how far it got, because running it again finishes the rest.
  Future<TagMergeResult> merge({
    required Tag from,
    required Tag into,
    bool dryRun = true,
  }) async {
    if (from.id == into.id) {
      throw ArgumentError('a tag cannot be merged into itself');
    }

    final rewritten = <Transaction>[];
    var legs = 0;
    for (final group in await _api.getTagTransactions(from.id)) {
      final splits = <Transaction>[];
      var moved = 0;
      for (final split in group.resolvedSplits()) {
        final tags = _movedTags(split.tags, from: from.name, into: into.name);
        if (tags == null) {
          splits.add(split);
          continue;
        }
        moved++;
        splits.add(split.copyWith(tags: tags));
      }
      // Firefly answers this endpoint with the whole group, legs included, so
      // a group is here because one of its legs carries the tag and not
      // necessarily because all of them do.
      if (moved == 0) continue;
      legs += moved;
      rewritten.add(group.copyWith(splits: splits));
    }

    if (dryRun) {
      return TagMergeResult(
        from: from,
        into: into,
        transactionIds: [for (final group in rewritten) group.id],
        legs: legs,
        dryRun: true,
        tagRemoved: false,
      );
    }

    final written = <String>[];
    for (final group in rewritten) {
      try {
        await _api.updateTransaction(group);
        written.add(group.id);
      } catch (error) {
        Error.throwWithStackTrace(
          StateError(
            'Merging ${from.name} into ${into.name} failed after moving '
            '${written.length} of ${rewritten.length} transactions: $error. '
            '${from.name} is still there, so running the merge again moves '
            'what is left.',
          ),
          StackTrace.current,
        );
      }
    }
    await _api.deleteTag(from.id);

    return TagMergeResult(
      from: from,
      into: into,
      transactionIds: written,
      legs: legs,
      dryRun: false,
      tagRemoved: true,
    );
  }

  /// [tags] with [from] swapped for [into], or null when this leg carries
  /// neither the tag nor a change worth writing.
  ///
  /// A leg already carrying both keeps one of them rather than two.
  static List<String>? _movedTags(
    List<String> tags, {
    required String from,
    required String into,
  }) {
    bool same(String tag, String other) =>
        tag.toLowerCase() == other.toLowerCase();
    if (!tags.any((tag) => same(tag, from))) return null;
    final kept = [
      for (final tag in tags)
        if (!same(tag, from)) tag,
    ];
    if (!kept.any((tag) => same(tag, into))) kept.add(into);
    return kept;
  }
}

class TagMergeResult {
  const TagMergeResult({
    required this.from,
    required this.into,
    required this.transactionIds,
    required this.legs,
    required this.dryRun,
    required this.tagRemoved,
  });

  final Tag from;
  final Tag into;

  /// Transaction groups holding at least one leg that moved.
  final List<String> transactionIds;

  /// Journals that moved, which is what a tag is actually attached to.
  final int legs;
  final bool dryRun;

  /// Whether the emptied tag is gone. Never on a dry run.
  final bool tagRemoved;
}
