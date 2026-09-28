import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../l10n/app_localizations.dart';
import '../l10n/fun_l10n.dart';
import '../l10n/l10n_extensions.dart';
import '../router/stats_route.dart';
import '../theme/app_theme.dart';
import '../utils/locale_formatting.dart';
import '../utils/stats_breakdown.dart';
import '../utils/stats_colors.dart';

/// Labels for the buckets of one series, short for an axis, long for a row.
class StatsBucketLabels {
  final List<StatsBucket> series;
  final StatsInterval interval;
  final LocaleFormatting format;
  final AppLocalizations l10n;

  const StatsBucketLabels({
    required this.series,
    required this.interval,
    required this.format,
    required this.l10n,
  });

  bool get _spansYears =>
      series.isNotEmpty && series.first.start.year != series.last.start.year;

  String axis(DateTime start) => switch (interval) {
    StatsInterval.day || StatsInterval.week => format.formatDayMonth(start),
    StatsInterval.month =>
      _spansYears
          ? format.formatShortMonthYear(start)
          : format.formatShortMonth(start),
    StatsInterval.quarter => l10n.statsQuarterLabel(
      (start.month - 1) ~/ 3 + 1,
      start.year,
    ),
    StatsInterval.year => '${start.year}',
  };

  String long(DateTime start) => switch (interval) {
    StatsInterval.day => format.formatMediumDate(start),
    StatsInterval.week => l10n.statsWeekOf(format.formatMediumDate(start)),
    StatsInterval.month => format.formatMonthYear(start),
    _ => axis(start),
  };
}

/// One drawn series: a type, a part of a type, or the net of two.
class _Series {
  final String label;
  final Color color;
  final double Function(StatsBucket bucket) valueOf;
  final bool isNet;

  const _Series(this.label, this.color, this.valueOf, {this.isNet = false});
}

/// [types] as a series over time in one chart: grouped bars or lines, one
/// per type, or with [byParts] each type cut into [splitKeys], stacked as
/// bars or one line per part, in shades of the type's own hue. [showNet]
/// draws income less expenses as a curve over the bars or a line among
/// the others. A tap on a bar or point hands its bucket to [onOpenBucket].
class StatsSeriesChart extends StatelessWidget {
  final List<StatsBucket> series;
  final List<TransactionTypeFilter> types;
  final StatsInterval interval;
  final StatsChart chart;
  final bool byParts;
  final bool showNet;
  final List<String> splitKeys;
  final String Function(String key) splitLabel;
  final String currency;
  final LocaleFormatting format;
  final FunL10n fun;
  final ValueChanged<StatsBucket> onOpenBucket;

  const StatsSeriesChart({
    super.key,
    required this.series,
    required this.types,
    required this.interval,
    required this.chart,
    required this.currency,
    required this.format,
    required this.fun,
    required this.onOpenBucket,
    this.byParts = false,
    this.showNet = false,
    this.splitKeys = const [],
    this.splitLabel = _sameName,
  });

  static String _sameName(String key) => key;

  String _money(double amount) => format.formatMoney(amount, currency);

  String _typeLabel(AppLocalizations l10n, TransactionTypeFilter type) =>
      type.localizedLabel(l10n, isRaccoon: fun.isRaccoon);

  /// The shade part [i] of [type] is drawn in; what was folded into Other
  /// takes the lightest.
  Color _partColor(BuildContext context, TransactionTypeFilter type, int i) {
    final named = splitKeys.where((key) => key != kStatsOtherSplit).length;
    final count = math.max(1, named) + 1;
    final index = splitKeys[i] == kStatsOtherSplit ? count - 1 : i;
    return statsShade(context.colors, type, index, count);
  }

  List<_Series> _typeSeries(BuildContext context, AppLocalizations l10n) => [
    for (final type in types)
      _Series(
        _typeLabel(l10n, type),
        statsTypeColor(context.colors, type),
        (bucket) => bucket.totalFor(type),
      ),
  ];

  /// A series per part a type actually has; income never shows up in the
  /// legend under an expense category it holds nothing in.
  List<_Series> _partSeries(BuildContext context, AppLocalizations l10n) => [
    for (final type in types)
      for (var i = 0; i < splitKeys.length; i++)
        if (series.any((bucket) => bucket.partFor(type, splitKeys[i]) != 0))
          _Series(
            types.length > 1
                ? '${_typeLabel(l10n, type)} · ${splitLabel(splitKeys[i])}'
                : splitLabel(splitKeys[i]),
            _partColor(context, type, i),
            (bucket) => bucket.partFor(type, splitKeys[i]),
          ),
  ];

  _Series _netSeries(AppLocalizations l10n) => _Series(
    l10n.netFlow,
    kStatsNetColor,
    (bucket) => bucket.net,
    isNet: true,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final labels = StatsBucketLabels(
      series: series,
      interval: interval,
      format: format,
      l10n: l10n,
    );
    final legend = byParts
        ? _partSeries(context, l10n)
        : _typeSeries(context, l10n);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              types.length == 1
                  ? _typeLabel(l10n, types.single)
                  : l10n.statsOverTime,
              textAlign: TextAlign.center,
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: series.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noTransactionsMatchFilters,
                        style: TextStyle(color: colors.text3),
                      ),
                    )
                  : chart == StatsChart.line
                  ? _lines(context, l10n, labels)
                  : _bars(context, l10n, labels),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 8,
              children: [
                for (final line in legend) _legendItem(line.color, line.label),
                if (showNet) _legendItem(kStatsNetColor, l10n.netFlow),
              ],
            ),
            // Stacked bars take their colour from the parts, so which bar in
            // a group is which type has to be said in words.
            if (byParts && chart == StatsChart.bars && types.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                l10n.statsStackOrder(
                  types.map((type) => _typeLabel(l10n, type)).join(' · '),
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.text3, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(label),
    ],
  );

  static const _leftReserved = 56.0;
  static const _bottomReserved = 28.0;

  /// Every label when they fit, else every few, so they never overlap.
  double get _labelStep => math.max(1, (series.length / 12).ceilToDouble());

  /// The axes, drawn by the chart that shows them and only reserved by one
  /// laid over it, so both map the same values to the same pixels.
  FlTitlesData _titles(
    BuildContext context,
    StatsBucketLabels labels, {
    bool drawn = true,
  }) {
    final style = TextStyle(color: context.colors.text3, fontSize: 11);
    return FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _leftReserved,
          // The ends are rarely round figures and crowd the gridline labels.
          minIncluded: false,
          maxIncluded: false,
          getTitlesWidget: (value, meta) => drawn
              ? SideTitleWidget(
                  meta: meta,
                  child: Text(format.formatCompactNumber(value), style: style),
                )
              : const SizedBox.shrink(),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _bottomReserved,
          interval: _labelStep,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (!drawn ||
                index != value ||
                index < 0 ||
                index >= series.length) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              child: Text(labels.axis(series[index].start), style: style),
            );
          },
        ),
      ),
    );
  }

  FlGridData _grid(BuildContext context) => FlGridData(
    drawVerticalLine: false,
    getDrawingHorizontalLine: (_) =>
        FlLine(color: context.colors.border, strokeWidth: 1),
  );

  /// The value range both the bars and a curve over them are drawn on.
  (double, double) _range() {
    var low = 0.0;
    var high = 0.0;
    for (final bucket in series) {
      for (final type in types) {
        high = math.max(high, bucket.totalFor(type));
      }
      if (showNet) {
        high = math.max(high, bucket.net);
        low = math.min(low, bucket.net);
      }
    }
    if (high == 0 && low == 0) high = 1;
    final pad = (high - low) * 0.08;
    return (low < 0 ? low - pad : 0, high + pad);
  }

  Widget _bars(
    BuildContext context,
    AppLocalizations l10n,
    StatsBucketLabels labels,
  ) {
    final colors = context.colors;
    final (minY, maxY) = _range();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Rods take most of each group's share of the width, up to a cap
        // that keeps a short series from turning into slabs.
        final perGroup = (constraints.maxWidth - _leftReserved) / series.length;
        final rodWidth = (perGroup * 0.7 / types.length).clamp(2.0, 26.0);
        final bars = BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            minY: minY,
            maxY: maxY,
            barGroups: [
              for (var i = 0; i < series.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 2,
                  barRods: [
                    for (final type in types)
                      BarChartRodData(
                        toY: series[i].totalFor(type),
                        color: byParts
                            ? Colors.transparent
                            : statsTypeColor(colors, type),
                        rodStackItems: byParts
                            ? _stackItems(context, series[i], type)
                            : const [],
                        width: rodWidth,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                  ],
                ),
            ],
            titlesData: _titles(context, labels),
            gridData: _grid(context),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => colors.surface2,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final type = types[rodIndex];
                  final bucket = series[groupIndex];
                  return BarTooltipItem(
                    '${_typeLabel(l10n, type)}\n${_money(rod.toY)}',
                    TextStyle(
                      color: statsTypeColor(colors, type),
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      if (byParts) ..._partLines(context, bucket, type),
                      if (showNet && rodIndex == types.length - 1)
                        TextSpan(
                          text: '\n${l10n.netFlow}: ${_money(bucket.net)}',
                          style: const TextStyle(
                            color: kStatsNetColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  );
                },
              ),
              touchCallback: (event, response) {
                final spot = response?.spot;
                if (event is FlTapUpEvent && spot != null) {
                  onOpenBucket(series[spot.touchedBarGroupIndex]);
                }
              },
            ),
          ),
        );
        if (!showNet) return bars;
        // The net rides over the bars as a curve, on a line chart laid on
        // top with the same range and the same axes reserved: bars spaced
        // around their slots centre each on (i + 0.5) / n of the width,
        // which is where x = i lands between -0.5 and n - 0.5.
        return Stack(
          children: [
            Positioned.fill(child: bars),
            Positioned.fill(
              child: IgnorePointer(
                child: LineChart(
                  LineChartData(
                    minX: -0.5,
                    maxX: series.length - 0.5,
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < series.length; i++)
                            FlSpot(i.toDouble(), series[i].net),
                        ],
                        color: kStatsNetColor,
                        barWidth: 3,
                        isCurved: true,
                        preventCurveOverShooting: true,
                        dotData: FlDotData(show: series.length <= 40),
                      ),
                    ],
                    titlesData: _titles(context, labels, drawn: false),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<BarChartRodStackItem> _stackItems(
    BuildContext context,
    StatsBucket bucket,
    TransactionTypeFilter type,
  ) {
    final items = <BarChartRodStackItem>[];
    var from = 0.0;
    for (var i = 0; i < splitKeys.length; i++) {
      final value = bucket.partFor(type, splitKeys[i]);
      if (value == 0) continue;
      items.add(
        BarChartRodStackItem(from, from + value, _partColor(context, type, i)),
      );
      from += value;
    }
    return items;
  }

  List<TextSpan> _partLines(
    BuildContext context,
    StatsBucket bucket,
    TransactionTypeFilter type,
  ) => [
    for (var i = 0; i < splitKeys.length; i++)
      if (bucket.partFor(type, splitKeys[i]) != 0)
        TextSpan(
          text:
              '\n${splitLabel(splitKeys[i])}: ${_money(bucket.partFor(type, splitKeys[i]))}',
          style: TextStyle(
            color: _partColor(context, type, i),
            fontWeight: FontWeight.w500,
          ),
        ),
  ];

  Widget _lines(
    BuildContext context,
    AppLocalizations l10n,
    StatsBucketLabels labels,
  ) {
    final colors = context.colors;
    final lines = [
      ...(byParts ? _partSeries(context, l10n) : _typeSeries(context, l10n)),
      if (showNet) _netSeries(l10n),
    ];
    return LineChart(
      LineChartData(
        lineBarsData: [
          for (final line in lines)
            LineChartBarData(
              spots: [
                for (var i = 0; i < series.length; i++)
                  FlSpot(i.toDouble(), line.valueOf(series[i])),
              ],
              color: line.color,
              barWidth: line.isNet ? 3 : 2.5,
              isCurved: line.isNet,
              preventCurveOverShooting: true,
              dotData: FlDotData(show: series.length <= 40),
            ),
        ],
        titlesData: _titles(context, labels),
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.surface2,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${lines[spot.barIndex].label}: ${_money(spot.y)}',
                  TextStyle(
                    color: lines[spot.barIndex].color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          touchCallback: (event, response) {
            final spots = response?.lineBarSpots;
            if (event is FlTapUpEvent && spots != null && spots.isNotEmpty) {
              onOpenBucket(series[spots.first.x.round()]);
            }
          },
        ),
      ),
    );
  }
}

/// The figures behind a series, a row per bucket and a column per type,
/// plus the net when shown, with totals; a tap on a row opens its bucket.
class StatsSeriesTable extends StatelessWidget {
  final List<StatsBucket> series;
  final List<TransactionTypeFilter> types;
  final StatsInterval interval;
  final bool showNet;
  final String currency;
  final LocaleFormatting format;
  final FunL10n fun;
  final ValueChanged<StatsBucket> onOpenBucket;

  const StatsSeriesTable({
    super.key,
    required this.series,
    required this.types,
    required this.interval,
    required this.showNet,
    required this.currency,
    required this.format,
    required this.fun,
    required this.onOpenBucket,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final labels = StatsBucketLabels(
      series: series,
      interval: interval,
      format: format,
      l10n: l10n,
    );
    final columns = <(String, Color, double Function(StatsBucket))>[
      for (final type in types)
        (
          type.localizedLabel(l10n, isRaccoon: fun.isRaccoon),
          statsTypeColor(colors, type),
          (bucket) => bucket.totalFor(type),
        ),
      if (showNet) (l10n.netFlow, kStatsNetColor, (bucket) => bucket.net),
    ];
    const money = TextStyle(
      fontFamily: 'Roboto Slab',
      fontWeight: FontWeight.w600,
    );
    String amount(double value) => format.formatMoney(value, currency);
    Widget cell(String text, {TextStyle? style, bool end = true}) => Expanded(
      flex: end ? 2 : 3,
      child: Text(
        text,
        textAlign: end ? TextAlign.end : TextAlign.start,
        style: style,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                cell(
                  l10n.statsTablePeriod,
                  end: false,
                  style: TextStyle(color: colors.text3),
                ),
                for (final (label, color, _) in columns)
                  cell(label, style: TextStyle(color: color)),
              ],
            ),
            const Divider(height: 24),
            for (final bucket in series)
              InkWell(
                onTap: () => onOpenBucket(bucket),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      cell(labels.long(bucket.start), end: false),
                      for (final (_, _, valueOf) in columns)
                        cell(amount(valueOf(bucket)), style: money),
                    ],
                  ),
                ),
              ),
            const Divider(height: 24),
            Row(
              children: [
                cell(
                  l10n.statsTableTotal,
                  end: false,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final (_, _, valueOf) in columns)
                  cell(
                    amount(
                      series.fold(0.0, (sum, bucket) => sum + valueOf(bucket)),
                    ),
                    style: money.copyWith(fontWeight: FontWeight.w800),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
