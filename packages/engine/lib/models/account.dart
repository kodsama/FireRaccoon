class Account {
  final String id;
  final String name;
  final String type; // 'asset', 'expense', 'revenue', 'liability'
  final String role; // 'defaultAsset', 'sharedAsset', 'savingAsset', 'ccAsset'
  final String? liabilityType; // 'loan', 'debt', 'mortgage', 'creditCard'
  final String? liabilityDirection; // 'credit', 'debit'
  final double currentBalance;
  final String currencySymbol;
  final String currencyCode;

  /// Whether [currencyCode] is the account's own setting or Firefly's fallback.
  ///
  /// An expense or revenue account is a counterparty label: any currency can
  /// flow through it, and most carry no currency of their own. Firefly still
  /// fills `currency_code` in for them, with the installation's primary
  /// currency, and says so only through `object_has_currency_setting`. Read
  /// without that flag, every counterparty looks like an account denominated in
  /// the primary currency.
  ///
  /// Absent from the payload means unknown, and unknown stays trusted: a
  /// version that does not send the flag should keep behaving as it did.
  final bool hasCurrencySetting;
  final String? iban;
  final String? bic;
  final String? accountNumber;
  final String? notes;
  final bool active;
  final bool includeNetWorth;
  final double? openingBalance;
  final DateTime? openingBalanceDate;
  final double? virtualBalance;
  final double? interest;
  final String? interestPeriod;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.role,
    this.liabilityType,
    this.liabilityDirection,
    required this.currentBalance,
    required this.currencySymbol,
    required this.currencyCode,
    this.hasCurrencySetting = true,
    this.iban,
    this.bic,
    this.accountNumber,
    this.notes,
    this.active = true,
    this.includeNetWorth = true,
    this.openingBalance,
    this.openingBalanceDate,
    this.virtualBalance,
    this.interest,
    this.interestPeriod,
  });

  bool get isLiability => type == 'liability';

  static String _normalizeType(String? raw) {
    return switch (raw) {
      'liabilities' => 'liability',
      _ => raw ?? 'asset',
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>;
    return Account(
      id: json['id'] as String,
      name: attrs['name'] as String? ?? 'Unknown Account',
      type: _normalizeType(attrs['type'] as String?),
      role: attrs['account_role'] as String? ?? 'defaultAsset',
      liabilityType: attrs['liability_type'] as String?,
      liabilityDirection: attrs['liability_direction'] as String?,
      currentBalance:
          double.tryParse(attrs['current_balance']?.toString() ?? '0') ?? 0.0,
      currencySymbol: attrs['currency_symbol'] as String? ?? '€',
      currencyCode: attrs['currency_code'] as String? ?? 'EUR',
      hasCurrencySetting: attrs['object_has_currency_setting'] as bool? ?? true,
      iban: attrs['iban'] as String?,
      bic: attrs['bic'] as String?,
      accountNumber: attrs['account_number'] as String?,
      notes: attrs['notes'] as String?,
      active: attrs['active'] as bool? ?? true,
      includeNetWorth: attrs['include_net_worth'] as bool? ?? true,
      openingBalance: double.tryParse(
        attrs['opening_balance']?.toString() ?? '',
      ),
      openingBalanceDate: attrs['opening_balance_date'] != null
          ? DateTime.tryParse(attrs['opening_balance_date'].toString())
          : null,
      virtualBalance: double.tryParse(
        attrs['virtual_balance']?.toString() ?? '',
      ),
      interest: double.tryParse(attrs['interest']?.toString() ?? ''),
      interestPeriod: attrs['interest_period'] as String?,
    );
  }

  Account copyWith({
    String? id,
    String? name,
    String? type,
    String? role,
    String? liabilityType,
    String? liabilityDirection,
    double? currentBalance,
    String? currencySymbol,
    String? currencyCode,
    bool? hasCurrencySetting,
    String? iban,
    String? bic,
    String? accountNumber,
    String? notes,
    bool? active,
    bool? includeNetWorth,
    double? openingBalance,
    DateTime? openingBalanceDate,
    double? virtualBalance,
    double? interest,
    String? interestPeriod,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      role: role ?? this.role,
      liabilityType: liabilityType ?? this.liabilityType,
      liabilityDirection: liabilityDirection ?? this.liabilityDirection,
      currentBalance: currentBalance ?? this.currentBalance,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      hasCurrencySetting: hasCurrencySetting ?? this.hasCurrencySetting,
      iban: iban ?? this.iban,
      bic: bic ?? this.bic,
      accountNumber: accountNumber ?? this.accountNumber,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      includeNetWorth: includeNetWorth ?? this.includeNetWorth,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalanceDate: openingBalanceDate ?? this.openingBalanceDate,
      virtualBalance: virtualBalance ?? this.virtualBalance,
      interest: interest ?? this.interest,
      interestPeriod: interestPeriod ?? this.interestPeriod,
    );
  }
}
