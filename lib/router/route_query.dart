class RouteQuery {
  static const searchKey = 'q';

  static String build(String path, Map<String, String?> params) {
    final filtered = <String, String>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) {
        filtered[entry.key] = value;
      }
    }
    if (filtered.isEmpty) return path;
    return Uri(path: path, queryParameters: filtered).toString();
  }

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
    final params = Map<String, String>.from(uri.queryParameters);
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
    final params = Map<String, String>.from(dest.queryParameters);
    params[searchKey] = q;
    return build(dest.path, params);
  }
}
