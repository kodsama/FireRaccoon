import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tight_rows_columns_provider.dart';

/// Space reserved on the trailing edge of each data column for the resize
/// handle in the header. Data cells use the same inset so content lines up.
const double tightRowResizeGutter = 12.0;

/// Scales [preferred] widths so they fit in [availableWidth].
///
/// When the preferred total already fits, returns those widths unchanged so a
/// trailing spacer can absorb leftover space. When it overflows, scales every
/// column proportionally so the sum equals [availableWidth].
Map<T, double> fitColumnWidths<T>({
  required List<T> order,
  required Map<T, double> preferred,
  required double availableWidth,
}) {
  if (order.isEmpty) return {};
  if (availableWidth <= 0) {
    return {for (final c in order) c: 0.0};
  }

  var sum = 0.0;
  for (final c in order) {
    sum += preferred[c] ?? 0;
  }

  if (sum <= 0) {
    final each = availableWidth / order.length;
    return {for (final c in order) c: each};
  }

  if (sum <= availableWidth) {
    return {for (final c in order) c: preferred[c]!};
  }

  final scale = availableWidth / sum;
  return {for (final c in order) c: preferred[c]! * scale};
}

/// Identifies each data column in the accounts tight-rows table.
enum AccountColumn { account, role, balance, endOfMonth }

/// Immutable snapshot of column configuration (widths + order).
class AccountColumnConfig {
  /// Ordered list of columns (determines left-to-right rendering order).
  final List<AccountColumn> order;

  /// Width in logical pixels for each column, keyed by [AccountColumn].
  final Map<AccountColumn, double> widths;

  const AccountColumnConfig({required this.order, required this.widths});

  static const double minWidth = 60.0;
  static const double actionWidth =
      96.0; // fixed – buttons column, never resized

  /// Sum of preferred column widths plus the actions column (no padding).
  double get preferredContentWidth {
    var sum = actionWidth;
    for (final col in order) {
      sum += widths[col]!;
    }
    return sum;
  }

  /// Effective per-column widths for a row whose content area is [contentWidth]
  /// (already excluding horizontal padding). Reserves [actionWidth] for the
  /// trailing actions column.
  Map<AccountColumn, double> fittedWidths(double contentWidth) {
    return fitColumnWidths(
      order: order,
      preferred: widths,
      availableWidth: contentWidth - actionWidth,
    );
  }

  static const Map<AccountColumn, double> _defaultWidths = {
    AccountColumn.account: 200,
    AccountColumn.role: 140,
    AccountColumn.balance: 130,
    AccountColumn.endOfMonth: 130,
  };

  static const List<AccountColumn> _defaultOrder = [
    AccountColumn.account,
    AccountColumn.role,
    AccountColumn.balance,
    AccountColumn.endOfMonth,
  ];

  static const AccountColumnConfig defaults = AccountColumnConfig(
    order: _defaultOrder,
    widths: _defaultWidths,
  );

  AccountColumnConfig copyWith({
    List<AccountColumn>? order,
    Map<AccountColumn, double>? widths,
  }) => AccountColumnConfig(
    order: order ?? this.order,
    widths: widths ?? this.widths,
  );

  // ── Serialisation ───────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'order': order.map((c) => c.name).toList(),
    'widths': {for (final e in widths.entries) e.key.name: e.value},
  };

  static AccountColumnConfig fromJson(Map<String, dynamic> json) {
    try {
      final rawOrder = (json['order'] as List).cast<String>();
      final order = rawOrder
          .map((n) => AccountColumn.values.firstWhere((c) => c.name == n))
          .toList();

      final rawWidths = (json['widths'] as Map).cast<String, dynamic>();
      final widths = <AccountColumn, double>{};
      for (final col in AccountColumn.values) {
        final v = rawWidths[col.name];
        widths[col] = (v is num)
            ? (v.toDouble()).clamp(minWidth, 800)
            : _defaultWidths[col]!;
      }

      // Ensure all columns are present; add any missing at the end.
      for (final col in AccountColumn.values) {
        if (!order.contains(col)) order.add(col);
      }

      return AccountColumnConfig(order: order, widths: widths);
    } catch (_) {
      return AccountColumnConfig.defaults;
    }
  }
}

// ── Notifier (Riverpod 2.x) ──────────────────────────────────────────────────

class AccountColumnConfigNotifier extends Notifier<AccountColumnConfig> {
  static const _prefsKey = 'account_column_config';

  @override
  AccountColumnConfig build() {
    _load();
    return AccountColumnConfig.defaults;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        state = AccountColumnConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Leave defaults in place.
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }

  /// Resize [column] by [delta] pixels. Width is clamped to [AccountColumnConfig.minWidth].
  void resizeColumn(AccountColumn column, double delta) {
    final current = state.widths[column]!;
    final next = (current + delta).clamp(
      AccountColumnConfig.minWidth,
      double.infinity,
    );
    if ((next - current).abs() < 0.5) return;
    state = state.copyWith(widths: {...state.widths, column: next});
    _persist();
  }

  /// Move the column currently at [fromIndex] to [toIndex].
  void reorderColumn(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    final newOrder = List<AccountColumn>.from(state.order);
    final col = newOrder.removeAt(fromIndex);
    final insertAt = toIndex > fromIndex ? toIndex - 1 : toIndex;
    newOrder.insert(insertAt, col);
    state = state.copyWith(order: newOrder);
    _persist();
  }

  /// Reset to factory defaults.
  void resetToDefaults() {
    state = AccountColumnConfig.defaults;
    _persist();
  }

  /// Overwrites column layout (settings import).
  void replaceConfig(AccountColumnConfig config) {
    state = config;
    _persist();
  }
}

final accountColumnConfigProvider =
    NotifierProvider<AccountColumnConfigNotifier, AccountColumnConfig>(
      AccountColumnConfigNotifier.new,
    );

// ── Transaction Columns Configuration ───────────────────────────────────────

class TransactionColumnConfig {
  final List<TightRowColumn> order;
  final Map<TightRowColumn, double> widths;

  const TransactionColumnConfig({required this.order, required this.widths});

  static const double minWidth = 60.0;
  static const double actionWidth = 96.0;

  /// Sum of preferred widths for [visible] columns plus the actions column.
  double preferredContentWidth(List<TightRowColumn> visible) {
    var sum = actionWidth;
    for (final col in visible) {
      sum += widths[col]!;
    }
    return sum;
  }

  /// Effective per-column widths for a row whose content area is [contentWidth]
  /// (already excluding horizontal padding). Reserves [actionWidth] for the
  /// trailing actions column. Only [visible] columns participate.
  Map<TightRowColumn, double> fittedWidths(
    double contentWidth,
    List<TightRowColumn> visible,
  ) {
    return fitColumnWidths(
      order: visible,
      preferred: widths,
      availableWidth: contentWidth - actionWidth,
    );
  }

  static const Map<TightRowColumn, double> _defaultWidths = {
    TightRowColumn.date: 100,
    TightRowColumn.account: 150,
    TightRowColumn.type: 100,
    TightRowColumn.payee: 140,
    TightRowColumn.description: 180,
    TightRowColumn.category: 130,
    TightRowColumn.budget: 120,
    TightRowColumn.amount: 110,
    TightRowColumn.reconciled: 70,
    TightRowColumn.balance: 110,
  };

  static const List<TightRowColumn> _defaultOrder = [
    TightRowColumn.date,
    TightRowColumn.account,
    TightRowColumn.type,
    TightRowColumn.payee,
    TightRowColumn.description,
    TightRowColumn.category,
    TightRowColumn.budget,
    TightRowColumn.amount,
    TightRowColumn.reconciled,
    TightRowColumn.balance,
  ];

  static const TransactionColumnConfig defaults = TransactionColumnConfig(
    order: _defaultOrder,
    widths: _defaultWidths,
  );

  TransactionColumnConfig copyWith({
    List<TightRowColumn>? order,
    Map<TightRowColumn, double>? widths,
  }) => TransactionColumnConfig(
    order: order ?? this.order,
    widths: widths ?? this.widths,
  );

  Map<String, dynamic> toJson() => {
    'order': order.map((c) => c.name).toList(),
    'widths': {for (final e in widths.entries) e.key.name: e.value},
  };

  static TransactionColumnConfig fromJson(Map<String, dynamic> json) {
    try {
      final rawOrder = (json['order'] as List).cast<String>();
      final order = rawOrder
          .map((n) => TightRowColumn.values.firstWhere((c) => c.name == n))
          .toList();

      final rawWidths = (json['widths'] as Map).cast<String, dynamic>();
      final widths = <TightRowColumn, double>{};
      for (final col in TightRowColumn.values) {
        final v = rawWidths[col.name];
        widths[col] = (v is num)
            ? (v.toDouble()).clamp(minWidth, 800)
            : _defaultWidths[col]!;
      }

      for (final col in TightRowColumn.values) {
        if (!order.contains(col)) order.add(col);
      }

      return TransactionColumnConfig(order: order, widths: widths);
    } catch (_) {
      return TransactionColumnConfig.defaults;
    }
  }
}

class TransactionColumnConfigNotifier
    extends Notifier<TransactionColumnConfig> {
  static const _prefsKey = 'transaction_column_config';

  @override
  TransactionColumnConfig build() {
    _load();
    return TransactionColumnConfig.defaults;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        state = TransactionColumnConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Leave defaults
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }

  void resizeColumn(TightRowColumn column, double delta) {
    final current = state.widths[column]!;
    final next = (current + delta).clamp(
      TransactionColumnConfig.minWidth,
      double.infinity,
    );
    if ((next - current).abs() < 0.5) return;
    state = state.copyWith(widths: {...state.widths, column: next});
    _persist();
  }

  void reorderColumn(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    final newOrder = List<TightRowColumn>.from(state.order);
    final col = newOrder.removeAt(fromIndex);
    final insertAt = toIndex > fromIndex ? toIndex - 1 : toIndex;
    newOrder.insert(insertAt, col);
    state = state.copyWith(order: newOrder);
    _persist();
  }

  void resetToDefaults() {
    state = TransactionColumnConfig.defaults;
    _persist();
  }

  /// Overwrites transaction column layout (settings import).
  void replaceConfig(TransactionColumnConfig config) {
    state = config;
    _persist();
  }
}

final transactionColumnConfigProvider =
    NotifierProvider<TransactionColumnConfigNotifier, TransactionColumnConfig>(
      TransactionColumnConfigNotifier.new,
    );
