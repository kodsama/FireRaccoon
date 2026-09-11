import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/undo_history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_feedback.dart';
import '../utils/history_entry_changes.dart';

/// What one history entry did, field by field, with the offer to take it back.
Future<void> showHistoryEntryDetails({
  required BuildContext context,
  required UndoEntry entry,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _HistoryEntryDetailsDialog(entry: entry),
  );
}

class _HistoryEntryDetailsDialog extends ConsumerStatefulWidget {
  const _HistoryEntryDetailsDialog({required this.entry});

  final UndoEntry entry;

  @override
  ConsumerState<_HistoryEntryDetailsDialog> createState() =>
      _HistoryEntryDetailsDialogState();
}

class _HistoryEntryDetailsDialogState
    extends ConsumerState<_HistoryEntryDetailsDialog> {
  bool _reverting = false;

  Future<void> _revert() async {
    final l10n = context.l10n;
    setState(() => _reverting = true);
    try {
      await ref.read(undoHistoryProvider.notifier).revert(widget.entry.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      showInfoToast(context, l10n.historyEntryReverted);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _reverting = false);
      reportError(
        context,
        l10n.historyEntryRevertFailed(readableError(error)),
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final entry = widget.entry;
    final changes = historyEntryChanges(entry);

    return AlertDialog(
      title: Text(entry.type.localizedLabel(l10n)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('yyyy-MM-dd HH:mm:ss')
                    .format(entry.timestampUtc.toLocal()),
                style: TextStyle(color: colors.text3, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(entry.details),
              const SizedBox(height: 16),
              Text(
                l10n.historyEntryWhatChanged,
                style: TextStyle(
                  color: colors.text2,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              if (changes.isEmpty)
                Text(
                  l10n.historyEntryNothingRecorded,
                  style: TextStyle(color: colors.text3),
                )
              else
                for (final change in changes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            historyFieldLabel(change.field),
                            style: TextStyle(color: colors.text2, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _sideBySide(l10n, change),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _reverting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _reverting ? null : _revert,
          icon: const Icon(LucideIcons.undo2, size: 16),
          label: Text(l10n.historyEntryRevert),
        ),
      ],
    );
  }

  /// What it was and what it became, or just the half that exists: a creation
  /// has no before and a deletion has no after.
  String _sideBySide(dynamic l10n, HistoryFieldChange change) {
    final before = change.before;
    final after = change.after;
    if (before == null) return after ?? '';
    if (after == null) return l10n.historyEntryCleared(before);
    return '$before  →  $after';
  }
}
