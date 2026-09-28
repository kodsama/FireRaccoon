import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/l10n/app_localizations_en.dart';
import 'package:fireraccoon/l10n/fun_l10n.dart';
import 'package:fireraccoon/router/stats_route.dart';
import 'package:fireraccoon/utils/locale_formatting.dart';
import 'package:fireraccoon/utils/stats_breakdown.dart';
import 'package:fireraccoon/widgets/stats_over_time.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../helpers/localized_test_app.dart';

void main() {
  const expense = TransactionTypeFilter.expense;
  final july = StatsBucket(
    bounds: DateRangeBounds(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 8, 1),
    ),
    totals: const {expense: 100},
    parts: const {
      expense: {'Rent': 70, 'Food': 30},
    },
  );

  Future<void> pumpChart(WidgetTester tester, StatsChart chart) async {
    await tester.pumpWidget(
      buildLocalizedTestApp(
        child: SizedBox(
          width: 800,
          child: SingleChildScrollView(
            child: StatsSeriesChart(
              series: [july],
              types: const [expense],
              interval: StatsInterval.month,
              chart: chart,
              byParts: true,
              splitKeys: const ['Rent', 'Food'],
              currency: '€',
              format: LocaleFormatting(const Locale('en')),
              fun: FunL10n(AppLocalizationsEn(), isRaccoon: false),
              onOpenBucket: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The pixel of [value] halfway along the chart, as the chart lays it out:
  /// 56px of axis on the left, 28px along the bottom, and the top 8% of the
  /// range kept as headroom.
  Offset at(WidgetTester tester, Type chart, double value, {double top = 100}) {
    final rect = tester.getRect(find.byType(chart));
    final maxY = top * 1.08;
    final plotHeight = rect.height - 28;
    return Offset(
      rect.left + 56 + (rect.width - 56) / 2,
      rect.top + plotHeight * (1 - value / maxY),
    );
  }

  testWidgets('hovering a stacked bar names the part under the pointer', (
    tester,
  ) async {
    await pumpChart(tester, StatsChart.bars);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);

    // Rent is stacked first, from 0 to 70; Food sits on it up to 100.
    await mouse.moveTo(at(tester, BarChart, 35));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsWidgets);
    expect(find.text('Expenses · July 2026'), findsOneWidget);
    expect(find.text('70.0% · €70.00'), findsOneWidget);

    await mouse.moveTo(at(tester, BarChart, 85));
    await tester.pumpAndSettle();
    expect(find.text('30.0% · €30.00'), findsOneWidget);
    expect(find.text('70.0% · €70.00'), findsNothing);
  });

  testWidgets('hovering lines names the one nearest the pointer', (
    tester,
  ) async {
    await pumpChart(tester, StatsChart.line);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);

    // Rent's line runs at 70, Food's at 30.
    await mouse.moveTo(at(tester, LineChart, 30, top: 70));
    await tester.pumpAndSettle();
    expect(find.text('€30.00'), findsOneWidget);
    expect(find.text('€70.00'), findsNothing);
  });

  testWidgets('hovering the net curve over the bars names the net', (
    tester,
  ) async {
    const income = TransactionTypeFilter.income;
    final month = StatsBucket(
      bounds: DateRangeBounds(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      ),
      totals: const {expense: 100, income: 150},
    );
    await tester.pumpWidget(
      buildLocalizedTestApp(
        child: SizedBox(
          width: 800,
          child: SingleChildScrollView(
            child: StatsSeriesChart(
              series: [month],
              types: const [expense, income],
              interval: StatsInterval.month,
              chart: StatsChart.bars,
              showNet: true,
              currency: '€',
              format: LocaleFormatting(const Locale('en')),
              fun: FunL10n(AppLocalizationsEn(), isRaccoon: false),
              onOpenBucket: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);

    // The net, 150 less 100, sits at 50 on a range topped at 150 plus 8%.
    await mouse.moveTo(at(tester, BarChart, 50, top: 150));
    await tester.pumpAndSettle();
    expect(find.text('Net'), findsWidgets);
    expect(find.text('€50.00'), findsOneWidget);

    // Well above the curve, on the income bar, the bar is named instead.
    await mouse.moveTo(
      at(tester, BarChart, 130, top: 150) + const Offset(10, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('€150.00'), findsOneWidget);
  });
}
