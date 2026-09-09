import 'package:fireraccoon/store/cosmos_login.dart';
import 'package:fireraccoon/store/cosmos_login_factory.dart';
import 'package:fireraccoon/store/cosmos_login_webview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('every platform with a web view gets the same one', () {
    // One implementation covers all six now, Linux included, so a platform
    // switch here would be a special case with nothing behind it.
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      final login = resolveCosmosLogin();

      expect(login, isA<WebviewCosmosLogin>(), reason: '$platform');
      expect(login.isSupported, isTrue, reason: '$platform');
    }
  });

  test('the unsupported answer still says so rather than pretending', () {
    const login = UnsupportedCosmosLogin();

    expect(login.isSupported, isFalse);
  });
}
