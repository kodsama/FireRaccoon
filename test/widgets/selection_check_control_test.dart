import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/theme/app_colors.dart';
import 'package:fireracoon/utils/balance_check_selection.dart';
import 'package:fireracoon/widgets/selection_check_control.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../helpers/screen_test_app.dart';

void main() {
  group('reconciledTogglePalette', () {
    final colors = AppColors.dark(AppAccent.green);

    test('reconciled rows use the green palette in both modes', () {
      expect(
        reconciledTogglePalette(
          colors,
          inSelectionMode: false,
          actuallyReconciled: true,
        ).selected,
        colors.success,
      );
      expect(
        reconciledTogglePalette(
          colors,
          inSelectionMode: true,
          actuallyReconciled: true,
        ).selected,
        colors.success,
      );
    });

    test('a pending pick in reconcile mode uses the accent palette', () {
      expect(
        reconciledTogglePalette(
          colors,
          inSelectionMode: true,
          actuallyReconciled: false,
        ).selected,
        SelectionCheckColors.selection(colors).selected,
      );
    });

    test('outside reconcile mode green stays reserved for reconciled', () {
      expect(
        reconciledTogglePalette(
          colors,
          inSelectionMode: false,
          actuallyReconciled: false,
        ).selected,
        colors.success,
      );
    });
  });

  group('balanceCheckTogglePalette', () {
    final colors = AppColors.dark(AppAccent.green);

    test('reconciled included and excluded use green', () {
      expect(
        balanceCheckTogglePalette(
          colors,
          visual: BalanceCheckVisual.reconciledIncluded,
        ).selected,
        colors.success,
      );
      expect(
        balanceCheckTogglePalette(
          colors,
          visual: BalanceCheckVisual.reconciledExcluded,
        ).selected,
        colors.success,
      );
    });

    test('pending and unselected use accent', () {
      expect(
        balanceCheckTogglePalette(
          colors,
          visual: BalanceCheckVisual.pendingInclude,
        ).selected,
        SelectionCheckColors.selection(colors).selected,
      );
      expect(
        balanceCheckTogglePalette(
          colors,
          visual: BalanceCheckVisual.unselected,
        ).selected,
        SelectionCheckColors.selection(colors).selected,
      );
    });
  });

  testWidgets('SelectionCheckControl renders excluded as minus circle', (
    tester,
  ) async {
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const SelectionCheckControl(
          state: SelectionState.none,
          excluded: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(LucideIcons.circleMinus), findsOneWidget);
  });

  testWidgets('SelectionCheckControl renders tri-state icons', (tester) async {
    for (final state in SelectionState.values) {
      await tester.pumpWidget(
        await buildScreenTestApp(
          child: SelectionCheckControl(state: state, enabled: true),
        ),
      );
      await tester.pump();

      expect(find.byType(Icon), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('SelectionCheckControl invokes onTap when enabled', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: SelectionCheckControl(
          state: SelectionState.none,
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('SelectionCheckControl shows disabled icon when off', (
    tester,
  ) async {
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const SelectionCheckControl(
          state: SelectionState.all,
          enabled: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(LucideIcons.circleOff), findsOneWidget);
  });

  testWidgets('SelectionCheckControl hides icon when disabled and hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const SelectionCheckControl(
          state: SelectionState.all,
          enabled: false,
          showDisabledIcon: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Icon), findsNothing);
  });
}
