import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../theme/app_theme.dart';
import '../utils/app_feedback.dart';

/// The failures this session recorded, where the person they happened to can
/// read them.
///
/// A message shown once and dismissed is gone, and the reason a write was
/// refused is exactly what somebody needs an hour later when they report it.
/// Nothing here is sent anywhere: it is held in memory for this run only, and
/// leaves the device only if it is copied deliberately.
class DiagnosticsSection extends StatefulWidget {
  const DiagnosticsSection({super.key});

  @override
  State<DiagnosticsSection> createState() => _DiagnosticsSectionState();
}

class _DiagnosticsSectionState extends State<DiagnosticsSection> {
  List<LoggedRecord> _records() => AppLogger.recentProblems();

  Future<void> _copy() async {
    final records = _records();
    if (records.isEmpty) return;
    await Clipboard.setData(
      ClipboardData(text: records.map((r) => '$r').join('\n')),
    );
    if (!mounted) return;
    showInfoToast(context, context.l10n.problemsCopied(records.length));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final records = _records();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recentProblemsDescription,
            style: TextStyle(color: colors.text3, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            Text(
              l10n.noRecentProblems,
              style: TextStyle(color: colors.text2, fontSize: 13),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                color: colors.sunken,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Scrollbar(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: SelectableText(
                        '$record',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.35,
                          color: record.isFailure ? colors.text : colors.text2,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: records.isEmpty ? null : _copy,
                icon: const Icon(LucideIcons.copy, size: 16),
                label: Text(l10n.copyProblems),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: records.isEmpty
                    ? null
                    : () => setState(AppLogger.clearRecent),
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: Text(l10n.clearProblems),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
