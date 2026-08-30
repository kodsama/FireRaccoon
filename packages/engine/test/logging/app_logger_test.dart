import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  group('AppLogger', () {
    tearDown(AppLogger.resetForTest);

    test('redacts authorization tokens from free text', () {
      final redacted = AppLogger.redact(
        'Authorization: Bearer secret-token-value',
      );

      expect(redacted, isNot(contains('secret-token-value')));
      expect(redacted, contains('Bearer ***'));
    });

    test('formats records with timestamp, level and logger name', () {
      final record = LogRecord(
        Level.WARNING,
        'Request failed',
        'fireraccoon.api',
        'boom',
        StackTrace.current,
      );

      final formatted = AppLogger.formatRecord(record);

      expect(formatted, contains('WARNING'));
      expect(formatted, contains('fireraccoon.api'));
      expect(formatted, contains('Request failed'));
      expect(formatted, isNot(contains('boom')));
    });

    test('emits only records at configured level or above', () {
      final emitted = <String>[];
      AppLogger.configure(minLevel: Level.INFO, sink: emitted.add);
      final log = AppLogger.scoped('api');

      log.fine('too chatty');
      log.info('important');

      expect(emitted, hasLength(1));
      expect(emitted.single, contains('important'));
    });

    test('redacts configured secret values', () {
      AppLogger.configure(secrets: ['super-secret']);
      expect(AppLogger.redact('token=super-secret'), contains('***'));
      AppLogger.resetForTest();
    });

    test('parseLevel maps config names and falls back', () {
      expect(AppLogger.parseLevel(null), Level.INFO);
      expect(AppLogger.parseLevel('ALL'), Level.ALL);
      expect(AppLogger.parseLevel('trace'), Level.FINEST);
      expect(AppLogger.parseLevel('FINER'), Level.FINER);
      expect(AppLogger.parseLevel('debug'), Level.FINE);
      expect(AppLogger.parseLevel('CONFIG'), Level.CONFIG);
      expect(AppLogger.parseLevel('INFO'), Level.INFO);
      expect(AppLogger.parseLevel('warn'), Level.WARNING);
      expect(AppLogger.parseLevel('error'), Level.SEVERE);
      expect(AppLogger.parseLevel('critical'), Level.SHOUT);
      expect(AppLogger.parseLevel('OFF'), Level.OFF);
      expect(AppLogger.parseLevel('unknown'), Level.INFO);
      expect(AppLogger.parseLevel('debug', fallback: Level.SEVERE), Level.FINE);
    });

    test('compactJson encodes values and falls back on failure', () {
      expect(AppLogger.compactJson(null), 'null');
      expect(AppLogger.compactJson({'a': 1}), '{"a":1}');
      expect(AppLogger.compactJson(Object()), isNotEmpty);
    });

    test('configure marks logger as configured', () {
      AppLogger.configure(minLevel: Level.WARNING);
      expect(AppLogger.configured, isTrue);
    });

    test('configure without sink uses default output path', () {
      AppLogger.configure(minLevel: Level.INFO);
      AppLogger.scoped('default').info('hello default sink');
      expect(AppLogger.configured, isTrue);
    });

    test('reconfigure cancels prior subscription', () {
      final first = <String>[];
      final second = <String>[];
      AppLogger.configure(minLevel: Level.INFO, sink: first.add);
      AppLogger.configure(minLevel: Level.INFO, sink: second.add);
      AppLogger.scoped('api').info('after reconfigure');

      expect(first, isEmpty);
      expect(second, hasLength(1));
    });

    test('compactJson redacts the payload it encodes', () {
      // Encoding is the whole point of calling this, so a caller that forgets
      // to redact afterwards prints the payload verbatim.
      AppLogger.configure(sink: (_) {}, secrets: const ['tok-abc']);
      addTearDown(AppLogger.resetForTest);

      final line = AppLogger.compactJson({
        'apiToken': 'tok-abc',
        'account': 'Wallet',
      });

      expect(line, isNot(contains('tok-abc')));
      expect(line, contains('***'));
      expect(line, contains('Wallet'));
    });

    test('a secret learned after configure is still redacted', () {
      // The token arrives when the keychain answers, long after configure ran,
      // so a list fixed at startup can never contain it.
      AppLogger.configure(sink: (_) {}, secrets: const []);
      addTearDown(AppLogger.resetForTest);

      expect(AppLogger.redact('token=late-secret'), contains('late-secret'));

      AppLogger.addSecret('late-secret');
      expect(
        AppLogger.redact('token=late-secret'),
        isNot(contains('late-secret')),
      );
    });

    test('addSecret ignores nothing worth redacting', () {
      AppLogger.configure(sink: (_) {}, secrets: const []);
      addTearDown(AppLogger.resetForTest);

      AppLogger.addSecret(null);
      AppLogger.addSecret('');
      AppLogger.addSecret('   ');

      // An empty secret would otherwise match everywhere and redact the lot.
      expect(AppLogger.redact('nothing to hide'), 'nothing to hide');
    });
  });
}
