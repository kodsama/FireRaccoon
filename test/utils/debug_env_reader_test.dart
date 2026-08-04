import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/utils/debug_env_credentials.dart';
import 'package:fireracoon/utils/debug_env_reader_io.dart';

void main() {
  group('parseDotEnv', () {
    test('parses key/value pairs and skips comments and blanks', () {
      final env = parseDotEnv('''
# Firefly credentials
FIREFLY_URL=https://cash.example.com

FIREFLY_TOKEN=abc123
''');
      expect(env['FIREFLY_URL'], 'https://cash.example.com');
      expect(env['FIREFLY_TOKEN'], 'abc123');
      expect(env.containsKey('# Firefly credentials'), isFalse);
    });

    test('strips matching surrounding quotes', () {
      final env = parseDotEnv('FIREFLY_TOKEN="quoted"\nOTHER=\'single\'');
      expect(env['FIREFLY_TOKEN'], 'quoted');
      expect(env['OTHER'], 'single');
    });

    test('ignores malformed lines without a key', () {
      final env = parseDotEnv('=nokey\nJUSTKEY\nGOOD=value');
      expect(env, {'GOOD': 'value'});
    });
  });

  group('readDebugEnvFile / loadDebugEnvCredentials', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('fr_env_test'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    test('reads an existing .env file', () async {
      final path = '${tempDir.path}/.env';
      File(
        path,
      ).writeAsStringSync('FIREFLY_URL=https://x.test\nFIREFLY_TOKEN=t');

      expect(await readDebugEnvFile(path), {
        'FIREFLY_URL': 'https://x.test',
        'FIREFLY_TOKEN': 't',
      });
      // The public entry (debug build) delegates to the reader.
      expect(await loadDebugEnvCredentials(path), {
        'FIREFLY_URL': 'https://x.test',
        'FIREFLY_TOKEN': 't',
      });
    });

    test('returns empty when the file is absent', () async {
      final missing = '${tempDir.path}/nope.env';
      expect(await readDebugEnvFile(missing), isEmpty);
      expect(await loadDebugEnvCredentials(missing), isEmpty);
    });
  });
}
