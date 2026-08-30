import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/models/account_prognosis.dart';
import 'package:fireraccoon/theme/app_colors.dart';
import 'package:fireraccoon/theme/app_theme.dart';
import 'package:fireraccoon/widgets/prognosis_band_chart.dart';

void main() {
  test(
    'computePrognosisChartBounds does not force zero for distant values',
    () {
      final bounds = computePrognosisChartBounds([
        PrognosisBalancePoint(
          date: DateTime(2026, 7, 1),
          expected: 10000,
          pessimistic: 9800,
          optimistic: 10200,
        ),
        PrognosisBalancePoint(
          date: DateTime(2026, 7, 15),
          expected: 10400,
          pessimistic: 10200,
          optimistic: 10600,
        ),
      ]);

      expect(bounds.min, greaterThan(0));
    },
  );

  testWidgets('PrognosisBandChart renders chart for multi-point timeline', (
    tester,
  ) async {
    final timeline = [
      PrognosisBalancePoint(
        date: DateTime(2026, 7, 1),
        expected: 1000,
        pessimistic: 900,
        optimistic: 1100,
      ),
      PrognosisBalancePoint(
        date: DateTime(2026, 7, 15),
        expected: 800,
        pessimistic: 700,
        optimistic: 900,
      ),
      PrognosisBalancePoint(
        date: DateTime(2026, 7, 31),
        expected: 600,
        pessimistic: 500,
        optimistic: 700,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(true, AppAccent.violet),
        home: Scaffold(
          body: PrognosisBandChart(
            timeline: timeline,
            formatValue: (value) => '\$${value.toStringAsFixed(0)}',
            markerEndOfMonth: DateTime(2026, 7, 31),
            horizonEnd: DateTime(2026, 7, 31),
          ),
        ),
      ),
    );

    expect(find.byType(PrognosisBandChart), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('PrognosisBandChart shows placeholder for short timeline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(true, AppAccent.violet),
        home: Scaffold(
          body: PrognosisBandChart(
            timeline: [
              PrognosisBalancePoint(
                date: DateTime(2026, 7, 1),
                expected: 1000,
                pessimistic: 900,
                optimistic: 1100,
              ),
            ],
            formatValue: _format,
          ),
        ),
      ),
    );

    expect(find.text('—'), findsOneWidget);
  });
}

String _format(double value) => '\$${value.toStringAsFixed(0)}';
