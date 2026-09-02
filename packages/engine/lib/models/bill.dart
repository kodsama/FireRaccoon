import 'firefly_date.dart';

enum BillRepeatFrequency {
  weekly('weekly'),
  monthly('monthly'),
  quarterly('quarterly'),
  halfYear('half-year'),
  yearly('yearly');

  const BillRepeatFrequency(this.apiValue);

  final String apiValue;

  static BillRepeatFrequency fromApi(String? value) {
    return BillRepeatFrequency.values.firstWhere(
      (f) => f.apiValue == value,
      orElse: () => BillRepeatFrequency.monthly,
    );
  }
}

class Bill {
  final String id;
  final String name;
  final double amountMin;
  final double amountMax;
  final double amountAvg;
  final String currencyCode;
  final String currencySymbol;
  final DateTime date;
  final DateTime? endDate;
  final DateTime? extensionDate;
  final BillRepeatFrequency repeatFrequency;
  final int skip;
  final bool active;
  final String? notes;
  final String? objectGroupTitle;

  const Bill({
    required this.id,
    required this.name,
    required this.amountMin,
    required this.amountMax,
    required this.amountAvg,
    required this.currencyCode,
    required this.currencySymbol,
    required this.date,
    this.endDate,
    this.extensionDate,
    required this.repeatFrequency,
    this.skip = 0,
    this.active = true,
    this.notes,
    this.objectGroupTitle,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};

    return Bill(
      id: json['id'] as String,
      name: attrs['name'] as String? ?? 'Unnamed',
      amountMin: _parseAmount(attrs['amount_min']),
      amountMax: _parseAmount(attrs['amount_max']),
      amountAvg: _parseAmount(attrs['amount_avg']),
      currencyCode: attrs['currency_code'] as String? ?? 'EUR',
      currencySymbol: attrs['currency_symbol'] as String? ?? '€',
      date: parseFireflyDate(attrs['date']) ?? DateTime.now(),
      endDate: parseFireflyDate(attrs['end_date']),
      extensionDate: parseFireflyDate(attrs['extension_date']),
      repeatFrequency: BillRepeatFrequency.fromApi(
        attrs['repeat_freq'] as String?,
      ),
      skip: attrs['skip'] as int? ?? 0,
      active: attrs['active'] as bool? ?? true,
      notes: attrs['notes'] as String?,
      objectGroupTitle: attrs['object_group_title'] as String?,
    );
  }

  static double _parseAmount(dynamic value) {
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }
}

class BillInput {
  final String name;
  final double amountMin;
  final double amountMax;
  final String currencyCode;
  final DateTime date;
  final BillRepeatFrequency repeatFrequency;
  final int skip;
  final bool active;
  final DateTime? endDate;
  final DateTime? extensionDate;
  final String? notes;
  final String? objectGroupTitle;

  const BillInput({
    required this.name,
    required this.amountMin,
    required this.amountMax,
    required this.currencyCode,
    required this.date,
    required this.repeatFrequency,
    this.skip = 0,
    this.active = true,
    this.endDate,
    this.extensionDate,
    this.notes,
    this.objectGroupTitle,
  });

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      'name': name,
      'amount_min': amountMin.toStringAsFixed(2),
      'amount_max': amountMax.toStringAsFixed(2),
      'currency_code': currencyCode,
      'date': _formatDate(date),
      'repeat_freq': repeatFrequency.apiValue,
      'skip': skip,
      'active': active,
    };

    final trimmedNotes = notes?.trim();
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      body['notes'] = trimmedNotes;
    }

    final trimmedGroup = objectGroupTitle?.trim();
    if (trimmedGroup != null && trimmedGroup.isNotEmpty) {
      body['object_group_title'] = trimmedGroup;
    }

    if (endDate != null) {
      body['end_date'] = _formatDate(endDate!);
    }
    if (extensionDate != null) {
      body['extension_date'] = _formatDate(extensionDate!);
    }

    return body;
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
