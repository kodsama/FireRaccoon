class RouteQuery {
  static const searchKey = 'q';

  /// [params] values are a string, or an iterable of strings for a key
  /// that repeats (`tag=a&tag=b`); empty ones are left out.
  static String build(String path, Map<String, Object?> params) {
    final filtered = <String, Object>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value is String && value.isNotEmpty) {
        filtered[entry.key] = value;
      } else if (value is Iterable<String>) {
        final values = value.where((v) => v.isNotEmpty).toList();
        if (values.isNotEmpty) filtered[entry.key] = values;
      }
    }
    if (filtered.isEmpty) return path;
    return Uri(path: path, queryParameters: filtered).toString();
  }

  /// Every non-empty value of a key that may repeat, in link order.
  static Set<String> values(Uri uri, String key) => {
    for (final value in uri.queryParametersAll[key] ?? const <String>[])
      if (value.isNotEmpty) value,
  };

  static String? param(Uri uri, String key) {
    final value = uri.queryParameters[key];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static T enumFrom<T extends Enum>(
    Uri uri,
    String key,
    List<T> values,
    T fallback,
  ) {
    final raw = uri.queryParameters[key];
    if (raw == null) return fallback;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }

  static String? searchFrom(Uri uri) => param(uri, searchKey);

  static String withSearch(Uri uri, String? query) {
    final params = Map<String, Object?>.from(uri.queryParametersAll);
    final trimmed = query?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      params.remove(searchKey);
    } else {
      params[searchKey] = trimmed;
    }
    return build(uri.path, params);
  }

  static String preserveSearch(Uri current, String destination) {
    final q = searchFrom(current);
    if (q == null) return destination;
    final dest = Uri.parse(destination);
    if (dest.queryParameters.containsKey(searchKey)) return destination;
    final params = Map<String, Object?>.from(dest.queryParametersAll);
    params[searchKey] = q;
    return build(dest.path, params);
  }
}
