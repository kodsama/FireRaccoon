import '../utils/budget_period.dart';

class Budget {
  final String id;
  final String name;
  final bool active;
  final String? notes;
  final double spent;
  final double autoBudgetAmount;
  final AutoBudgetType autoBudgetType;
  final AutoBudgetPeriod? autoBudgetPeriod;
  final String currencySymbol;
  final String currencyCode;

  Budget({
    required this.id,
    required this.name,
    required this.active,
    this.notes,
    required this.spent,
    required this.autoBudgetAmount,
    this.autoBudgetType = AutoBudgetType.none,
    this.autoBudgetPeriod,
    required this.currencySymbol,
    required this.currencyCode,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>;

    // Firefly returns 'spent' as an array of amounts (one per currency)
    final spentArray = attrs['spent'] as List<dynamic>? ?? [];
    double totalSpent = 0.0;
    if (spentArray.isNotEmpty) {
      final firstSpent = spentArray[0] as Map<String, dynamic>;
      // Spent amounts are usually negative strings, so take the absolute value
      totalSpent =
          (double.tryParse(firstSpent['sum']?.toString() ?? '0') ?? 0.0).abs();
    }

    return Budget(
      id: json['id'] as String,
      name: attrs['name'] as String? ?? 'Unnamed Budget',
      active: attrs['active'] as bool? ?? false,
      notes: attrs['notes'] as String?,
      spent: totalSpent,
      autoBudgetAmount:
          double.tryParse(attrs['auto_budget_amount']?.toString() ?? '0') ??
          0.0,
      autoBudgetType: AutoBudgetType.parse(
        attrs['auto_budget_type']?.toString(),
      ),
      autoBudgetPeriod: AutoBudgetPeriod.parse(
        attrs['auto_budget_period'] as String?,
      ),
      currencySymbol: attrs['auto_budget_currency_symbol'] as String? ?? '€',
      currencyCode: attrs['auto_budget_currency_code'] as String? ?? 'EUR',
    );
  }
}

class BudgetLimit {
  final String id;
  final String budgetId;
  final DateTime start;
  final DateTime end;
  final double amount;
  final String currencyCode;
  final String currencySymbol;
  final String? notes;

  const BudgetLimit({
    required this.id,
    required this.budgetId,
    required this.start,
    required this.end,
    required this.amount,
    required this.currencyCode,
    required this.currencySymbol,
    this.notes,
  });

  factory BudgetLimit.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    return BudgetLimit(
      id: json['id'] as String,
      budgetId: attrs['budget_id']?.toString() ?? '',
      start: _parseDate(attrs['start']) ?? DateTime.now(),
      end: _parseDate(attrs['end']) ?? DateTime.now(),
      amount: double.tryParse(attrs['amount']?.toString() ?? '0') ?? 0.0,
      currencyCode: attrs['currency_code'] as String? ?? 'EUR',
      currencySymbol: attrs['currency_symbol'] as String? ?? '€',
      notes: attrs['notes'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class BudgetInput {
  final String name;
  final bool active;
  final String? notes;
  final AutoBudgetType autoBudgetType;
  final double? autoBudgetAmount;
  final AutoBudgetPeriod? autoBudgetPeriod;
  final String currencyCode;

  const BudgetInput({
    required this.name,
    this.active = true,
    this.notes,
    this.autoBudgetType = AutoBudgetType.none,
    this.autoBudgetAmount,
    this.autoBudgetPeriod,
    required this.currencyCode,
  });

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      'name': name,
      'active': active,
      'auto_budget_type': autoBudgetType.apiValue,
    };

    final trimmedNotes = notes?.trim();
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      body['notes'] = trimmedNotes;
    }

    if (autoBudgetType != AutoBudgetType.none) {
      final amount = autoBudgetAmount ?? 0;
      body['auto_budget_amount'] = amount.toStringAsFixed(2);
      body['auto_budget_period'] =
          (autoBudgetPeriod ?? AutoBudgetPeriod.monthly).apiValue;
      body['auto_budget_currency_code'] = currencyCode;
    }

    return body;
  }
}

class BudgetLimitInput {
  final DateTime start;
  final DateTime end;
  final double amount;
  final String currencyCode;
  final String? notes;

  const BudgetLimitInput({
    required this.start,
    required this.end,
    required this.amount,
    required this.currencyCode,
    this.notes,
  });

  static String formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      'start': formatDate(start),
      'end': formatDate(end),
      'amount': amount.toStringAsFixed(2),
      'currency_code': currencyCode,
    };

    final trimmedNotes = notes?.trim();
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      body['notes'] = trimmedNotes;
    }

    return body;
  }
}
