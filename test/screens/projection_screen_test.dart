import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/providers/view_mode_provider.dart';
import 'package:fireraccoon/screens/projection_screen.dart';

import '../helpers/screen_test_app.dart';

void main() {
  testWidgets('ProjectionScreen forecasts from scheduled cash flow', (
    tester,
  ) async {
    configureLargeScreen(tester);
    await tester.pumpWidget(
      await buildScreenTestApp(child: const ProjectionScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Include in forecast'), findsOneWidget);
    expect(find.text('Predicted balances'), findsOneWidget);
  });

  testWidgets('ProjectionScreen respects global compact view mode', (
    tester,
  ) async {
    configureLargeScreen(tester);
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const ProjectionScreen(),
        viewMode: ViewMode.compact,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsWidgets);
    expect(find.text('Checking'), findsWidgets);
  });
}
