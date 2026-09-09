import 'package:fireraccoon/widgets/insecure_connection_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/localized_test_app.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(buildLocalizedTestApp(child: child));

  testWidgets('https gets a closed lock', (tester) async {
    await pump(tester, const TransportLockIcon(url: 'https://firefly.test'));

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.lock_outline);
  });

  testWidgets('http gets an open lock', (tester) async {
    await pump(tester, const TransportLockIcon(url: 'http://firefly.test'));

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.lock_open_outlined);
  });

  testWidgets('the two locks do not share a colour', (tester) async {
    // The whole point of showing it in both states is that the safe one is
    // distinguishable at a glance from the unsafe one.
    await pump(tester, const TransportLockIcon(url: 'https://firefly.test'));
    final secure = tester.widget<Icon>(find.byType(Icon)).color;

    await pump(tester, const TransportLockIcon(url: 'http://firefly.test'));
    final insecure = tester.widget<Icon>(find.byType(Icon)).color;

    expect(secure, isNotNull);
    expect(insecure, isNotNull);
    expect(secure, isNot(insecure));
  });

  testWidgets('the lock is sized where a heading needs it smaller', (
    tester,
  ) async {
    await pump(
      tester,
      const TransportLockIcon(url: 'https://firefly.test', size: 15),
    );

    expect(tester.widget<Icon>(find.byType(Icon)).size, 15);
  });

  testWidgets('the badge names the risk it is flagging', (tester) async {
    await pump(tester, const InsecureConnectionBadge());

    expect(find.text('Not encrypted'), findsOneWidget);
  });

  testWidgets('the warning spells out what travels in the clear', (
    tester,
  ) async {
    await pump(tester, const InsecureConnectionWarning());

    expect(find.textContaining('in the clear'), findsOneWidget);
    expect(find.textContaining('https://'), findsOneWidget);
  });
}
