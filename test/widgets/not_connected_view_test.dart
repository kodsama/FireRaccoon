import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/widgets/not_connected_view.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/localized_test_app.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    String? funMode,
  }) async {
    SharedPreferences.setMockInitialValues({'funMode': funMode ?? 'none'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: buildLocalizedTestApp(child: child),
      ),
    );
    await tester.pump();
  }

  testWidgets('a disconnected server is a state, not an error', (tester) async {
    await pump(
      tester,
      const LoadFailureView(
        error: FireflyNotConnectedException(),
        message: 'Error loading data: something went wrong',
      ),
    );

    expect(find.text('Uh oh, no server yet'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    // The whole point: none of the exception prose reaches the screen.
    expect(find.textContaining('Error loading data'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('a real failure still shows its message', (tester) async {
    await pump(
      tester,
      LoadFailureView(
        error: Exception('boom'),
        message: 'Error loading data: boom',
      ),
    );

    expect(find.text('Error loading data: boom'), findsOneWidget);
    expect(find.byType(NotConnectedView), findsNothing);
  });

  testWidgets('Raccoon Mode gets its own copy', (tester) async {
    await pump(tester, const NotConnectedView(), funMode: 'raccoon');

    expect(find.text('Uh oh, the bins are empty'), findsOneWidget);
    expect(find.text('Uh oh, no server yet'), findsNothing);
  });
}
