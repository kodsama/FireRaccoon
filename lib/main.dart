// coverage:ignore-file — app bootstrap shell
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'deployment/deployment_providers.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/mcp_provider.dart';
import 'providers/server_session_provider.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'services/mcp_service.dart';
import 'store/secure_storage.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureLogging();
  final prefs = await SharedPreferences.getInstance();
  final deployment = await loadDeploymentConfig();
  // One keychain trip before anything hydrates. Each provider reads its own
  // secrets, and on macOS an unprimed read is a separate keychain access and so
  // a separate password prompt.
  await appSecureStorage.prime();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deploymentConfigProvider.overrideWithValue(deployment),
      ],
      child: const FireRacoonApp(),
    ),
  );
}

void _configureLogging() {
  const envLogLevel = String.fromEnvironment('LOG_LEVEL');
  final level = AppLogger.parseLevel(envLogLevel.isEmpty ? null : envLogLevel);
  // Bearer tokens are pattern-redacted by AppLogger; no static secret list
  // is needed now that credentials never pass through build-time config.
  AppLogger.configure(minLevel: level, secrets: const []);
  final startupLog = AppLogger.scoped('app.startup');

  FlutterError.onError = (details) {
    startupLog.severe(
      'Uncaught Flutter framework error: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    startupLog.shout('Uncaught platform error', error, stack);
    return true;
  };
  const fromDefine = String.fromEnvironment('FIRERACOON_MODE');
  startupLog.info(
    'Logging configured at level ${level.name}; '
    'FIRERACOON_MODE=${fromDefine.isEmpty ? 'local (default)' : fromDefine}',
  );
}

class FireRacoonApp extends ConsumerWidget {
  const FireRacoonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deployment = ref.watch(deploymentConfigProvider);
    if (deployment.isServer) {
      ref.watch(serverSessionProvider);
    }
    final router = ref.watch(routerProvider);
    final themeSettings = ref.watch(themeProvider);
    final appLocale = ref.watch(localeProvider);
    if (mcpDesktopSupported) {
      ref.watch(mcpServiceProvider);
    }

    return MaterialApp.router(
      title: 'FireRacoon',
      locale: appLocale.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocale.supported,
      themeMode: themeSettings.themeMode,
      theme: AppTheme.buildFromSettings(
        isDark: false,
        palette: themeSettings.effectivePalette,
        accentType: themeSettings.effectiveAccent,
      ),
      darkTheme: AppTheme.buildFromSettings(
        isDark: true,
        palette: themeSettings.effectivePalette,
        accentType: themeSettings.effectiveAccent,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
