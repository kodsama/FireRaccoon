import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/providers/view_mode_provider.dart';
import 'package:fireracoon/screens/projection_screen.dart';
import '../helpers/screen_test_app.dart';

void main() {
  testWidgets('ProjectionScreen renders real and speculative projection tabs', (
    tester,
  ) async {
    configureLargeScreen(tester);
    await tester.pumpWidget(
      await buildScreenTestApp(child: const ProjectionScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Real projection'), findsOneWidget);
    expect(find.text('Speculative projection'), findsOneWidget);
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
