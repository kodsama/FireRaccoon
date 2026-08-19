import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../store/secure_storage.dart';
import '../l10n/app_localizations.dart';

enum TightRowColumn {
  date,
  account,
  type,
  payee,
  description,
  category,
  budget,
  amount,
  reconciled,
  balance,
}

extension TightRowColumnL10n on TightRowColumn {
  String label(AppLocalizations l10n) {
    switch (this) {
      case TightRowColumn.date:
        return l10n.columnDate;
      case TightRowColumn.account:
        return l10n.columnAccount;
      case TightRowColumn.type:
        return l10n.columnType;
      case TightRowColumn.payee:
        return l10n.columnPayee;
      case TightRowColumn.description:
        return l10n.columnDescription;
      case TightRowColumn.category:
        return l10n.columnCategory;
      case TightRowColumn.budget:
        return l10n.columnBudget;
      case TightRowColumn.amount:
        return l10n.columnAmount;
      case TightRowColumn.reconciled:
        return l10n.columnReconciled;
      case TightRowColumn.balance:
        return l10n.columnBalance;
    }
  }
}

class TightRowsColumnsNotifier extends Notifier<Set<TightRowColumn>> {
  static const _storage = appSecureStorage;
  static const _storageKey = 'tightRowsColumns';

  static const Set<TightRowColumn> defaultColumns = {
    TightRowColumn.date,
    TightRowColumn.account,
    TightRowColumn.type,
    TightRowColumn.payee,
    TightRowColumn.description,
    TightRowColumn.category,
    TightRowColumn.amount,
    TightRowColumn.reconciled,
    TightRowColumn.balance,
  };

  @override
  Set<TightRowColumn> build() {
    _load();
    return defaultColumns;
  }

  Future<void> _load() async {
    final stored = await _storage.read(key: _storageKey);
    if (stored != null && stored.isNotEmpty) {
      final keys = stored.split(',');
      final loaded = <TightRowColumn>{};
      for (final key in keys) {
        for (final col in TightRowColumn.values) {
          if (col.name == key.trim()) {
            loaded.add(col);
          }
        }
      }
      if (loaded.isNotEmpty) {
        state = loaded;
      }
    }
  }

  Future<void> toggleColumn(TightRowColumn column) async {
    final next = Set<TightRowColumn>.from(state);
    if (next.contains(column)) {
      if (next.length > 1) {
        next.remove(column);
      }
    } else {
      next.add(column);
    }
    state = next;
    await _save();
  }

  Future<void> setColumns(Set<TightRowColumn> columns) async {
    if (columns.isEmpty) return;
    state = Set<TightRowColumn>.from(columns);
    await _save();
  }

  Future<void> _save() async {
    final stored = TightRowColumn.values
        .where((col) => state.contains(col))
        .map((col) => col.name)
        .join(',');
    await _storage.write(key: _storageKey, value: stored);
  }
}

final tightRowsColumnsProvider =
    NotifierProvider<TightRowsColumnsNotifier, Set<TightRowColumn>>(
      TightRowsColumnsNotifier.new,
    );
