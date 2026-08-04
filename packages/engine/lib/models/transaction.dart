class Transaction {
  final String id;
  final String type; // 'withdrawal', 'deposit', 'transfer'
  final DateTime date;
  final double amount;
  final String description;
  final String sourceName;
  final String destinationName;
  final String categoryName;
  final String currencySymbol;
  final String currencyCode;
  final double? foreignAmount;
  final String? foreignCurrencySymbol;
  final String? foreignCurrencyCode;
  final String? sourceId;
  final String? destinationId;
  final String? categoryId;
  final String? budgetId;
  final String? budgetName;
  final String? notes;
  final List<String> tags;
  final String? billId;
  final String? billName;
  final String? piggyBankId;
  final String? piggyBankName;
  final DateTime? interestDate;
  final String? groupTitle;
  final List<Transaction> splits;
  final bool reconciled;

  Transaction({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    required this.description,
    required this.sourceName,
    required this.destinationName,
    required this.categoryName,
    required this.currencySymbol,
    required this.currencyCode,
    this.foreignAmount,
    this.foreignCurrencySymbol,
    this.foreignCurrencyCode,
    this.sourceId,
    this.destinationId,
    this.categoryId,
    this.budgetId,
    this.budgetName,
    this.notes,
    this.tags = const [],
    this.billId,
    this.billName,
    this.piggyBankId,
    this.piggyBankName,
    this.interestDate,
    this.groupTitle,
    this.splits = const [],
    this.reconciled = false,
  });

  bool get isSplitGroup => splits.length > 1;

  /// Sum of all split amounts (equals [amount] for a single-line journal).
  /// Memoized: the model is immutable and this is read in tight loops.
  late final double totalAmount = resolvedSplits().fold(
    0.0,
    (sum, split) => sum + split.amount,
  );

  /// True when every split in the journal is reconciled.
  bool get isReconciled => resolvedSplits().every((split) => split.reconciled);

  /// True when at least one split is not reconciled.
  bool get hasUnreconciledSplits =>
      resolvedSplits().any((split) => !split.reconciled);

  /// True when some but not all splits are reconciled.
  bool get isPartiallyReconciled =>
      !isReconciled && resolvedSplits().any((split) => split.reconciled);

  /// Returns a copy with [value] applied to every split in the journal.
  Transaction withReconciled(bool value) {
    final updatedSplits = splits.isNotEmpty
        ? splits.map((split) => split.copyWith(reconciled: value)).toList()
        : const <Transaction>[];
    return copyWith(reconciled: value, splits: updatedSplits);
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>;
    final txs = attrs['transactions'] as List<dynamic>? ?? [];
    final groupTitle = attrs['group_title'] as String?;
    final journalId = json['id'] as String;

    if (txs.isEmpty) {
      return Transaction(
        id: journalId,
        type: 'withdrawal',
        date: DateTime.now(),
        amount: 0,
        description: 'No Description',
        sourceName: 'Unknown',
        destinationName: 'Unknown',
        categoryName: 'Uncategorized',
        currencySymbol: '€',
        currencyCode: 'EUR',
        groupTitle: groupTitle,
      );
    }

    final parsed = txs
        .map(
          (tx) => _fromSplitMap(
            journalId: journalId,
            groupTitle: groupTitle,
            tx: tx as Map<String, dynamic>,
          ),
        )
        .toList();

    if (parsed.length == 1) {
      return parsed.first;
    }

    return parsed.first.copyWith(splits: parsed, groupTitle: groupTitle);
  }

  static Transaction _fromSplitMap({
    required String journalId,
    required String? groupTitle,
    required Map<String, dynamic> tx,
  }) {
    final rawTags = tx['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return Transaction(
      id: journalId,
      type: tx['type'] as String? ?? 'withdrawal',
      // Firefly returns offset-aware timestamps; convert to local time so
      // calendar-field reads (day grouping, future checks) match the user's
      // local day instead of the UTC instant.
      date: tx['date'] != null
          ? (DateTime.tryParse(tx['date'].toString()) ?? DateTime.now())
                .toLocal()
          : DateTime.now(),
      amount: double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0,
      description: tx['description'] as String? ?? 'No Description',
      sourceName: tx['source_name'] as String? ?? 'Unknown',
      destinationName: tx['destination_name'] as String? ?? 'Unknown',
      categoryName: (tx['category_name'] as String? ?? '').trim(),
      currencySymbol: tx['currency_symbol'] as String? ?? '€',
      currencyCode: tx['currency_code'] as String? ?? 'EUR',
      foreignAmount: tx['foreign_amount'] != null
          ? double.tryParse(tx['foreign_amount'].toString())
          : null,
      foreignCurrencySymbol: tx['foreign_currency_symbol'] as String?,
      foreignCurrencyCode: tx['foreign_currency_code'] as String?,
      sourceId: tx['source_id']?.toString(),
      destinationId: tx['destination_id']?.toString(),
      categoryId: tx['category_id']?.toString(),
      budgetId: tx['budget_id']?.toString(),
      budgetName: tx['budget_name'] as String?,
      notes: tx['notes'] as String?,
      tags: tags,
      billId: (tx['bill_id'] ?? tx['subscription_id'])?.toString(),
      billName: (tx['bill_name'] ?? tx['subscription_name']) as String?,
      piggyBankId: tx['piggy_bank_id']?.toString(),
      piggyBankName: tx['piggy_bank_name'] as String?,
      interestDate: tx['interest_date'] != null
          ? DateTime.tryParse(tx['interest_date'].toString())
          : null,
      groupTitle: groupTitle,
      reconciled: _parseBool(tx['reconciled']),
    );
  }

  static bool _parseBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  Transaction copyWith({
    String? id,
    String? type,
    DateTime? date,
    double? amount,
    String? description,
    String? sourceName,
    String? destinationName,
    String? categoryName,
    String? currencySymbol,
    String? currencyCode,
    double? foreignAmount,
    String? foreignCurrencySymbol,
    String? foreignCurrencyCode,
    String? sourceId,
    String? destinationId,
    String? categoryId,
    String? budgetId,
    String? budgetName,
    String? notes,
    List<String>? tags,
    String? billId,
    String? billName,
    String? piggyBankId,
    String? piggyBankName,
    DateTime? interestDate,
    String? groupTitle,
    List<Transaction>? splits,
    bool? reconciled,
    bool clearForeignAmount = false,
    bool clearBudget = false,
    bool clearBill = false,
    bool clearPiggyBank = false,
    bool clearInterestDate = false,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      sourceName: sourceName ?? this.sourceName,
      destinationName: destinationName ?? this.destinationName,
      categoryName: categoryName ?? this.categoryName,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      foreignAmount: clearForeignAmount
          ? null
          : (foreignAmount ?? this.foreignAmount),
      foreignCurrencySymbol: clearForeignAmount
          ? null
          : (foreignCurrencySymbol ?? this.foreignCurrencySymbol),
      foreignCurrencyCode: clearForeignAmount
          ? null
          : (foreignCurrencyCode ?? this.foreignCurrencyCode),
      sourceId: sourceId ?? this.sourceId,
      destinationId: destinationId ?? this.destinationId,
      categoryId: categoryId ?? this.categoryId,
      budgetId: clearBudget ? null : (budgetId ?? this.budgetId),
      budgetName: clearBudget ? null : (budgetName ?? this.budgetName),
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      billId: clearBill ? null : (billId ?? this.billId),
      billName: clearBill ? null : (billName ?? this.billName),
      piggyBankId: clearPiggyBank ? null : (piggyBankId ?? this.piggyBankId),
      piggyBankName: clearPiggyBank
          ? null
          : (piggyBankName ?? this.piggyBankName),
      interestDate: clearInterestDate
          ? null
          : (interestDate ?? this.interestDate),
      groupTitle: groupTitle ?? this.groupTitle,
      splits: splits ?? this.splits,
      reconciled: reconciled ?? this.reconciled,
    );
  }

  /// The journal lines: [splits] for a split group, otherwise the
  /// transaction itself. Memoized to avoid allocating in hot loops.
  late final List<Transaction> _resolvedSplits = splits.isNotEmpty
      ? splits
      : List.unmodifiable(<Transaction>[this]);

  List<Transaction> resolvedSplits() => _resolvedSplits;

  Map<String, dynamic> toApiPayload({bool isUpdate = false}) {
    final items = resolvedSplits()
        .map((split) => split.toSplitJson(isUpdate: isUpdate))
        .toList();
    final payload = <String, dynamic>{'transactions': items};
    if (items.length > 1) {
      payload['group_title'] = groupTitle ?? description;
    }
    return payload;
  }

  /// ISO-8601 with an explicit UTC offset: local DateTimes serialize without
  /// one, which lets the server reinterpret them in its own timezone.
  static String formatApiDateTime(DateTime date) {
    if (date.isUtc) return date.toIso8601String();
    final offset = date.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final hours = abs.inHours.toString().padLeft(2, '0');
    final minutes = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return '${date.toIso8601String()}$sign$hours:$minutes';
  }

  Map<String, dynamic> toSplitJson({bool isUpdate = false}) {
    final omitFinancials = isUpdate && reconciled;
    final split = <String, dynamic>{
      'type': type,
      'date': formatApiDateTime(date),
      'description': description,
    };

    if (!omitFinancials) {
      split['amount'] = amount.toStringAsFixed(2);
      split['currency_code'] = currencyCode;
      if (sourceId != null && sourceId!.isNotEmpty) {
        split['source_id'] = sourceId;
      }
      if (sourceName.isNotEmpty) split['source_name'] = sourceName;
      if (destinationId != null && destinationId!.isNotEmpty) {
        split['destination_id'] = destinationId;
      }
      if (destinationName.isNotEmpty) {
        split['destination_name'] = destinationName;
      }
      if (foreignAmount != null) {
        split['foreign_amount'] = foreignAmount!.toStringAsFixed(2);
        if (foreignCurrencyCode != null && foreignCurrencyCode!.isNotEmpty) {
          split['foreign_currency_code'] = foreignCurrencyCode;
        }
      }
    }

    if (categoryId != null && categoryId!.isNotEmpty) {
      split['category_id'] = categoryId;
    }
    if (categoryName.isNotEmpty) split['category_name'] = categoryName;
    if (budgetId != null && budgetId!.isNotEmpty) {
      split['budget_id'] = budgetId;
    }
    if (budgetName != null && budgetName!.isNotEmpty) {
      split['budget_name'] = budgetName;
    }
    if (notes != null && notes!.isNotEmpty) split['notes'] = notes;
    if (tags.isNotEmpty) split['tags'] = tags;
    if (billId != null && billId!.isNotEmpty) split['bill_id'] = billId;
    if (piggyBankId != null && piggyBankId!.isNotEmpty) {
      split['piggy_bank_id'] = piggyBankId;
    }
    if (interestDate != null) {
      split['interest_date'] = interestDate!.toIso8601String().split('T').first;
    }
    split['reconciled'] = reconciled;

    return split;
  }
}
