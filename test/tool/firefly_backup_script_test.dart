import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firefly_backup.sh volumes prints compose volume names', () async {
    final root = Directory.current.path;
    final script = File('$root/tool/firefly_backup.sh');
    expect(script.existsSync(), isTrue);

    final result = await Process.run(
      'bash',
      [script.path, 'volumes'],
      environment: {...Platform.environment, 'COMPOSE_PROJECT_NAME': 'demo'},
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final out = result.stdout.toString();
    expect(out, contains('project=demo'));
    expect(out, contains('db=demo_firefly_db'));
    expect(out, contains('upload=demo_firefly_upload'));
  });
}
