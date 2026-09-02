import 'firefly_date.dart';

class PiggyBankAccountLink {
  final String accountId;
  final String name;
  final double currentAmount;

  const PiggyBankAccountLink({
    required this.accountId,
    required this.name,
    required this.currentAmount,
  });

  factory PiggyBankAccountLink.fromJson(Map<String, dynamic> json) {
    return PiggyBankAccountLink(
      accountId: json['account_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      currentAmount:
          double.tryParse(json['current_amount']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class PiggyBank {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final int? percentage;
  final double? leftToSave;
  final String currencyCode;
  final String currencySymbol;
  final DateTime startDate;
  final DateTime? targetDate;
  final bool active;
  final String? notes;
  final String? objectGroupTitle;
  final List<PiggyBankAccountLink> accounts;

  const PiggyBank({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.percentage,
    this.leftToSave,
    required this.currencyCode,
    required this.currencySymbol,
    required this.startDate,
    this.targetDate,
    this.active = true,
    this.notes,
    this.objectGroupTitle,
    this.accounts = const [],
  });

  factory PiggyBank.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    final accountList = attrs['accounts'] as List<dynamic>? ?? [];

    return PiggyBank(
      id: json['id'] as String,
      name: attrs['name'] as String? ?? 'Unnamed',
      targetAmount:
          double.tryParse(attrs['target_amount']?.toString() ?? '0') ?? 0.0,
      currentAmount:
          double.tryParse(attrs['current_amount']?.toString() ?? '0') ?? 0.0,
      percentage: attrs['percentage'] as int?,
      leftToSave: _parseNullableAmount(attrs['left_to_save']),
      currencyCode: attrs['currency_code'] as String? ?? 'EUR',
      currencySymbol: attrs['currency_symbol'] as String? ?? '€',
      startDate: parseFireflyDate(attrs['start_date']) ?? DateTime.now(),
      targetDate: parseFireflyDate(attrs['target_date']),
      active: attrs['active'] as bool? ?? true,
      notes: attrs['notes'] as String?,
      objectGroupTitle: attrs['object_group_title'] as String?,
      accounts: accountList
          .map((e) => PiggyBankAccountLink.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static double? _parseNullableAmount(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}

class PiggyBankInput {
  final String name;
  final double targetAmount;
  final String currencyCode;
  final List<String> accountIds;
  final DateTime startDate;
  final DateTime? targetDate;
  final String? notes;
  final String? objectGroupTitle;

  const PiggyBankInput({
    required this.name,
    required this.targetAmount,
    required this.currencyCode,
    required this.accountIds,
    required this.startDate,
    this.targetDate,
    this.notes,
    this.objectGroupTitle,
  });

  Map<String, dynamic> toCreateJson() => _toJson(includeCurrency: true);

  Map<String, dynamic> toUpdateJson() => _toJson(includeCurrency: false);

  Map<String, dynamic> _toJson({required bool includeCurrency}) {
    final body = <String, dynamic>{
      'name': name,
      'target_amount': targetAmount.toStringAsFixed(2),
      'start_date': _formatDate(startDate),
      'accounts': accountIds.map((id) => {'account_id': id}).toList(),
    };

    if (includeCurrency) {
      body['transaction_currency_code'] = currencyCode;
    }

    if (targetDate != null) {
      body['target_date'] = _formatDate(targetDate!);
    }

    final trimmedNotes = notes?.trim();
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      body['notes'] = trimmedNotes;
    }

    final trimmedGroup = objectGroupTitle?.trim();
    if (trimmedGroup != null && trimmedGroup.isNotEmpty) {
      body['object_group_title'] = trimmedGroup;
    }

    return body;
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
