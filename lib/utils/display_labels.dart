import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../l10n/app_localizations.dart';

/// User-facing label for nullable text fields.
String displayLabelOrUnknown(String? value, AppLocalizations l10n) {
  final trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? l10n.unknown : trimmed;
}

extension TransactionDisplayLabels on Transaction {
  String displayCategory(AppLocalizations l10n) =>
      displayLabelOrUnknown(categoryName, l10n);

  /// Header label for split journals: group title when set, else description.
  String displayTitle() {
    final title = (groupTitle ?? '').trim();
    return title.isNotEmpty ? title : description;
  }

  /// Category summary for split parents with heterogeneous categories.
  String displayCategorySummary(AppLocalizations l10n) {
    final lines = resolvedSplits();
    if (lines.length <= 1) return displayCategory(l10n);

    final categories = lines
        .map((split) => categoryGroupKey(split.categoryName))
        .where((name) => name.isNotEmpty)
        .toSet();
    if (categories.isEmpty) return l10n.unknown;
    if (categories.length == 1) {
      return displayLabelOrUnknown(categories.first, l10n);
    }
    return l10n.splitCategoriesCount(categories.length);
  }
}

extension CategoryBreakdownDisplay on CategoryBreakdown {
  String displayName(AppLocalizations l10n) =>
      displayLabelOrUnknown(name, l10n);
}
