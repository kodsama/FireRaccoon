// coverage:ignore-file — app bootstrap shell
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'deployment/deployment_providers.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/mcp_provider.dart';
import 'providers/server_session_provider.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'providers/backup_providers.dart';
import 'services/mcp_service.dart';
import 'utils/backup_directory.dart';
import 'store/secure_storage.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureLogging();
  // Dates can be written in a locale the interface is not translated into, and
  // flutter_localizations only loads symbols for the languages it ships. Asking
  // DateFormat for one it has never seen throws, so they are all loaded here.
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  final deployment = await loadDeploymentConfig();
  // One keychain trip before anything hydrates. Each provider reads its own
  // secrets, and on macOS an unprimed read is a separate keychain access and so
  // a separate password prompt.
  await appSecureStorage.prime();
  // Resolved here rather than lazily: the path comes from a platform channel,
  // and the MCP server hands it to its isolate at spawn, which cannot wait.
  final backupsDirectory = await resolveBackupsDirectory();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deploymentConfigProvider.overrideWithValue(deployment),
        backupsDirectoryProvider.overrideWithValue(backupsDirectory),
      ],
      child: const FireRaccoonApp(),
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
  const fromDefine = String.fromEnvironment('FIRERACCOON_MODE');
  startupLog.info(
    'Logging configured at level ${level.name}; '
    'FIRERACCOON_MODE=${fromDefine.isEmpty ? 'local (default)' : fromDefine}',
  );
}

class FireRaccoonApp extends ConsumerWidget {
  const FireRaccoonApp({super.key});

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
      title: 'FireRaccoon',
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
