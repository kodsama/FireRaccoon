import 'package:shared_preferences/shared_preferences.dart';

/// Settings written before the raccoon spelling was corrected.
///
/// The rename gave every key FireRaccoon owns a second c, and took one stored
/// value with it: fun mode is recorded by name, and `racoon` is not a name any
/// mode answers to now. Nothing was deleted, so an install from before the
/// rename still holds all of it under the old spelling, in a place the app no
/// longer looks.
const String _legacyPrefix = 'fireracoon_';
const String _currentPrefix = 'fireraccoon_';

/// Set once the pre-rename application support directory has been read.
///
/// Without it, a file the person deleted on purpose would come back on the
/// next launch, which is the one thing copying it again cannot undo.
const String kLegacySupportAdoptedKey = 'fireraccoonLegacySupportAdopted';

/// The name a preference had before the rename.
///
/// Firefly still holds whatever the old install mirrored there, under the name
/// that install used, so the server copy is reachable by asking for it.
String legacyPreferenceName(String name) =>
    name.replaceFirst(_currentPrefix, _legacyPrefix);

/// Copies what the old spelling still holds onto the names in use, and reports
/// the names it recovered.
///
/// A key already written under the new name wins: it is what the person has
/// been using since, and the stranded copy is older by definition. Only a key
/// that was actually adopted is dropped afterwards, so nothing is discarded on
/// the strength of a guess about which copy matters.
Future<List<String>> adoptLegacyRenamedPreferences(
  SharedPreferences prefs,
) async {
  final adopted = <String>[];
  for (final legacyKey in prefs.getKeys().toList()) {
    final currentKey = _currentNameFor(legacyKey);
    if (currentKey == null) continue;
    if (prefs.get(currentKey) != null) continue;
    // Every key the rename moved holds either text, which is how the three
    // configs and the avatars are stored, or the one flag. Anything else is
    // left where it is rather than written back as the wrong type.
    final value = prefs.get(legacyKey);
    if (value is String) {
      await prefs.setString(currentKey, value);
    } else if (value is bool) {
      await prefs.setBool(currentKey, value);
    } else {
      continue;
    }
    await prefs.remove(legacyKey);
    adopted.add(currentKey);
  }
  // Fun mode is the one value, rather than key, that the rename moved.
  if (prefs.getString('funMode') == 'racoon') {
    await prefs.setString('funMode', 'raccoon');
    adopted.add('funMode');
  }
  return adopted;
}

String? _currentNameFor(String key) {
  if (key.startsWith(_legacyPrefix)) {
    return '$_currentPrefix${key.substring(_legacyPrefix.length)}';
  }
  if (key == 'isRacoonMode') return 'isRaccoonMode';
  return null;
}
