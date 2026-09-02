@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fireraccoon/store/legacy_support_directory_io.dart';

void main() {
  late Directory root;
  late String from;
  late String to;

  setUp(() {
    root = Directory.systemTemp.createTempSync('legacy_support');
    from = '${root.path}/com.fireracoon';
    to = '${root.path}/com.fireraccoon';
    Directory(from).createSync();
    Directory(to).createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('takes the undo history and avatars the old install left', () async {
    File('$from/undo_history_v1.json').writeAsStringSync('["undone"]');
    Directory('$from/avatars').createSync();
    File('$from/avatars/person_1.png').writeAsStringSync('png');

    final adopted = await adoptLegacyFiles(from: from, to: to);

    expect(File('$to/undo_history_v1.json').readAsStringSync(), '["undone"]');
    expect(File('$to/avatars/person_1.png').readAsStringSync(), 'png');
    expect(
      adopted,
      containsAll(['undo_history_v1.json', 'avatars/person_1.png']),
    );
  });

  test('leaves a file the current install already wrote', () async {
    File('$from/undo_history_v1.json').writeAsStringSync('["old"]');
    File('$to/undo_history_v1.json').writeAsStringSync('["current"]');

    final adopted = await adoptLegacyFiles(from: from, to: to);

    expect(File('$to/undo_history_v1.json').readAsStringSync(), '["current"]');
    expect(adopted, isEmpty);
  });

  test('does nothing when there is no old directory', () async {
    final adopted = await adoptLegacyFiles(from: '${root.path}/absent', to: to);

    expect(adopted, isEmpty);
  });

  test('legacySupportPath spells the whole path the old way', () {
    expect(
      legacySupportPath('/Users/x/Library/Application Support/com.fireraccoon'),
      '/Users/x/Library/Application Support/com.fireracoon',
    );
    expect(
      legacySupportPath(
        '/Users/x/Library/Containers/com.fireraccoon/Data/Library/'
        'Application Support/com.fireraccoon',
      ),
      '/Users/x/Library/Containers/com.fireracoon/Data/Library/'
      'Application Support/com.fireracoon',
    );
  });
}
