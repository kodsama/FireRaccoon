enum LiabilityType {
  debt('debt'),
  loan('loan'),
  mortgage('mortgage');

  const LiabilityType(this.apiValue);
  final String apiValue;
}

enum LiabilityDirection {
  credit('credit'),
  debit('debit');

  const LiabilityDirection(this.apiValue);
  final String apiValue;
}

enum InterestPeriod {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  quarterly('quarterly'),
  halfYear('half-year'),
  yearly('yearly');

  const InterestPeriod(this.apiValue);
  final String apiValue;
}

class LiabilityInput {
  final String name;
  final String currencyCode;
  final LiabilityType liabilityType;
  final LiabilityDirection liabilityDirection;
  final double? amountOwed;
  final DateTime? startDate;
  final double? interest;
  final InterestPeriod? interestPeriod;
  final bool includeNetWorth;
  final String? iban;
  final String? bic;
  final String? accountNumber;
  final String? notes;

  const LiabilityInput({
    required this.name,
    required this.currencyCode,
    required this.liabilityType,
    required this.liabilityDirection,
    this.amountOwed,
    this.startDate,
    this.interest,
    this.interestPeriod,
    this.includeNetWorth = true,
    this.iban,
    this.bic,
    this.accountNumber,
    this.notes,
  });

  Map<String, dynamic> toCreateJson() {
    final body = <String, dynamic>{
      'name': name,
      'type': 'liability',
      'currency_code': currencyCode,
      'liability_type': liabilityType.apiValue,
      'liability_direction': liabilityDirection.apiValue,
      'include_net_worth': includeNetWorth,
    };

    if (amountOwed != null) {
      body['opening_balance'] = amountOwed!.toStringAsFixed(2);
    }
    if (startDate != null) {
      body['opening_balance_date'] = _formatDate(startDate!);
    }
    if (interest != null) {
      body['interest'] = interest!.toString();
    }
    if (interestPeriod != null) {
      body['interest_period'] = interestPeriod!.apiValue;
    }

    _addIfNotEmpty(body, 'iban', iban);
    _addIfNotEmpty(body, 'bic', bic);
    _addIfNotEmpty(body, 'account_number', accountNumber);
    _addIfNotEmpty(body, 'notes', notes);

    return body;
  }

  static void _addIfNotEmpty(
    Map<String, dynamic> body,
    String key,
    String? value,
  ) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      body[key] = trimmed;
    }
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
