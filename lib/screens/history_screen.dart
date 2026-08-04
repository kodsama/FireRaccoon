import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

import 'package:go_router/go_router.dart';
import '../l10n/l10n_extensions.dart';
import '../providers/undo_history_provider.dart' as undo;
import '../providers/theme_provider.dart';
import '../router/history_route.dart';
import '../theme/app_theme.dart';
import '../utils/json_file_store.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '';
  undo.UndoActionType? _typeFilter;
  final _listController = ScrollController();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  String _historyExportPayload(undo.UndoHistoryState history) {
    final payload = {
      'cursor': history.cursor,
      'limit': history.limit,
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'entries': history.entries.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<({String path, String contents})> _writeHistoryExport(
    undo.UndoHistoryState history,
  ) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'fireracoon_history_$timestamp.json';
    final path = await jsonStoreDocumentsPath(fileName);
    final contents = _historyExportPayload(history);
    await jsonStoreWrite(path, contents);
    return (path: path, contents: contents);
  }

  Future<void> _exportHistory(undo.UndoHistoryState history) async {
    final l10n = context.l10n;
    final export = await _writeHistoryExport(history);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.historyExportedTo(export.path))),
    );
  }

  Future<void> _exportAndShareHistory(undo.UndoHistoryState history) async {
    final l10n = context.l10n;
    final export = await _writeHistoryExport(history);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    await SharePlus.instance.share(
      ShareParams(
        text: l10n.historyExportText,
        subject: l10n.historyExportSubject,
        files: [
          XFile.fromData(
            utf8.encode(export.contents),
            mimeType: 'application/json',
            name: 'fireracoon_history_$timestamp.json',
          ),
        ],
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.historyExportedAndShared)));
  }

  void _jumpToCurrent(
    undo.UndoHistoryState history,
    List<undo.UndoEntry> visibleEntries,
  ) {
    if (history.cursor < 0 || history.cursor >= history.entries.length) return;
    final current = history.entries[history.cursor];
    final visibleIndex = visibleEntries.indexWhere(
      (entry) => entry.id == current.id,
    );
    if (visibleIndex < 0) return;
    _listController.animateTo(
      (visibleIndex * 96).toDouble(),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);
    final history = ref.watch(undo.undoHistoryProvider);
    final notifier = ref.read(undo.undoHistoryProvider.notifier);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final routeState = GoRouterState.of(context);
    final routeQuery = HistoryRoute.searchFrom(routeState) ?? _query;
    final routeType = HistoryRoute.typeFrom(routeState) ?? _typeFilter;

    final entries = history.entries
        .where((entry) {
          final matchesType = routeType == null || entry.type == routeType;
          if (!matchesType) return false;
          if (routeQuery.trim().isEmpty) return true;
          final needle = routeQuery.toLowerCase();
          return entry.type
                  .localizedLabel(l10n)
                  .toLowerCase()
                  .contains(needle) ||
              entry.details.toLowerCase().contains(needle) ||
              entry.title.toLowerCase().contains(needle);
        })
        .toList()
        .reversed
        .toList();

    final now = DateTime.now();
    final today = <undo.UndoEntry>[];
    final yesterday = <undo.UndoEntry>[];
    final older = <undo.UndoEntry>[];
    for (final entry in entries) {
      final localDate = entry.timestampUtc.toLocal();
      final dayDiff = DateUtils.dateOnly(
        now,
      ).difference(DateUtils.dateOnly(localDate)).inDays;
      if (dayDiff == 0) {
        today.add(entry);
      } else if (dayDiff == 1) {
        yesterday.add(entry);
      } else {
        older.add(entry);
      }
    }
    final flat = <({String? header, undo.UndoEntry? entry})>[
      if (today.isNotEmpty) (header: l10n.historySectionToday, entry: null),
      ...today.map((entry) => (header: null, entry: entry)),
      if (yesterday.isNotEmpty)
        (header: l10n.historySectionYesterday, entry: null),
      ...yesterday.map((entry) => (header: null, entry: entry)),
      if (older.isNotEmpty) (header: l10n.historySectionOlder, entry: null),
      ...older.map((entry) => (header: null, entry: entry)),
    ];

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.history, color: colors.accent.acc),
                const SizedBox(width: 10),
                Text(fun.navHistory, style: context.textTheme.headlineMedium),
                const Spacer(),
                Text(
                  l10n.historyEntriesCount(
                    history.entries.length,
                    history.limit,
                  ),
                  style: TextStyle(color: colors.text3),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: history.canUndo ? () => notifier.undo() : null,
                  icon: const Icon(LucideIcons.undo2, size: 16),
                  label: Text(l10n.undo),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: history.canRedo ? () => notifier.redo() : null,
                  icon: const Icon(LucideIcons.redo2, size: 16),
                  label: Text(l10n.redo),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: history.entries.isEmpty
                      ? null
                      : () => notifier.clearHistory(),
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  label: Text(l10n.clear),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: history.entries.isEmpty
                      ? null
                      : () => _exportHistory(history),
                  icon: const Icon(LucideIcons.fileDown, size: 16),
                  label: Text(l10n.exportJson),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: history.entries.isEmpty
                      ? null
                      : () => _exportAndShareHistory(history),
                  icon: const Icon(LucideIcons.share2, size: 16),
                  label: Text(l10n.exportAndShare),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: entries.isEmpty
                      ? null
                      : () => _jumpToCurrent(history, entries),
                  icon: const Icon(LucideIcons.crosshair, size: 16),
                  label: Text(l10n.jumpToCurrent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: routeQuery)
                      ..selection = TextSelection.collapsed(
                        offset: routeQuery.length,
                      ),
                    onChanged: (value) {
                      _query = value;
                      context.go(
                        HistoryRoute.location(
                          search: value.isEmpty ? null : value,
                          type: routeType,
                        ),
                      );
                    },
                    decoration: InputDecoration(
                      labelText: l10n.searchHistory,
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<undo.UndoActionType?>(
                  value: routeType,
                  hint: Text(l10n.allActions),
                  items: [
                    DropdownMenuItem<undo.UndoActionType?>(
                      value: null,
                      child: Text(l10n.allActions),
                    ),
                    ...undo.UndoActionType.values.map(
                      (type) => DropdownMenuItem<undo.UndoActionType?>(
                        value: type,
                        child: Text(type.localizedLabel(l10n)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    _typeFilter = value;
                    context.go(
                      HistoryRoute.location(
                        search: routeQuery.isEmpty ? null : routeQuery,
                        type: value,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noHistoryEntriesMatchFilters,
                        style: TextStyle(color: colors.text3),
                      ),
                    )
                  : ListView.separated(
                      controller: _listController,
                      itemCount: flat.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = flat[index];
                        if (row.header != null) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              row.header!,
                              style: TextStyle(
                                color: colors.text3,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          );
                        }
                        final entry = row.entry!;
                        final absoluteIndex = history.entries.indexWhere(
                          (item) => item.id == entry.id,
                        );
                        final isCurrent = absoluteIndex == history.cursor;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isCurrent ? colors.surface2 : colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent
                                  ? colors.accent.acc
                                  : colors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.type.localizedLabel(l10n),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    dateFormat.format(
                                      entry.timestampUtc.toLocal(),
                                    ),
                                    style: TextStyle(
                                      color: colors.text3,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entry.details,
                                style: TextStyle(color: colors.text2),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
