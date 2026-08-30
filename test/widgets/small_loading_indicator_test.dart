import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/widgets/fun_decorated_surface.dart';
import 'package:fireraccoon/widgets/small_loading_indicator.dart';

import '../helpers/localized_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fireraccoon_logo.png is in the asset bundle', () async {
    final data = await rootBundle.load('assets/fireraccoon_logo.png');
    expect(data.lengthInBytes, greaterThan(1000));
    expect(data.buffer.asUint8List().sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('FunLogo paints the bundled raccoon asset', (tester) async {
    SharedPreferences.setMockInitialValues({'funMode': 'raccoon'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: buildLocalizedTestApp(
          child: const FunLogo(width: 72, height: 72),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('PageLoadingIndicator shows breathing logo in Raccoon Mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'funMode': 'raccoon'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: buildLocalizedTestApp(child: const PageLoadingIndicator()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(FunLogo), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
  });

  testWidgets('SmallLoadingIndicator uses spinner outside Raccoon Mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'funMode': 'none'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: buildLocalizedTestApp(child: const SmallLoadingIndicator()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FunLogo), findsNothing);
  });
}
