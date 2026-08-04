import 'dart:convert';
import 'dart:io';

import 'package:fireracoon/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';

class _WebAuthPlatform extends FlutterWebAuth2Platform {
  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required Map<String, dynamic> options,
  }) async {
    final state = Uri.parse(url).queryParameters['state'];
    return Uri(
      scheme: callbackUrlScheme,
      host: 'oauth-callback',
      queryParameters: {'code': 'authorization-code', 'state': state},
    ).toString();
  }

  @override
  Future<void> clearAllDanglingCalls() async {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  test('authenticateOAuth exchanges the code and stores credentials', () async {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    FlutterWebAuth2Platform.instance = _WebAuthPlatform();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'access_token': 'oauth-token',
          'token_type': 'bearer',
          'expires_in': 3600,
        }),
      );
      await request.response.close();
    });
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => AuthNotifier(storage: const FlutterSecureStorage()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final baseUrl = 'http://${server.address.host}:${server.port}';

    await container
        .read(authProvider.notifier)
        .authenticateOAuth('$baseUrl/', 'client-id', true);

    final settings = container.read(authProvider);
    expect(settings.serverUrl, baseUrl);
    expect(settings.apiToken, 'oauth-token');
    expect(settings.authMode, AuthMode.oauth2);
    expect(settings.allowInsecure, isTrue);
  });
}
