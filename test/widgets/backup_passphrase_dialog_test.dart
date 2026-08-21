import 'package:fireracoon/widgets/backup_passphrase_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/localized_test_app.dart';

/// Holds the dialog's future.
///
/// Returning it from an async helper would flatten it, so the helper would not
/// complete until the dialog closed and every test would deadlock before it
/// could interact.
class _DialogRun {
  Future<String?>? future;
}

/// Opens the dialog and returns a handle to the result it will produce.
Future<_DialogRun> _open(WidgetTester tester, {required bool confirm}) async {
  final run = _DialogRun();

  await tester.pumpWidget(
    buildLocalizedTestApp(
      child: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              run.future = showBackupPassphraseDialog(
                context: context,
                confirm: confirm,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return run;
}

void main() {
  testWidgets('cancelling returns null without a disposal error', (
    tester,
  ) async {
    final run = await _open(tester, confirm: false);

    await tester.enterText(find.byType(TextField), 'hunter2');
    await tester.tap(find.text('Cancel'));
    // Disposing the controllers when showDialog's future completed read them
    // again while the route animated out: "A TextEditingController was used
    // after being disposed", cascading into a failed Overlay assertion.
    await tester.pumpAndSettle();

    expect(await run.future, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a passphrase is returned and nothing is used after disposal', (
    tester,
  ) async {
    final run = await _open(tester, confirm: false);

    await tester.enterText(find.byType(TextField), 'hunter2');
    await tester.tap(find.text('Import settings'));
    await tester.pumpAndSettle();

    expect(await run.future, 'hunter2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty passphrase is refused rather than returned', (
    tester,
  ) async {
    await _open(tester, confirm: false);

    await tester.tap(find.text('Import settings'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Enter the backup passphrase.'), findsOneWidget);
  });

  testWidgets('export refuses a passphrase that fails the policy', (
    tester,
  ) async {
    await _open(tester, confirm: true);

    await tester.enterText(find.byType(TextField).first, 'short');
    await tester.tap(find.text('Export settings'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    // Typing again clears the complaint rather than leaving it stale.
    await tester.enterText(find.byType(TextField).first, 'Str0ng!Passphrase');
    await tester.pumpAndSettle();
    expect(find.textContaining('at least'), findsNothing);
  });

  testWidgets('export refuses when the confirmation does not match', (
    tester,
  ) async {
    await _open(tester, confirm: true);

    await tester.enterText(find.byType(TextField).first, 'Str0ng!Passphrase');
    await tester.enterText(find.byType(TextField).last, 'Str0ng!Different');
    await tester.tap(find.text('Export settings'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('export returns the passphrase when both fields agree', (
    tester,
  ) async {
    final run = await _open(tester, confirm: true);

    await tester.enterText(find.byType(TextField).first, 'Str0ng!Passphrase');
    await tester.enterText(find.byType(TextField).last, 'Str0ng!Passphrase');
    await tester.tap(find.text('Export settings'));
    await tester.pumpAndSettle();

    expect(await run.future, 'Str0ng!Passphrase');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the passphrase can be shown and hidden', (tester) async {
    await _open(tester, confirm: false);

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isFalse,
    );
  });
}
