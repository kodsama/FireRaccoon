import '../models/account.dart';
import '../models/budget.dart';
import '../models/transaction.dart';

bool matchesSearchQuery(String? query, Iterable<String> fields) {
  if (query == null || query.trim().isEmpty) return true;
  final needle = query.trim().toLowerCase();
  for (final field in fields) {
    if (field.toLowerCase().contains(needle)) return true;
  }
  return false;
}

extension AccountSearch on Account {
  bool matchesSearch(String? query) =>
      matchesSearchQuery(query, [name, type, role, currencyCode]);
}

extension TransactionSearch on Transaction {
  bool matchesSearch(String? query) {
    final fields = <String>[
      description,
      sourceName,
      destinationName,
      categoryName,
      type,
      ?groupTitle,
    ];
    for (final split in resolvedSplits()) {
      fields.addAll([
        split.description,
        split.sourceName,
        split.destinationName,
        split.categoryName,
      ]);
    }
    return matchesSearchQuery(query, fields);
  }
}

extension BudgetSearch on Budget {
  bool matchesSearch(String? query) => matchesSearchQuery(query, [name]);
}
