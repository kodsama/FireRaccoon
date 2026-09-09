import 'package:fireraccoon/store/cosmos_login.dart';
import 'package:fireraccoon/store/cosmos_login_desktop.dart';
import 'package:fireraccoon/store/cosmos_login_factory.dart';
import 'package:fireraccoon/store/cosmos_login_webview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('inappwebview covers the platforms it implements', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        resolveCosmosLogin(),
        isA<WebviewCosmosLogin>(),
        reason: '$platform should use the inappwebview flow',
      );
    }
  });

  test('Linux falls to the desktop web view', () {
    // flutter_inappwebview has no Linux implementation, so Linux uses
    // webkit2gtk through desktop_webview_window instead.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    expect(resolveCosmosLogin(), isA<DesktopCosmosLogin>());
  });

  test('anything else reports itself unsupported rather than guessing', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

    final login = resolveCosmosLogin();

    expect(login, isA<UnsupportedCosmosLogin>());
    expect(login.isSupported, isFalse);
  });
}
