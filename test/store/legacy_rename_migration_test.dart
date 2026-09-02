import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fireraccoon/store/legacy_rename_migration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('adopts every key the rename left behind, whatever its type', () async {
    final prefs = await prefsWith({
      'fireracoon_people_config': '{"version":1,"people":[]}',
      'fireracoon_side_menu_config': '{"nodes":[]}',
      'fireracoon_avatar_person_1': 'AAAA',
      'isRacoonMode': true,
      'transactionPageSize': 100,
    });

    final adopted = await adoptLegacyRenamedPreferences(prefs);

    expect(
      prefs.getString('fireraccoon_people_config'),
      '{"version":1,"people":[]}',
    );
    expect(prefs.getString('fireraccoon_side_menu_config'), '{"nodes":[]}');
    expect(prefs.getString('fireraccoon_avatar_person_1'), 'AAAA');
    expect(prefs.getBool('isRaccoonMode'), isTrue);
    expect(
      adopted,
      containsAll([
        'fireraccoon_people_config',
        'fireraccoon_side_menu_config',
        'fireraccoon_avatar_person_1',
        'isRaccoonMode',
      ]),
    );
    // Keys the rename did not touch are left exactly as they are.
    expect(prefs.getInt('transactionPageSize'), 100);
  });

  test('drops the old key once it has been adopted', () async {
    final prefs = await prefsWith({'fireracoon_people_config': '{}'});

    await adoptLegacyRenamedPreferences(prefs);

    expect(prefs.containsKey('fireracoon_people_config'), isFalse);
  });

  test('leaves a key already written under the new name alone', () async {
    final prefs = await prefsWith({
      'fireracoon_people_config': '{"people":["old"]}',
      'fireraccoon_people_config': '{"people":["current"]}',
    });

    final adopted = await adoptLegacyRenamedPreferences(prefs);

    expect(
      prefs.getString('fireraccoon_people_config'),
      '{"people":["current"]}',
    );
    // Nothing was adopted, so nothing is discarded either.
    expect(prefs.getString('fireracoon_people_config'), '{"people":["old"]}');
    expect(adopted, isEmpty);
  });

  test('renames the one stored value the rename moved', () async {
    final prefs = await prefsWith({'funMode': 'racoon'});

    final adopted = await adoptLegacyRenamedPreferences(prefs);

    expect(prefs.getString('funMode'), 'raccoon');
    expect(adopted, contains('funMode'));
  });

  test('a fun mode that is already current is left as it is', () async {
    final prefs = await prefsWith({'funMode': 'christmas'});

    final adopted = await adoptLegacyRenamedPreferences(prefs);

    expect(prefs.getString('funMode'), 'christmas');
    expect(adopted, isEmpty);
  });

  test('leaves a key holding neither text nor a flag alone', () async {
    final prefs = await prefsWith({'fireracoon_count': 3});

    final adopted = await adoptLegacyRenamedPreferences(prefs);

    // Writing it back as text would make the new key unreadable to the
    // getter that owns it, so nothing is written and nothing is dropped.
    expect(prefs.get('fireraccoon_count'), isNull);
    expect(prefs.getInt('fireracoon_count'), 3);
    expect(adopted, isEmpty);
  });

  test('legacyPreferenceName spells a preference the old way', () {
    expect(
      legacyPreferenceName('fireraccoon_people_config'),
      'fireracoon_people_config',
    );
  });
}
