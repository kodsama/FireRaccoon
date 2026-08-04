String _decodeHtmlEntities(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
}

class FireflyCurrency {
  final String id;
  final String code;
  final String name;
  final String symbol;
  final bool enabled;

  const FireflyCurrency({
    required this.id,
    required this.code,
    required this.name,
    required this.symbol,
    this.enabled = true,
  });

  factory FireflyCurrency.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>;
    return FireflyCurrency(
      id: json['id'] as String,
      code: _decodeHtmlEntities(attrs['code'] as String? ?? 'EUR'),
      name: _decodeHtmlEntities(attrs['name'] as String? ?? 'Euro'),
      symbol: _decodeHtmlEntities(attrs['symbol'] as String? ?? '€'),
      enabled: attrs['enabled'] as bool? ?? true,
    );
  }
}
