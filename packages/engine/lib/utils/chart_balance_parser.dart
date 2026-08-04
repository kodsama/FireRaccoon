/// Parses Firefly III `GET /api/v1/chart/balance/balance` responses.
Map<String, List<double>> parseChartBalanceHistories(Object? body) {
  final datasets = _datasetsFromBody(body);
  final histories = <String, List<double>>{};

  for (final dataset in datasets) {
    final label = dataset['label'] as String?;
    final entries = dataset['entries'];
    if (label == null || label.isEmpty || entries is! Map) continue;

    final points =
        entries.entries
            .map(
              (entry) => MapEntry(
                entry.key.toString(),
                double.tryParse(entry.value.toString()) ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    if (points.isEmpty) continue;
    histories[label] = points.map((point) => point.value).toList();
  }

  return histories;
}

List<Map<String, dynamic>> _datasetsFromBody(Object? body) {
  if (body is List) {
    return body.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
  if (body is Map) {
    final data = body['data'];
    if (data is List) {
      return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
  }
  return const [];
}
