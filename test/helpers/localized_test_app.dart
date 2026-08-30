import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fireraccoon/l10n/app_localizations.dart';
import 'package:fireraccoon/theme/app_colors.dart';
import 'package:fireraccoon/theme/app_theme.dart';

Widget buildLocalizedTestApp({required Widget child}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.buildTheme(false, AppAccent.green),
    home: Scaffold(body: child),
  );
}
