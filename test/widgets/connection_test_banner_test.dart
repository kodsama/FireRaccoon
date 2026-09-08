import 'package:fireraccoon/widgets/connection_test_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/localized_test_app.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('a failure is readable against its own background', (
    tester,
  ) async {
    // The bug this replaces: the message went to a snack bar the dialog's own
    // scrim painted over, leaving it dimmed to the point of being unreadable.
    await tester.pumpWidget(
      buildLocalizedTestApp(
        child: const ConnectionTestBanner(ok: false, message: 'It went wrong'),
      ),
    );

    final text = tester.widget<Text>(find.text('It went wrong'));
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('It went wrong'),
            matching: find.byType(Container),
          )
          .first,
    );
    final background = (container.decoration! as BoxDecoration).color!;

    expect(
      _contrast(text.style!.color!, background),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('an action is offered only when one was given', (tester) async {
    await tester.pumpWidget(
      buildLocalizedTestApp(
        child: const ConnectionTestBanner(ok: false, message: 'no action'),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);

    await tester.pumpWidget(
      buildLocalizedTestApp(
        child: ConnectionTestBanner(
          ok: false,
          message: 'with action',
          action: FilledButton(onPressed: () {}, child: const Text('Do it')),
        ),
      ),
    );
    expect(find.text('Do it'), findsOneWidget);
  });

  testWidgets('a success reads on its own background too', (tester) async {
    await tester.pumpWidget(
      buildLocalizedTestApp(
        child: const ConnectionTestBanner(ok: true, message: 'It worked'),
      ),
    );

    final text = tester.widget<Text>(find.text('It worked'));
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('It worked'),
            matching: find.byType(Container),
          )
          .first,
    );
    final background = (container.decoration! as BoxDecoration).color!;

    expect(
      _contrast(text.style!.color!, background),
      greaterThanOrEqualTo(4.5),
    );
  });
}
