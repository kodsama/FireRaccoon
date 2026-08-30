import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../deployment/deployment_providers.dart';
import '../fun_modes/fun_mode.dart';
import '../theme/app_colors.dart';
import '../theme/theme_palette.dart';
import '../providers/locale_provider.dart';
import '../providers/prognosis_settings_provider.dart';
import '../providers/server_session_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/transaction_page_size_provider.dart';
import '../providers/view_mode_provider.dart';
import '../utils/json_file_store.dart';
import 'data_providers.dart';
import 'paginated_transactions_provider.dart';
import 'transaction_analytics_providers.dart';
import 'transaction_search_provider.dart';

const kUndoHistoryMinLimit = 10;
const kUndoHistoryDefaultLimit = 10000;
const kUndoHistoryMaxLimit = 100000;
const _undoHistoryLimitPrefsKey = 'undoHistoryLimit';
const _undoHistoryFileName = 'undo_history_v1.json';

enum UndoActionType {
  themeMode,
  themePalette,
  themeAccent,
  themeFunMode,
  locale,
  viewMode,
  transactionPageSize,
  prognosisMode,
  prognosisHorizon,
  prognosisInclusion,
  prognosisMarginPercent,
  accountCreate,
  accountUpdate,
  accountDelete,
  budgetCreate,
  budgetUpdate,
  budgetDelete,
  transactionCreate,
  transactionUpdate,
  transactionDelete,
  billCreate,
  billUpdate,
  billDelete,
  recurrenceCreate,
  recurrenceUpdate,
  recurrenceDelete,
  piggyBankCreate,
  piggyBankUpdate,
  piggyBankDelete,
  liabilityCreate,
}

int normalizeUndoHistoryLimit(int value) {
  return value.clamp(kUndoHistoryMinLimit, kUndoHistoryMaxLimit);
}

class UndoEntry {
  const UndoEntry({
    required this.id,
    required this.timestampUtc,
    required this.title,
    required this.details,
    required this.type,
    required this.undoPayload,
    required this.redoPayload,
  });

  final String id;
  final DateTime timestampUtc;
  final String title;
  final String details;
  final UndoActionType type;
  final Map<String, Object?> undoPayload;
  final Map<String, Object?> redoPayload;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'timestampUtc': timestampUtc.toIso8601String(),
      'title': title,
      'details': details,
      'type': type.name,
      'undoPayload': undoPayload,
      'redoPayload': redoPayload,
    };
  }

  static UndoEntry? fromJson(Map<String, Object?> json) {
    final typeRaw = json['type'] as String?;
    final type = UndoActionType.values
        .where((e) => e.name == typeRaw)
        .firstOrNull;
    final id = json['id'] as String?;
    final timestamp = json['timestampUtc'] as String?;
    final title = json['title'] as String?;
    final details = json['details'] as String?;
    final undoPayload = json['undoPayload'] as Map<String, Object?>?;
    final redoPayload = json['redoPayload'] as Map<String, Object?>?;
    if (type == null ||
        id == null ||
        timestamp == null ||
        title == null ||
        details == null ||
        undoPayload == null ||
        redoPayload == null) {
      return null;
    }
    return UndoEntry(
      id: id,
      timestampUtc:
          DateTime.tryParse(timestamp)?.toUtc() ?? DateTime.now().toUtc(),
      title: title,
      details: details,
      type: type,
      undoPayload: undoPayload,
      redoPayload: redoPayload,
    );
  }
}

class UndoHistoryState {
  const UndoHistoryState({
    this.entries = const [],
    this.cursor = -1,
    this.isHydrated = false,
    this.limit = kUndoHistoryDefaultLimit,
  });

  final List<UndoEntry> entries;
  final int cursor;
  final bool isHydrated;
  final int limit;

  bool get canUndo => cursor >= 0 && entries.isNotEmpty;
  bool get canRedo => cursor < entries.length - 1;

  UndoHistoryState copyWith({
    List<UndoEntry>? entries,
    int? cursor,
    bool? isHydrated,
    int? limit,
  }) {
    return UndoHistoryState(
      entries: entries ?? this.entries,
      cursor: cursor ?? this.cursor,
      isHydrated: isHydrated ?? this.isHydrated,
      limit: limit ?? this.limit,
    );
  }
}

class UndoHistoryNotifier extends Notifier<UndoHistoryState> {
  late SharedPreferences _prefs;
  bool _replaying = false;
  String? _cachePath;

  @override
  UndoHistoryState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final limit = normalizeUndoHistoryLimit(
      _prefs.getInt(_undoHistoryLimitPrefsKey) ?? kUndoHistoryDefaultLimit,
    );
    _hydrate(limit);
    return UndoHistoryState(limit: limit);
  }

  Future<void> _hydrate(int limit) async {
    if (ref.read(deploymentConfigProvider).isServer) {
      await _hydrateFromServer(limit);
      return;
    }
    // Reading the file is three async gaps wide, and whoever asked for this
    // notifier can be gone by the end of any of them. Touching [state] then
    // throws, which is how a disposed container turned into a failure in a
    // test that had already finished. The server path above already guards
    // every gap; this one did not guard any.
    try {
      final path = await _historyPath();
      if (!ref.mounted) return;
      if (!await jsonStoreExists(path)) {
        if (!ref.mounted) return;
        state = state.copyWith(isHydrated: true, limit: limit);
        return;
      }
      final raw = await jsonStoreRead(path);
      if (!ref.mounted) return;
      if (raw == null || raw.trim().isEmpty) {
        state = state.copyWith(isHydrated: true, limit: limit);
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        state = state.copyWith(isHydrated: true, limit: limit);
        return;
      }
      await _applyDecodedHistory(
        Map<String, Object?>.from(decoded),
        limit: limit,
      );
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(isHydrated: true, limit: limit);
    }
  }

  Future<void> _hydrateFromServer(int limit) async {
    try {
      // Yield so Notifier.build can finish before we touch [state].
      await Future<void>.value();
      if (!ref.mounted) return;
      final client = ref.read(serverSessionProvider.notifier).client;
      if (client == null || client.sessionToken == null) {
        state = state.copyWith(isHydrated: true, limit: limit);
        return;
      }
      final snap = await client.fetchState();
      if (!ref.mounted) return;
      final undo = snap['undo'];
      if (undo is Map) {
        await _applyDecodedHistory(
          Map<String, Object?>.from(undo),
          limit: limit,
          persistAfter: false,
        );
        return;
      }
      state = state.copyWith(isHydrated: true, limit: limit);
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(isHydrated: true, limit: limit);
    }
  }

  Future<void> _applyDecodedHistory(
    Map<String, Object?> map, {
    required int limit,
    bool persistAfter = true,
  }) async {
    final cursor = map['cursor'] is int
        ? map['cursor'] as int
        : (map['index'] is int ? map['index'] as int : -1);
    final items = map['entries'] as List<Object?>? ?? const [];
    final entries = items
        .whereType<Map>()
        .map((item) => UndoEntry.fromJson(Map<String, Object?>.from(item)))
        .whereType<UndoEntry>()
        .toList();
    final normalizedEntries = entries.length > limit
        ? entries.sublist(entries.length - limit)
        : entries;
    final adjustedCursor = normalizedEntries.isEmpty
        ? -1
        : cursor.clamp(-1, normalizedEntries.length - 1);
    if (!ref.mounted) return;
    state = state.copyWith(
      entries: normalizedEntries,
      cursor: adjustedCursor,
      isHydrated: true,
      limit: limit,
    );
    if (persistAfter) await _persist();
  }

  Future<void> setLimit(int value) async {
    final normalized = normalizeUndoHistoryLimit(value);
    await _prefs.setInt(_undoHistoryLimitPrefsKey, normalized);
    var entries = state.entries;
    var cursor = state.cursor;
    if (entries.length > normalized) {
      final trimCount = entries.length - normalized;
      entries = entries.sublist(trimCount);
      cursor = entries.isEmpty
          ? -1
          : (cursor - trimCount).clamp(-1, entries.length - 1);
    }
    state = state.copyWith(entries: entries, cursor: cursor, limit: normalized);
    await _persist();
  }

  Future<void> clearHistory() async {
    state = state.copyWith(entries: const [], cursor: -1);
    await _persist();
  }

  void record({
    required String title,
    required String details,
    required UndoActionType type,
    required Map<String, Object?> undoPayload,
    required Map<String, Object?> redoPayload,
  }) {
    if (_replaying) return;

    final active = state.entries.isEmpty
        ? <UndoEntry>[]
        : state.entries.sublist(0, state.cursor + 1);
    active.add(
      UndoEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        timestampUtc: DateTime.now().toUtc(),
        title: title,
        details: details,
        type: type,
        undoPayload: undoPayload,
        redoPayload: redoPayload,
      ),
    );
    final trimmed = active.length > state.limit
        ? active.sublist(active.length - state.limit)
        : active;
    state = state.copyWith(entries: trimmed, cursor: trimmed.length - 1);
    unawaited(_persist());
  }

  Future<void> undo() async {
    if (!state.canUndo) return;
    final entry = state.entries[state.cursor];
    _replaying = true;
    try {
      final recreated = await _apply(entry.type, entry.undoPayload);
      var entries = state.entries;
      if (recreated != null) {
        entries = List.of(entries);
        entries[state.cursor] = _remapEntryTransactionId(entry, recreated.id);
      }
      state = state.copyWith(entries: entries, cursor: state.cursor - 1);
      await _persist();
    } finally {
      _replaying = false;
    }
  }

  Future<void> redo() async {
    if (!state.canRedo) return;
    final target = state.cursor + 1;
    final entry = state.entries[target];
    _replaying = true;
    try {
      final recreated = await _apply(entry.type, entry.redoPayload);
      var entries = state.entries;
      if (recreated != null) {
        entries = List.of(entries);
        entries[target] = _remapEntryTransactionId(entry, recreated.id);
      }
      state = state.copyWith(entries: entries, cursor: target);
      await _persist();
    } finally {
      _replaying = false;
    }
  }

  /// Recreating a transaction assigns a new server id; keep the history entry
  /// pointing at the live row so the opposite action still works.
  UndoEntry _remapEntryTransactionId(UndoEntry entry, String newId) {
    Map<String, Object?> remap(Map<String, Object?> payload) {
      final next = Map<String, Object?>.from(payload);
      if (next['transactionId'] is String) next['transactionId'] = newId;
      if (next['id'] is String) next['id'] = newId;
      return next;
    }

    return UndoEntry(
      id: entry.id,
      timestampUtc: entry.timestampUtc,
      title: entry.title,
      details: entry.details,
      type: entry.type,
      undoPayload: remap(entry.undoPayload),
      redoPayload: remap(entry.redoPayload),
    );
  }

  /// Patches transaction caches in place after an undo/redo mutation so the
  /// visible lists update without refetching the whole lookback window.
  void _patchTransactionCaches({Transaction? upsert, String? removeId}) {
    ref.invalidate(rangedTransactionsProvider);
    ref.invalidate(serverSearchResultsProvider);
    if (upsert == null && removeId == null) {
      ref.invalidate(transactionsProvider);
      return;
    }
    // For removals only the id survives in the payload; recover the row from
    // the shared cache to learn which account-filtered lists it touches.
    final removed = removeId == null
        ? null
        : ref
              .read(transactionsProvider)
              .value
              ?.where((t) => t.id == removeId)
              .firstOrNull;
    final patched = upsert ?? removed;
    final accountKeys =
        <String?>{
          null,
          if (patched != null) ...transactionAccountNames(patched),
        }..removeWhere(
          (key) =>
              key != null && !ref.exists(paginatedTransactionsProvider(key)),
        );
    for (final key in accountKeys) {
      final paginated = ref.read(paginatedTransactionsProvider(key).notifier);
      if (upsert != null) {
        paginated.upsertTransaction(upsert);
      } else {
        paginated.removeTransaction(removeId!);
      }
    }
    final transactionsNotifier = ref.read(transactionsProvider.notifier);
    if (upsert != null) {
      transactionsNotifier.upsert(upsert);
    } else {
      transactionsNotifier.remove(removeId!);
    }
  }

  /// Applies an undo/redo action. Returns the recreated transaction when the
  /// action recreated one server-side (its id changes), null otherwise.
  Future<Transaction?> _apply(
    UndoActionType type,
    Map<String, Object?> payload,
  ) async {
    switch (type) {
      case UndoActionType.themeMode:
        final value = payload['mode'] as String? ?? ThemeMode.system.name;
        final mode = ThemeMode.values.firstWhere(
          (m) => m.name == value,
          orElse: () => ThemeMode.system,
        );
        ref.read(themeProvider.notifier).setThemeMode(mode);
        break;
      case UndoActionType.themePalette:
        final value = payload['palette'] as String?;
        final palette = ThemePaletteType.values.firstWhere(
          (p) => p.name == value,
          orElse: () => ThemePaletteType.classic,
        );
        ref.read(themeProvider.notifier).setPalette(palette);
        break;
      case UndoActionType.themeAccent:
        final value = payload['accent'] as String?;
        final accent = AccentColorType.values.firstWhere(
          (a) => a.name == value,
          orElse: () => AccentColorType.blue,
        );
        ref.read(themeProvider.notifier).setAccent(accent);
        break;
      case UndoActionType.themeFunMode:
        final value = payload['funMode'] as String?;
        final mode = FunMode.values.firstWhere(
          (m) => m.name == value,
          orElse: () => FunMode.none,
        );
        ref.read(themeProvider.notifier).setFunMode(mode);
        break;
      case UndoActionType.locale:
        final value = payload['locale'] as String?;
        await ref
            .read(localeProvider.notifier)
            .setLocale(AppLocale.fromCode(value));
        break;
      case UndoActionType.viewMode:
        final value = payload['viewMode'] as String?;
        final mode = ViewMode.values.firstWhere(
          (m) => m.name == value,
          orElse: () => ViewMode.standard,
        );
        await ref.read(viewModeProvider.notifier).setMode(mode);
        break;
      case UndoActionType.transactionPageSize:
        final raw = payload['pageSize'] as int? ?? kDefaultTransactionPageSize;
        await ref.read(transactionPageSizeProvider.notifier).setPageSize(raw);
        break;
      case UndoActionType.prognosisMode:
        final value = payload['mode'] as String?;
        final mode = PrognosisViewMode.values.firstWhere(
          (m) => m.name == value,
          orElse: () => PrognosisViewMode.expected,
        );
        ref.read(prognosisSettingsProvider.notifier).setMode(mode);
        break;
      case UndoActionType.prognosisHorizon:
        final value = payload['horizon'] as String?;
        final horizon = PrognosisHorizon.values.firstWhere(
          (h) => h.name == value,
          orElse: () => PrognosisHorizon.endOfNextMonth,
        );
        ref.read(prognosisSettingsProvider.notifier).setHorizon(horizon);
        break;
      case UndoActionType.prognosisInclusion:
        final options = PrognosisInclusionOptions(
          includeScheduledTransactions:
              payload['includeScheduledTransactions'] as bool? ?? true,
          includeRecurringTransactions:
              payload['includeRecurringTransactions'] as bool? ?? true,
          includeBills: payload['includeBills'] as bool? ?? true,
          includeIncome: payload['includeIncome'] as bool? ?? true,
          includeExpenses: payload['includeExpenses'] as bool? ?? true,
          includeTransfers: payload['includeTransfers'] as bool? ?? true,
          includeCreditCards: payload['includeCreditCards'] as bool? ?? true,
          includeLiabilities: payload['includeLiabilities'] as bool? ?? true,
        );
        ref.read(prognosisSettingsProvider.notifier).setInclusion(options);
        break;
      case UndoActionType.prognosisMarginPercent:
        final value = (payload['marginPercent'] as num? ?? 15).toDouble();
        ref.read(prognosisSettingsProvider.notifier).setMarginPercent(value);
        break;
      case UndoActionType.accountCreate:
        final service = ref.read(apiServiceProvider);
        final accountId = payload['accountId'] as String?;
        if (accountId != null && accountId.isNotEmpty) {
          await service?.deleteAccount(accountId);
        } else {
          final name = payload['name'] as String?;
          final accountType = payload['type'] as String?;
          final currencyCode = payload['currencyCode'] as String?;
          if (name != null && accountType != null && currencyCode != null) {
            await service?.createAccount(
              name: name,
              type: accountType,
              currencyCode: currencyCode,
            );
          }
        }
        ref.invalidate(accountsProvider);
        break;
      case UndoActionType.accountUpdate:
        final service = ref.read(apiServiceProvider);
        final accountId = payload['accountId'] as String?;
        final name = payload['name'] as String?;
        if (accountId != null && name != null) {
          await service?.updateAccount(accountId, name: name);
          ref.invalidate(accountsProvider);
        }
        break;
      case UndoActionType.accountDelete:
        final service = ref.read(apiServiceProvider);
        final accountId = payload['accountId'] as String?;
        if (accountId != null && accountId.isNotEmpty) {
          await service?.deleteAccount(accountId);
        } else {
          final name = payload['name'] as String?;
          final accountType = payload['type'] as String?;
          final currencyCode = payload['currencyCode'] as String?;
          if (name != null && accountType != null && currencyCode != null) {
            await service?.createAccount(
              name: name,
              type: accountType,
              currencyCode: currencyCode,
            );
          }
        }
        ref.invalidate(accountsProvider);
        break;
      case UndoActionType.budgetCreate:
        final service = ref.read(apiServiceProvider);
        final budgetId = payload['budgetId'] as String?;
        if (budgetId != null && budgetId.isNotEmpty) {
          await service?.deleteBudget(budgetId);
        } else {
          final input = _budgetInputFromPayload(payload);
          if (input != null) {
            await service?.createBudget(input);
          }
        }
        ref.invalidate(budgetsProvider);
        break;
      case UndoActionType.budgetUpdate:
        final service = ref.read(apiServiceProvider);
        final budgetId = payload['budgetId'] as String?;
        final input = _budgetInputFromPayload(payload);
        if (budgetId != null && input != null) {
          await service?.updateBudget(budgetId, input);
          ref.invalidate(budgetsProvider);
        }
        break;
      case UndoActionType.budgetDelete:
        final service = ref.read(apiServiceProvider);
        final budgetId = payload['budgetId'] as String?;
        if (budgetId != null && budgetId.isNotEmpty) {
          await service?.deleteBudget(budgetId);
        } else {
          final input = _budgetInputFromPayload(payload);
          if (input != null) {
            await service?.createBudget(input);
          }
        }
        ref.invalidate(budgetsProvider);
        break;
      case UndoActionType.transactionCreate:
        final service = ref.read(apiServiceProvider);
        final transactionId = payload['transactionId'] as String?;
        if (transactionId != null && transactionId.isNotEmpty) {
          await service?.deleteTransaction(transactionId);
          _patchTransactionCaches(removeId: transactionId);
        } else {
          final transaction = _transactionFromPayload(payload);
          if (transaction != null) {
            final created = await service?.createTransaction(transaction);
            _patchTransactionCaches(upsert: created);
            ref.invalidate(scopedTransactionsProvider);
            return created;
          }
        }
        ref.invalidate(scopedTransactionsProvider);
        break;
      case UndoActionType.transactionUpdate:
        final service = ref.read(apiServiceProvider);
        final transaction = _transactionFromPayload(payload);
        if (transaction != null) {
          final saved = await service?.updateTransaction(transaction);
          _patchTransactionCaches(upsert: saved);
          ref.invalidate(scopedTransactionsProvider);
        }
        break;
      case UndoActionType.transactionDelete:
        final service = ref.read(apiServiceProvider);
        // Redo carries only the id (delete again); undo carries the full
        // payload (recreate).
        final transactionId = payload['transactionId'] as String?;
        if (transactionId != null && transactionId.isNotEmpty) {
          await service?.deleteTransaction(transactionId);
          _patchTransactionCaches(removeId: transactionId);
          ref.invalidate(scopedTransactionsProvider);
        } else {
          final transaction = _transactionFromPayload(payload);
          if (transaction != null) {
            final created = await service?.createTransaction(transaction);
            _patchTransactionCaches(upsert: created);
            ref.invalidate(scopedTransactionsProvider);
            return created;
          }
        }
        break;
      case UndoActionType.billCreate:
        final service = ref.read(apiServiceProvider);
        final billId = payload['billId'] as String?;
        if (billId != null && billId.isNotEmpty) {
          await service?.deleteBill(billId);
        } else {
          final input = _billInputFromPayload(payload);
          if (input != null) {
            await service?.createBill(input);
          }
        }
        ref.invalidate(billsProvider);
        break;
      case UndoActionType.billUpdate:
        final service = ref.read(apiServiceProvider);
        final billId = payload['billId'] as String?;
        final input = _billInputFromPayload(payload);
        if (billId != null && input != null) {
          await service?.updateBill(billId, input);
          ref.invalidate(billsProvider);
        }
        break;
      case UndoActionType.billDelete:
        final service = ref.read(apiServiceProvider);
        final billId = payload['billId'] as String?;
        if (billId != null && billId.isNotEmpty) {
          await service?.deleteBill(billId);
        } else {
          final input = _billInputFromPayload(payload);
          if (input != null) {
            await service?.createBill(input);
          }
        }
        ref.invalidate(billsProvider);
        break;
      case UndoActionType.recurrenceCreate:
        final service = ref.read(apiServiceProvider);
        final recurrenceId = payload['recurrenceId'] as String?;
        if (recurrenceId != null && recurrenceId.isNotEmpty) {
          await service?.deleteRecurrence(recurrenceId);
        } else {
          final input = _recurrenceInputFromPayload(payload);
          if (input != null) {
            await service?.createRecurrence(input);
          }
        }
        ref.invalidate(recurrencesProvider);
        break;
      case UndoActionType.recurrenceUpdate:
        final service = ref.read(apiServiceProvider);
        final recurrenceId = payload['recurrenceId'] as String?;
        final input = _recurrenceInputFromPayload(payload);
        if (recurrenceId != null && input != null) {
          await service?.updateRecurrence(recurrenceId, input);
          ref.invalidate(recurrencesProvider);
        }
        break;
      case UndoActionType.recurrenceDelete:
        final service = ref.read(apiServiceProvider);
        final recurrenceId = payload['recurrenceId'] as String?;
        if (recurrenceId != null && recurrenceId.isNotEmpty) {
          await service?.deleteRecurrence(recurrenceId);
        } else {
          final input = _recurrenceInputFromPayload(payload);
          if (input != null) {
            await service?.createRecurrence(input);
          }
        }
        ref.invalidate(recurrencesProvider);
        break;
      case UndoActionType.piggyBankCreate:
        final service = ref.read(apiServiceProvider);
        final piggyBankId = payload['piggyBankId'] as String?;
        if (piggyBankId != null && piggyBankId.isNotEmpty) {
          await service?.deletePiggyBank(piggyBankId);
        } else {
          final input = _piggyBankInputFromPayload(payload);
          if (input != null) {
            await service?.createPiggyBank(input);
          }
        }
        ref.invalidate(piggyBanksProvider);
        break;
      case UndoActionType.piggyBankUpdate:
        final service = ref.read(apiServiceProvider);
        final piggyBankId = payload['piggyBankId'] as String?;
        final input = _piggyBankInputFromPayload(payload);
        if (piggyBankId != null && input != null) {
          await service?.updatePiggyBank(piggyBankId, input);
          ref.invalidate(piggyBanksProvider);
        }
        break;
      case UndoActionType.piggyBankDelete:
        final service = ref.read(apiServiceProvider);
        final piggyBankId = payload['piggyBankId'] as String?;
        if (piggyBankId != null && piggyBankId.isNotEmpty) {
          await service?.deletePiggyBank(piggyBankId);
        } else {
          final input = _piggyBankInputFromPayload(payload);
          if (input != null) {
            await service?.createPiggyBank(input);
          }
        }
        ref.invalidate(piggyBanksProvider);
        break;
      case UndoActionType.liabilityCreate:
        final service = ref.read(apiServiceProvider);
        final accountId = payload['accountId'] as String?;
        if (accountId != null && accountId.isNotEmpty) {
          await service?.deleteAccount(accountId);
        } else {
          final input = _liabilityInputFromPayload(payload);
          if (input != null) {
            await service?.createLiability(input);
          }
        }
        ref.invalidate(accountsProvider);
        break;
    }
    return null;
  }

  DateTime _readDate(
    Map<String, Object?> payload,
    String key,
    DateTime fallback,
  ) {
    final raw = payload[key] as String?;
    return DateTime.tryParse(raw ?? '') ?? fallback;
  }

  DateTime? _readNullableDate(Map<String, Object?> payload, String key) {
    final raw = payload[key] as String?;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  BudgetInput? _budgetInputFromPayload(Map<String, Object?> payload) {
    final name = payload['name'] as String?;
    if (name == null) return null;

    final legacyAmount = (payload['amount'] as num?)?.toDouble();
    final autoBudgetAmount =
        (payload['autoBudgetAmount'] as num?)?.toDouble() ?? legacyAmount;
    final currencyCode =
        payload['currencyCode'] as String? ??
        payload['auto_budget_currency_code'] as String? ??
        'EUR';

    return BudgetInput(
      name: name,
      active: payload['active'] as bool? ?? true,
      notes: payload['notes'] as String?,
      autoBudgetType: AutoBudgetType.parse(
        payload['autoBudgetType'] as String?,
      ),
      autoBudgetAmount: autoBudgetAmount,
      autoBudgetPeriod: AutoBudgetPeriod.parse(
        payload['autoBudgetPeriod'] as String?,
      ),
      currencyCode: currencyCode,
    );
  }

  BillInput? _billInputFromPayload(Map<String, Object?> payload) {
    final name = payload['name'] as String?;
    final amountMin = (payload['amountMin'] as num?)?.toDouble();
    final amountMax = (payload['amountMax'] as num?)?.toDouble();
    final currencyCode = payload['currencyCode'] as String?;
    if (name == null ||
        amountMin == null ||
        amountMax == null ||
        currencyCode == null) {
      return null;
    }
    final repeat = BillRepeatFrequency.values.firstWhere(
      (item) => item.name == (payload['repeatFrequency'] as String?),
      orElse: () => BillRepeatFrequency.monthly,
    );
    return BillInput(
      name: name,
      amountMin: amountMin,
      amountMax: amountMax,
      currencyCode: currencyCode,
      date: _readDate(payload, 'date', DateTime.now()),
      repeatFrequency: repeat,
      skip: payload['skip'] as int? ?? 0,
      active: payload['active'] as bool? ?? true,
      endDate: _readNullableDate(payload, 'endDate'),
      extensionDate: _readNullableDate(payload, 'extensionDate'),
      notes: payload['notes'] as String?,
      objectGroupTitle: payload['objectGroupTitle'] as String?,
    );
  }

  PiggyBankInput? _piggyBankInputFromPayload(Map<String, Object?> payload) {
    final name = payload['name'] as String?;
    final targetAmount = (payload['targetAmount'] as num?)?.toDouble();
    final currencyCode = payload['currencyCode'] as String?;
    final accountIds = (payload['accountIds'] as List<Object?>?)
        ?.whereType<String>()
        .toList();
    if (name == null ||
        targetAmount == null ||
        currencyCode == null ||
        accountIds == null ||
        accountIds.isEmpty) {
      return null;
    }
    return PiggyBankInput(
      name: name,
      targetAmount: targetAmount,
      currencyCode: currencyCode,
      accountIds: accountIds,
      startDate: _readDate(payload, 'startDate', DateTime.now()),
      targetDate: _readNullableDate(payload, 'targetDate'),
      notes: payload['notes'] as String?,
      objectGroupTitle: payload['objectGroupTitle'] as String?,
    );
  }

  RecurrenceInput? _recurrenceInputFromPayload(Map<String, Object?> payload) {
    final title = payload['title'] as String?;
    if (title == null) return null;
    final type = RecurrenceTransactionType.values.firstWhere(
      (item) => item.name == (payload['type'] as String?),
      orElse: () => RecurrenceTransactionType.withdrawal,
    );
    final repetitionType = RecurrenceRepetitionType.values.firstWhere(
      (item) => item.name == (payload['repetitionType'] as String?),
      orElse: () => RecurrenceRepetitionType.monthly,
    );
    final weekend = RecurrenceWeekendMode.values.firstWhere(
      (item) => item.name == (payload['weekendMode'] as String?),
      orElse: () => RecurrenceWeekendMode.createAnyway,
    );
    final sourceId = payload['sourceId'] as String?;
    final destinationId = payload['destinationId'] as String?;
    final amount = (payload['amount'] as num?)?.toDouble();
    final currencyCode = payload['currencyCode'] as String?;
    final txDescription = payload['transactionDescription'] as String?;
    if (sourceId == null ||
        destinationId == null ||
        amount == null ||
        currencyCode == null ||
        txDescription == null) {
      return null;
    }
    return RecurrenceInput(
      type: type,
      title: title,
      description: payload['description'] as String?,
      firstDate: _readDate(payload, 'firstDate', DateTime.now()),
      repeatUntil: _readNullableDate(payload, 'repeatUntil'),
      nrOfRepetitions: payload['nrOfRepetitions'] as int?,
      applyRules: payload['applyRules'] as bool? ?? true,
      active: payload['active'] as bool? ?? true,
      notes: payload['notes'] as String?,
      repetitions: [
        RecurrenceRepetitionInput(
          type: repetitionType,
          moment: payload['moment'] as String? ?? '',
          skip: payload['skip'] as int? ?? 0,
          weekend: weekend,
        ),
      ],
      transactions: [
        RecurrenceTransactionInput(
          id: payload['transactionLineId'] as String?,
          description: txDescription,
          amount: amount,
          currencyCode: currencyCode,
          foreignAmount: (payload['foreignAmount'] as num?)?.toDouble(),
          foreignCurrencyCode: payload['foreignCurrencyCode'] as String?,
          sourceId: sourceId,
          destinationId: destinationId,
          budgetId: payload['budgetId'] as String?,
          categoryId: payload['categoryId'] as String?,
          billId: payload['billId'] as String?,
          tags:
              (payload['tags'] as List<Object?>?)
                  ?.whereType<String>()
                  .toList() ??
              const [],
        ),
      ],
    );
  }

  Transaction? _transactionFromPayload(Map<String, Object?> payload) {
    final type = payload['type'] as String?;
    final amount = (payload['amount'] as num?)?.toDouble();
    final description = payload['description'] as String?;
    final sourceName = payload['sourceName'] as String?;
    final destinationName = payload['destinationName'] as String?;
    final currencySymbol = payload['currencySymbol'] as String?;
    final currencyCode = payload['currencyCode'] as String?;
    if (type == null ||
        amount == null ||
        description == null ||
        sourceName == null ||
        destinationName == null ||
        currencySymbol == null ||
        currencyCode == null) {
      return null;
    }
    return Transaction(
      id: payload['id'] as String? ?? '',
      type: type,
      date: _readDate(payload, 'date', DateTime.now()),
      amount: amount,
      description: description,
      sourceName: sourceName,
      destinationName: destinationName,
      categoryName: payload['categoryName'] as String? ?? '',
      currencySymbol: currencySymbol,
      currencyCode: currencyCode,
      foreignAmount: (payload['foreignAmount'] as num?)?.toDouble(),
      foreignCurrencySymbol: payload['foreignCurrencySymbol'] as String?,
      foreignCurrencyCode: payload['foreignCurrencyCode'] as String?,
      sourceId: payload['sourceId'] as String?,
      destinationId: payload['destinationId'] as String?,
      categoryId: payload['categoryId'] as String?,
      budgetId: payload['budgetId'] as String?,
      budgetName: payload['budgetName'] as String?,
      notes: payload['notes'] as String?,
      tags:
          (payload['tags'] as List<Object?>?)?.whereType<String>().toList() ??
          const [],
      billId: payload['billId'] as String?,
      billName: payload['billName'] as String?,
      piggyBankId: payload['piggyBankId'] as String?,
      piggyBankName: payload['piggyBankName'] as String?,
      interestDate: _readNullableDate(payload, 'interestDate'),
      groupTitle: payload['groupTitle'] as String?,
      reconciled: payload['reconciled'] as bool? ?? false,
    );
  }

  LiabilityInput? _liabilityInputFromPayload(Map<String, Object?> payload) {
    final name = payload['name'] as String?;
    final currencyCode = payload['currencyCode'] as String?;
    if (name == null || currencyCode == null) return null;
    final liabilityType = LiabilityType.values.firstWhere(
      (item) => item.name == (payload['liabilityType'] as String?),
      orElse: () => LiabilityType.debt,
    );
    final liabilityDirection = LiabilityDirection.values.firstWhere(
      (item) => item.name == (payload['liabilityDirection'] as String?),
      orElse: () => LiabilityDirection.credit,
    );
    final periodName = payload['interestPeriod'] as String?;
    final period = InterestPeriod.values.where(
      (item) => item.name == periodName,
    );
    return LiabilityInput(
      name: name,
      currencyCode: currencyCode,
      liabilityType: liabilityType,
      liabilityDirection: liabilityDirection,
      amountOwed: (payload['amountOwed'] as num?)?.toDouble(),
      startDate: _readNullableDate(payload, 'startDate'),
      interest: (payload['interest'] as num?)?.toDouble(),
      interestPeriod: period.isEmpty ? null : period.first,
      includeNetWorth: payload['includeNetWorth'] as bool? ?? true,
      iban: payload['iban'] as String?,
      bic: payload['bic'] as String?,
      accountNumber: payload['accountNumber'] as String?,
      notes: payload['notes'] as String?,
    );
  }

  Future<String> _historyPath() async {
    final cached = _cachePath;
    if (cached != null) return cached;
    final path = await jsonStoreSupportPath(_undoHistoryFileName);
    _cachePath = path;
    return path;
  }

  Future<void> _persist() async {
    final payload = <String, Object?>{
      'cursor': state.cursor,
      'index': state.cursor,
      'limit': state.limit,
      'entries': state.entries.map((entry) => entry.toJson()).toList(),
    };
    if (ref.read(deploymentConfigProvider).isServer) {
      final client = ref.read(serverSessionProvider.notifier).client;
      if (client != null && client.sessionToken != null) {
        try {
          await client.putUndo(payload);
        } on Object {
          // Keep in-memory history; next successful persist will sync.
        }
      }
      return;
    }
    final path = await _historyPath();
    await jsonStoreWrite(path, jsonEncode(payload));
  }
}

final undoHistoryProvider =
    NotifierProvider<UndoHistoryNotifier, UndoHistoryState>(
      UndoHistoryNotifier.new,
    );
