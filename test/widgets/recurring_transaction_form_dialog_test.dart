import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/utils/create_flows.dart';
import 'package:fireraccoon/widgets/recurring_transaction_form_dialog.dart';

import '../helpers/dialog_test_helpers.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/ui_test_data.dart';

Future<void> _openCreateDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open Dialog'));
  await settleIgnoringOverflow(tester);
}

Future<void> _fillMandatoryFields(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Monthly rent');
  await tester.enterText(fields.at(2), 'Rent payment');
  await tester.enterText(fields.at(3), '1200.00');
  await tester.pump();
}

const _rule =
    'fireraccoon:schedule:anchor=day:31;adjust=previous-banking;calendar=SE';

/// A rule whose schedule Firefly cannot state, so it rides in the notes.
final _ruledRecurrence = Recurrence(
  id: 'rec-2',
  type: RecurrenceTransactionType.withdrawal,
  title: 'Union fee',
  firstDate: DateTime(2026, 8, 1),
  notes: 'Renegotiated in March\n$_rule',
  repetitions: const [
    RecurrenceRepetition(type: RecurrenceRepetitionType.monthly, moment: '31'),
  ],
  transactions: const [
    RecurrenceTransactionLine(
      id: 'tx-line-2',
      description: 'Union fee',
      amount: 250,
      currencyCode: 'EUR',
      sourceId: '1',
      sourceName: 'Checking',
      destinationId: '2',
      destinationName: 'Store',
    ),
  ],
);

Future<FakeFireflyService> _openEditingRuled(WidgetTester tester) async {
  configureDialogTestSurface(tester);
  addTearDown(tester.view.resetPhysicalSize);

  final fake = buildDialogFireflyService(recurrences: [_ruledRecurrence]);
  await tester.pumpWidget(
    await buildScreenTestApp(
      child: Consumer(
        builder: (context, ref, _) {
          return ElevatedButton(
            onPressed: () => showRecurringTransactionFormDialog(
              context: context,
              ref: ref,
              recurrence: _ruledRecurrence,
            ),
            child: const Text('Open Dialog'),
          );
        },
      ),
      fireflyService: fake,
      authSettings: AuthSettings(
        serverUrl: 'https://firefly.test',
        apiToken: 'token',
      ),
    ),
  );
  await settleIgnoringOverflow(tester);
  await _openCreateDialog(tester);
  return fake;
}

void main() {
  setUp(allowDialogLayoutOverflow);

  testWidgets('the amount says which currency the rule is in', (tester) async {
    configureDialogTestSurface(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showRecurringTransactionFormDialog(
                context: context,
                ref: ref,
              ),
              child: const Text('Open Dialog'),
            );
          },
        ),
        fireflyService: buildDialogFireflyService(),
      ),
    );
    await settleIgnoringOverflow(tester);
    await _openCreateDialog(tester);

    // On the amount, not on a row of its own above it, where a rule in krona
    // and a rule in euro read exactly alike.
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('Default Currency'), findsNothing);
  });

  testWidgets('showRecurringTransactionFormDialog creates a recurrence', (
    tester,
  ) async {
    configureDialogTestSurface(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService();

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () =>
                  openCreateRecurringTransactionDialog(context, ref),
              child: const Text('Open Dialog'),
            );
          },
        ),
        fireflyService: fake,
        authSettings: AuthSettings(
          serverUrl: 'https://firefly.test',
          apiToken: 'token',
        ),
      ),
    );
    await settleIgnoringOverflow(tester);

    await _openCreateDialog(tester);
    expect(find.text('Create Recurring Transaction'), findsOneWidget);

    await _fillMandatoryFields(tester);
    await tapDialogPrimaryAction(tester, label: 'Create');

    expect(find.text('Create Recurring Transaction'), findsNothing);
    expect(find.text('Recurring transaction created.'), findsOneWidget);
  });

  testWidgets('showRecurringTransactionFormDialog edits a recurrence', (
    tester,
  ) async {
    configureDialogTestSurface(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService(recurrences: [sampleRecurrence]);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showRecurringTransactionFormDialog(
                context: context,
                ref: ref,
                recurrence: sampleRecurrence,
              ),
              child: const Text('Open Dialog'),
            );
          },
        ),
        fireflyService: fake,
        authSettings: AuthSettings(
          serverUrl: 'https://firefly.test',
          apiToken: 'token',
        ),
      ),
    );
    await settleIgnoringOverflow(tester);

    await _openCreateDialog(tester);
    expect(find.text('Edit Recurring Transaction'), findsOneWidget);
    expect(find.text('Weekly groceries'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'Biweekly groceries');
    await tapDialogPrimaryAction(tester, label: 'Save');

    expect(find.text('Edit Recurring Transaction'), findsNothing);
  });

  testWidgets('the schedule rule never reaches the notes field, and survives '
      'a save that never touched it', (tester) async {
    // The rule is a marker, not prose. Left visible in the notes it reads as
    // junk, and one keystroke would put the schedule silently back to the day
    // number Firefly stores.
    final fake = await _openEditingRuled(tester);

    expect(find.textContaining('fireraccoon:schedule:'), findsNothing);
    expect(find.text('Renegotiated in March'), findsWidgets);

    await tapDialogPrimaryAction(tester, label: 'Save');

    expect(fake.savedRecurrences.single.notes, 'Renegotiated in March\n$_rule');
  });

  testWidgets('a stored rule fills in the controls that describe it', (
    tester,
  ) async {
    await _openEditingRuled(tester);

    expect(find.text('Use a banking-day rule'), findsOneWidget);
    expect(find.text('The banking day before'), findsWidgets);
    expect(find.text('Sweden'), findsWidgets);
  });

  testWidgets('turning the rule off takes it out of the notes', (tester) async {
    final fake = await _openEditingRuled(tester);

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await settleIgnoringOverflow(tester);
    await tapDialogPrimaryAction(tester, label: 'Save');

    expect(fake.savedRecurrences.single.notes, 'Renegotiated in March');
  });

  testWidgets('the last Thursday of the month loads as itself', (tester) async {
    // The case ndom cannot state: counting forward, a fifth Thursday fires in
    // some months and goes quiet in the rest.
    configureDialogTestSurface(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final recurrence = Recurrence(
      id: 'rec-3',
      type: RecurrenceTransactionType.withdrawal,
      title: 'Cleaner',
      firstDate: DateTime(2026, 8, 1),
      notes:
          'fireraccoon:schedule:anchor=weekday:-1,4;adjust=none;'
          'calendar=weekend',
      repetitions: const [
        RecurrenceRepetition(
          type: RecurrenceRepetitionType.ndom,
          moment: '4,4',
        ),
      ],
      transactions: const [
        RecurrenceTransactionLine(
          id: 'tx-line-3',
          description: 'Cleaner',
          amount: 80,
          currencyCode: 'EUR',
          sourceId: '1',
          sourceName: 'Checking',
          destinationId: '2',
          destinationName: 'Store',
        ),
      ],
    );

    final fake = buildDialogFireflyService(recurrences: [recurrence]);
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showRecurringTransactionFormDialog(
                context: context,
                ref: ref,
                recurrence: recurrence,
              ),
              child: const Text('Open Dialog'),
            );
          },
        ),
        fireflyService: fake,
        authSettings: AuthSettings(
          serverUrl: 'https://firefly.test',
          apiToken: 'token',
        ),
      ),
    );
    await settleIgnoringOverflow(tester);
    await _openCreateDialog(tester);

    expect(find.text('Last'), findsWidgets);
    expect(find.text('Thursday'), findsWidgets);

    await tapDialogPrimaryAction(tester, label: 'Save');

    expect(
      fake.savedRecurrences.single.notes,
      'fireraccoon:schedule:anchor=weekday:-1,4;adjust=none;calendar=weekend',
    );
  });

  testWidgets('turning the rule on writes it into the notes', (tester) async {
    configureDialogTestSurface(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService();
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showRecurringTransactionFormDialog(
                context: context,
                ref: ref,
              ),
              child: const Text('Open Dialog'),
            );
          },
        ),
        fireflyService: fake,
        authSettings: AuthSettings(
          serverUrl: 'https://firefly.test',
          apiToken: 'token',
        ),
      ),
    );
    await settleIgnoringOverflow(tester);
    await _openCreateDialog(tester);
    await _fillMandatoryFields(tester);

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await settleIgnoringOverflow(tester);

    expect(find.text('Day of the month'), findsWidgets);
    await tapDialogPrimaryAction(tester, label: 'Create');

    expect(
      fake.savedRecurrences.single.notes,
      'fireraccoon:schedule:anchor=day:1;adjust=none;calendar=weekend',
    );
  });
}
