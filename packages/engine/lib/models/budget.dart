import 'firefly_date.dart';
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

  /// What Firefly says the auto-budget is denominated in, or null when it says
  /// nothing, which is what it does for a budget that never had one set.
  ///
  /// Not defaulted. These used to fall back to the euro, so on a ledger whose
  /// primary currency is anything else every budget read as euro while the
  /// figures were in the ledger's own currency. A caller that has to show one
  /// falls back to the primary currency, which is what the amount is in.
  final String? currencySymbol;
  final String? currencyCode;

  Budget({
    required this.id,
    required this.name,
    required this.active,
    this.notes,
    required this.spent,
    required this.autoBudgetAmount,
    this.autoBudgetType = AutoBudgetType.none,
    this.autoBudgetPeriod,
    this.currencySymbol,
    this.currencyCode,
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
      currencySymbol: attrs['auto_budget_currency_symbol'] as String?,
      currencyCode: attrs['auto_budget_currency_code'] as String?,
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
      start: parseFireflyDate(attrs['start']) ?? DateTime.now(),
      end: parseFireflyDate(attrs['end']) ?? DateTime.now(),
      amount: double.tryParse(attrs['amount']?.toString() ?? '0') ?? 0.0,
      currencyCode: attrs['currency_code'] as String? ?? 'EUR',
      currencySymbol: attrs['currency_symbol'] as String? ?? '€',
      notes: attrs['notes'] as String?,
    );
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

  /// Firefly's id for [currencyCode], when the caller could resolve one.
  ///
  /// Firefly 6.6.6 accepts `auto_budget_currency_code` and stores nothing from
  /// it. The id is the field it actually reads, so a redenomination only lands
  /// when this is known.
  final String? currencyId;

  const BudgetInput({
    required this.name,
    this.active = true,
    this.notes,
    this.autoBudgetType = AutoBudgetType.none,
    this.autoBudgetAmount,
    this.autoBudgetPeriod,
    required this.currencyCode,
    this.currencyId,
  });

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{'name': name, 'active': active};

    final trimmedNotes = notes?.trim();
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      body['notes'] = trimmedNotes;
    }

    // Auto-budget keys are omitted entirely when there is nothing to set.
    // Firefly (6.6.6) rejects every attempt to send an empty one: `none` alone
    // is "The amount is required", `none` with 0 is "must be more than zero",
    // and null is "invalid auto budget type". Omitting the keys is the only
    // accepted shape, and it leaves an existing auto-budget untouched, which is
    // what a partial update should do. Clearing one is not expressible here.
    if (autoBudgetType != AutoBudgetType.none) {
      final amount = autoBudgetAmount ?? 0;
      body['auto_budget_type'] = autoBudgetType.apiValue;
      body['auto_budget_amount'] = amount.toStringAsFixed(2);
      body['auto_budget_period'] =
          (autoBudgetPeriod ?? AutoBudgetPeriod.monthly).apiValue;
      body['auto_budget_currency_code'] = currencyCode;
      if (currencyId != null && currencyId!.isNotEmpty) {
        body['auto_budget_currency_id'] = currencyId;
      }
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
