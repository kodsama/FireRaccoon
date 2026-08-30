import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:logging/logging.dart';

/// One retained line, kept so it can be read back inside the app.
///
/// Holds the pieces separately rather than one string so a reader can filter by
/// level without parsing its own output back.
final class LoggedRecord {
  const LoggedRecord({
    required this.time,
    required this.level,
    required this.loggerName,
    required this.message,
    this.error,
  });

  final DateTime time;
  final Level level;
  final String loggerName;

  /// Already redacted. Nothing unredacted is ever retained.
  final String message;

  /// The error's type, never the error itself: a thrown object can close over
  /// anything, including the token that was being sent when it threw.
  final String? error;

  /// Whether something failed, as opposed to something being worth noting.
  bool get isFailure => level >= Level.SEVERE;

  @override
  String toString() {
    final suffix = error == null ? '' : ' | errorType=$error';
    return '${time.toIso8601String()} [${level.name}] $loggerName: '
        '$message$suffix';
  }
}

/// Centralized logger for FireRaccoon app and engine packages.
///
/// The logger is intentionally lightweight and depends on `package:logging`
/// so every package can share the same level filters and output format.
final class AppLogger {
  AppLogger._();

  static bool _configured = false;
  static Level _minLevel = Level.INFO;
  static final Set<String> _secretValues = <String>{};
  static StreamSubscription<LogRecord>? _subscription;

  /// How many records are kept for [recent].
  ///
  /// Enough to hold the run-up to a failure rather than the failure alone: the
  /// request that preceded it is usually what explains it.
  static const int recentCapacity = 300;
  static final ListQueue<LoggedRecord> _recent = ListQueue<LoggedRecord>();

  /// Configures root logger listeners and filtering.
  static void configure({
    Level minLevel = Level.INFO,
    void Function(String line)? sink,
    Iterable<String> secrets = const <String>[],
  }) {
    _subscription?.cancel();
    _configured = true;
    _minLevel = minLevel;
    _secretValues
      ..clear()
      ..addAll(secrets.where((value) => value.trim().isNotEmpty));

    hierarchicalLoggingEnabled = true;
    Logger.root.level = minLevel;
    _subscription = Logger.root.onRecord.listen((record) {
      if (record.level < _minLevel) {
        return;
      }
      _retain(record);
      final line = formatRecord(record);
      if (sink != null) {
        sink(line);
      } else {
        // Keep default output sink simple so the package stays pure Dart.
        // ignore: avoid_print
        print(line);
      }
    });
  }

  /// Creates a namespaced logger under `fireraccoon.<scope>`.
  static Logger scoped(String scope) => Logger('fireraccoon.$scope');

  static void _retain(LogRecord record) {
    _recent.addLast(
      LoggedRecord(
        time: record.time,
        level: record.level,
        loggerName: record.loggerName,
        message: redact(record.message),
        error: record.error == null ? null : '${record.error.runtimeType}',
      ),
    );
    while (_recent.length > recentCapacity) {
      _recent.removeFirst();
    }
  }

  /// The records kept so far, oldest first.
  ///
  /// [atLeast] filters by severity, which is how a reader asks for the
  /// problems rather than the traffic.
  static List<LoggedRecord> recent({Level? atLeast}) {
    if (atLeast == null) return List<LoggedRecord>.unmodifiable(_recent);
    return List<LoggedRecord>.unmodifiable(
      _recent.where((record) => record.level >= atLeast),
    );
  }

  /// The retained records worth putting in front of somebody.
  ///
  /// Saves every caller naming a level, and the `logging` package with it.
  static List<LoggedRecord> recentProblems() => recent(atLeast: Level.WARNING);

  /// Drops what is retained. The stream is untouched.
  static void clearRecent() => _recent.clear();

  /// Formats records in a single searchable line.
  static String formatRecord(LogRecord record) {
    final base =
        '${record.time.toIso8601String()} [${record.level.name}] '
        '${record.loggerName}: ${redact(record.message)}';
    final error = record.error == null
        ? ''
        : ' | errorType=${record.error.runtimeType}';
    final stack = record.stackTrace == null ? '' : ' | stack=<redacted>';
    return '$base$error$stack';
  }

  /// Redacts known secret values and bearer tokens from log text.
  static String redact(String raw) {
    var output = raw;
    output = output.replaceAllMapped(
      RegExp(r'Bearer\s+[^\s,;]+', caseSensitive: false),
      (_) => 'Bearer ***',
    );
    for (final secret in _secretValues) {
      output = output.replaceAll(secret, '***');
    }
    return output;
  }

  /// Parses level names from config files or env vars.
  static Level parseLevel(String? raw, {Level fallback = Level.INFO}) {
    if (raw == null) return fallback;
    return switch (raw.trim().toUpperCase()) {
      'ALL' => Level.ALL,
      'FINEST' || 'TRACE' => Level.FINEST,
      'FINER' => Level.FINER,
      'FINE' || 'DEBUG' => Level.FINE,
      'CONFIG' => Level.CONFIG,
      'INFO' => Level.INFO,
      'WARNING' || 'WARN' => Level.WARNING,
      'SEVERE' || 'ERROR' => Level.SEVERE,
      'SHOUT' || 'CRITICAL' => Level.SHOUT,
      'OFF' => Level.OFF,
      _ => fallback,
    };
  }

  /// Adds a value to redact from every line from here on.
  ///
  /// [configure] takes the secrets known at startup, and the ones that matter
  /// are not known then: the API token arrives when the keychain answers, and a
  /// session token when someone signs in. Without this the list stayed empty and
  /// [redact] had nothing to match but the word Bearer.
  static void addSecret(String? value) {
    final secret = value?.trim() ?? '';
    if (secret.isEmpty) return;
    _secretValues.add(secret);
  }

  /// Utility helper for logging payload snippets without huge lines.
  ///
  /// Redacted, because the encoded form is the whole point of calling this and
  /// a caller that forgets to redact afterwards prints the payload verbatim.
  static String compactJson(Object? value) {
    if (value == null) return 'null';
    try {
      return redact(jsonEncode(value));
    } on Object {
      return redact('$value');
    }
  }

  /// Resets logger state for deterministic tests.
  static void resetForTest() {
    _subscription?.cancel();
    _subscription = null;
    _configured = false;
    _recent.clear();
    _secretValues.clear();
    _minLevel = Level.INFO;
    Logger.root.level = Level.INFO;
  }

  /// Exposed only for diagnostics and tests.
  static bool get configured => _configured;
}
