enum RecurrenceTransactionType {
  withdrawal('withdrawal'),
  deposit('deposit'),
  transfer('transfer');

  const RecurrenceTransactionType(this.apiValue);

  final String apiValue;

  static RecurrenceTransactionType fromApi(String? value) {
    return RecurrenceTransactionType.values.firstWhere(
      (t) => t.apiValue == value,
      orElse: () => RecurrenceTransactionType.withdrawal,
    );
  }
}

enum RecurrenceRepetitionType {
  daily('daily'),
  weekly('weekly'),
  ndom('ndom'),
  monthly('monthly'),
  yearly('yearly');

  const RecurrenceRepetitionType(this.apiValue);

  final String apiValue;

  static RecurrenceRepetitionType fromApi(String? value) {
    return RecurrenceRepetitionType.values.firstWhere(
      (t) => t.apiValue == value,
      orElse: () => RecurrenceRepetitionType.monthly,
    );
  }
}

enum RecurrenceWeekendMode {
  createAnyway(1),
  skipWeekend(2),
  previousFriday(3),
  nextMonday(4);

  const RecurrenceWeekendMode(this.apiValue);

  final int apiValue;

  static RecurrenceWeekendMode fromApi(int? value) {
    return RecurrenceWeekendMode.values.firstWhere(
      (m) => m.apiValue == value,
      orElse: () => RecurrenceWeekendMode.createAnyway,
    );
  }
}

enum RecurrenceEndMode { forever, untilDate, repetitionCount }

class RecurrenceRepetition {
  final String? id;
  final RecurrenceRepetitionType type;
  final String moment;
  final int skip;
  final RecurrenceWeekendMode weekend;
  final String? description;

  const RecurrenceRepetition({
    this.id,
    required this.type,
    required this.moment,
    this.skip = 0,
    this.weekend = RecurrenceWeekendMode.createAnyway,
    this.description,
  });

  factory RecurrenceRepetition.fromJson(Map<String, dynamic> json) {
    return RecurrenceRepetition(
      id: json['id']?.toString(),
      type: RecurrenceRepetitionType.fromApi(json['type'] as String?),
      moment: json['moment'] as String? ?? '',
      skip: json['skip'] as int? ?? 0,
      weekend: RecurrenceWeekendMode.fromApi(json['weekend'] as int?),
      description: json['description'] as String?,
    );
  }
}

class RecurrenceTransactionLine {
  final String? id;
  final String description;
  final double amount;
  final String currencyCode;
  final String? currencySymbol;
  final double? foreignAmount;
  final String? foreignCurrencyCode;
  final String? sourceId;
  final String? sourceName;
  final String? destinationId;
  final String? destinationName;
  final String? budgetId;
  final String? budgetName;
  final String? categoryId;
  final String? categoryName;
  final String? billId;
  final String? billName;
  final List<String> tags;

  const RecurrenceTransactionLine({
    this.id,
    required this.description,
    required this.amount,
    required this.currencyCode,
    this.currencySymbol,
    this.foreignAmount,
    this.foreignCurrencyCode,
    this.sourceId,
    this.sourceName,
    this.destinationId,
    this.destinationName,
    this.budgetId,
    this.budgetName,
    this.categoryId,
    this.categoryName,
    this.billId,
    this.billName,
    this.tags = const [],
  });

  factory RecurrenceTransactionLine.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    return RecurrenceTransactionLine(
      id: json['id']?.toString(),
      description: json['description'] as String? ?? '',
      amount: _parseAmount(json['amount']),
      currencyCode: json['currency_code'] as String? ?? 'EUR',
      currencySymbol: json['currency_symbol'] as String?,
      foreignAmount: json['foreign_amount'] == null
          ? null
          : _parseAmount(json['foreign_amount']),
      foreignCurrencyCode: json['foreign_currency_code'] as String?,
      sourceId: json['source_id']?.toString(),
      sourceName: json['source_name'] as String?,
      destinationId: json['destination_id']?.toString(),
      destinationName: json['destination_name'] as String?,
      budgetId: json['budget_id']?.toString(),
      budgetName: json['budget_name'] as String?,
      categoryId: json['category_id']?.toString(),
      categoryName: json['category_name'] as String?,
      billId: (json['bill_id'] ?? json['subscription_id'])?.toString(),
      billName: (json['bill_name'] ?? json['subscription_name']) as String?,
      tags: tagsRaw is List
          ? tagsRaw.map((t) => t.toString()).toList()
          : const [],
    );
  }

  static double _parseAmount(dynamic value) {
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }
}

class Recurrence {
  final String id;
  final RecurrenceTransactionType type;
  final String title;
  final String? description;
  final DateTime firstDate;
  final DateTime? latestDate;
  final DateTime? repeatUntil;
  final int? nrOfRepetitions;
  final bool applyRules;
  final bool active;
  final String? notes;
  final List<RecurrenceRepetition> repetitions;
  final List<RecurrenceTransactionLine> transactions;

  const Recurrence({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.firstDate,
    this.latestDate,
    this.repeatUntil,
    this.nrOfRepetitions,
    this.applyRules = true,
    this.active = true,
    this.notes,
    this.repetitions = const [],
    this.transactions = const [],
  });

  RecurrenceRepetition? get primaryRepetition =>
      repetitions.isEmpty ? null : repetitions.first;

  RecurrenceTransactionLine? get primaryTransaction =>
      transactions.isEmpty ? null : transactions.first;

  factory Recurrence.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    final repetitionsRaw = attrs['repetitions'] as List<dynamic>? ?? [];
    final transactionsRaw = attrs['transactions'] as List<dynamic>? ?? [];

    return Recurrence(
      id: json['id'] as String,
      type: RecurrenceTransactionType.fromApi(attrs['type'] as String?),
      title: attrs['title'] as String? ?? 'Unnamed',
      description: attrs['description'] as String?,
      firstDate: _parseDate(attrs['first_date']) ?? DateTime.now(),
      latestDate: _parseDate(attrs['latest_date']),
      repeatUntil: _parseDate(attrs['repeat_until']),
      nrOfRepetitions: attrs['nr_of_repetitions'] as int?,
      applyRules: attrs['apply_rules'] as bool? ?? true,
      active: attrs['active'] as bool? ?? true,
      notes: attrs['notes'] as String?,
      repetitions: repetitionsRaw
          .map((r) => RecurrenceRepetition.fromJson(r as Map<String, dynamic>))
          .toList(),
      transactions: transactionsRaw
          .map(
            (t) =>
                RecurrenceTransactionLine.fromJson(t as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class RecurrenceTransactionInput {
  final String? id;
  final String description;
  final double amount;
  final String currencyCode;
  final double? foreignAmount;
  final String? foreignCurrencyCode;
  final String sourceId;
  final String destinationId;
  final String? budgetId;
  final String? categoryId;
  final String? billId;
  final List<String> tags;

  const RecurrenceTransactionInput({
    this.id,
    required this.description,
    required this.amount,
    required this.currencyCode,
    this.foreignAmount,
    this.foreignCurrencyCode,
    required this.sourceId,
    required this.destinationId,
    this.budgetId,
    this.categoryId,
    this.billId,
    this.tags = const [],
  });

  Map<String, dynamic> toJson({required bool isUpdate}) {
    final body = <String, dynamic>{
      'description': description,
      'amount': amount.toStringAsFixed(2),
      'currency_code': currencyCode,
      'source_id': sourceId,
      'destination_id': destinationId,
    };

    if (isUpdate && id != null) {
      body['id'] = id;
    }
    if (foreignAmount != null && foreignCurrencyCode != null) {
      body['foreign_amount'] = foreignAmount!.toStringAsFixed(2);
      body['foreign_currency_code'] = foreignCurrencyCode;
    }
    if (budgetId != null && budgetId!.isNotEmpty) {
      body['budget_id'] = budgetId;
    }
    if (categoryId != null && categoryId!.isNotEmpty) {
      body['category_id'] = categoryId;
    }
    if (billId != null && billId!.isNotEmpty) {
      body['bill_id'] = billId;
    }
    if (tags.isNotEmpty) {
      body['tags'] = tags;
    }

    return body;
  }
}

class RecurrenceRepetitionInput {
  final RecurrenceRepetitionType type;
  final String moment;
  final int skip;
  final RecurrenceWeekendMode weekend;

  const RecurrenceRepetitionInput({
    required this.type,
    required this.moment,
    this.skip = 0,
    this.weekend = RecurrenceWeekendMode.createAnyway,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.apiValue,
      'moment': moment,
      'skip': skip,
      'weekend': weekend.apiValue,
    };
  }

  static String momentForDate(RecurrenceRepetitionType type, DateTime date) {
    return switch (type) {
      RecurrenceRepetitionType.daily => '',
      RecurrenceRepetitionType.weekly => '${date.weekday}',
      RecurrenceRepetitionType.monthly => '${date.day}',
      RecurrenceRepetitionType.yearly => _formatDate(date),
      RecurrenceRepetitionType.ndom => '${_weekOfMonth(date)},${date.weekday}',
    };
  }

  static int _weekOfMonth(DateTime date) {
    return ((date.day - 1) ~/ 7) + 1;
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class RecurrenceInput {
  final RecurrenceTransactionType type;
  final String title;
  final String? description;
  final DateTime firstDate;
  final DateTime? repeatUntil;
  final int? nrOfRepetitions;
  final bool applyRules;
  final bool active;
  final String? notes;
  final List<RecurrenceRepetitionInput> repetitions;
  final List<RecurrenceTransactionInput> transactions;

  const RecurrenceInput({
    required this.type,
    required this.title,
    this.description,
    required this.firstDate,
    this.repeatUntil,
    this.nrOfRepetitions,
    this.applyRules = true,
    this.active = true,
    this.notes,
    required this.repetitions,
    required this.transactions,
  });

  Map<String, dynamic> toJson({required bool isUpdate}) {
    final body = <String, dynamic>{
      'title': title,
      'first_date': RecurrenceRepetitionInput._formatDate(firstDate),
      'repeat_until': repeatUntil == null
          ? null
          : RecurrenceRepetitionInput._formatDate(repeatUntil!),
      'apply_rules': applyRules,
      'active': active,
      'repetitions': repetitions.map((r) => r.toJson()).toList(),
      'transactions': transactions
          .map((t) => t.toJson(isUpdate: isUpdate))
          .toList(),
    };

    if (!isUpdate) {
      body['type'] = type.apiValue;
    }

    final trimmedDescription = description?.trim();
    if (trimmedDescription != null && trimmedDescription.isNotEmpty) {
      body['description'] = trimmedDescription;
    }

    final trimmedNotes = notes?.trim();
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      body['notes'] = trimmedNotes;
    }

    if (nrOfRepetitions != null) {
      body['nr_of_repetitions'] = nrOfRepetitions;
    }

    return body;
  }
}
