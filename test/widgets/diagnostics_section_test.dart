import 'package:fireraccoon/widgets/diagnostics_section.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/localized_test_app.dart';

void main() {
  setUp(AppLogger.configure);
  tearDown(AppLogger.resetForTest);

  testWidgets('shows what failed since the app started', (tester) async {
    AppLogger.scoped('api.firefly').severe('Firefly refused the write');

    await tester.pumpWidget(
      buildLocalizedTestApp(child: const DiagnosticsSection()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Firefly refused the write'), findsOneWidget);
    expect(find.textContaining('Nothing has failed'), findsNothing);
  });

  testWidgets('routine traffic is not shown as a problem', (tester) async {
    AppLogger.scoped('api.firefly').info('GET /api/v1/accounts 200');

    await tester.pumpWidget(
      buildLocalizedTestApp(child: const DiagnosticsSection()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing has failed'), findsOneWidget);
    expect(find.textContaining('/api/v1/accounts'), findsNothing);
  });

  testWidgets('clearing empties the list', (tester) async {
    AppLogger.scoped('api.firefly').severe('Firefly refused the write');

    await tester.pumpWidget(
      buildLocalizedTestApp(child: const DiagnosticsSection()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Firefly refused the write'), findsNothing);
    expect(find.textContaining('Nothing has failed'), findsOneWidget);
  });
}
