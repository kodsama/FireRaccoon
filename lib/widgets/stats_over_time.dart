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

/// One line or set of bars in the chart: a type, or the net of two.
class _Series {
  final String label;
  final Color color;
  final double Function(StatsBucket bucket) valueOf;

  /// The type the series sums, `null` for the net.
  final TransactionTypeFilter? type;

  const _Series(this.label, this.color, this.valueOf, {this.type});
}

/// The selected types as a series over time, as bars or lines, with a table
/// of the same figures under it. A tap on a bar, point or row hands its
/// bucket to [onOpenBucket].
class StatsOverTime extends StatelessWidget {
  final List<StatsBucket> series;
  final List<TransactionTypeFilter> types;
  final StatsInterval interval;
  final StatsChart chart;
  final bool showNet;
  final String currency;
  final LocaleFormatting format;
  final FunL10n fun;
  final ValueChanged<StatsBucket> onOpenBucket;

  /// The parts a stacked bar is cut into, in stacking order, and their names.
  final List<String> splitKeys;
  final String Function(String key) splitLabel;

  const StatsOverTime({
    super.key,
    required this.series,
    required this.types,
    required this.interval,
    required this.chart,
    required this.showNet,
    required this.currency,
    required this.format,
    required this.fun,
    required this.onOpenBucket,
    this.splitKeys = const [],
    this.splitLabel = _sameName,
  });

  static String _sameName(String key) => key;

  bool get _stacked => chart == StatsChart.stacked;

  /// Parts take the palette in order, and what was folded into the rest
  /// takes a quiet grey so the named parts stand out.
  Color _partColor(BuildContext context, int index) {
    final colors = context.colors;
    if (splitKeys[index] == kStatsOtherSplit) return colors.text3;
    final palette = [
      colors.accent.acc,
      colors.warning,
      colors.danger,
      colors.success,
      colors.accent.deep,
      colors.accent.hi,
    ];
    return palette[index % palette.length];
  }

  List<_Series> _seriesFor(BuildContext context, AppLocalizations l10n) {
    final colors = context.colors;
    return [
      for (final type in types)
        _Series(
          type.localizedLabel(l10n, isRaccoon: fun.isRaccoon),
          switch (type) {
            TransactionTypeFilter.expense => colors.danger,
            TransactionTypeFilter.income => colors.success,
            _ => colors.accent.acc,
          },
          (bucket) => bucket.totalFor(type),
          type: type,
        ),
      if (showNet) _Series(l10n.netFlow, colors.text2, (bucket) => bucket.net),
    ];
  }

  bool get _spansYears =>
      series.isNotEmpty && series.first.start.year != series.last.start.year;

  String _axisLabel(DateTime start, AppLocalizations l10n) =>
      switch (interval) {
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

  String _longLabel(DateTime start, AppLocalizations l10n) =>
      switch (interval) {
        StatsInterval.day => format.formatMediumDate(start),
        StatsInterval.week => l10n.statsWeekOf(format.formatMediumDate(start)),
        StatsInterval.month => format.formatMonthYear(start),
        _ => _axisLabel(start, l10n),
      };

  String _money(double amount) => format.formatMoney(amount, currency);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final lines = _seriesFor(context, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.statsOverTime,
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
                      ? _lines(context, lines, l10n)
                      : _bars(context, lines, l10n),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    if (_stacked)
                      for (var i = 0; i < splitKeys.length; i++)
                        _legendItem(
                          _partColor(context, i),
                          splitLabel(splitKeys[i]),
                        ),
                    if (!_stacked)
                      for (final line in lines)
                        _legendItem(line.color, line.label),
                  ],
                ),
                // Stacked bars take their colour from the parts, so which bar
                // in a group is which type has to be said in words.
                if (_stacked && lines.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.statsStackOrder(
                      lines.map((line) => line.label).join(' · '),
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.text3, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _table(context, lines, l10n),
      ],
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

  /// Every label when they fit, else every few, so they never overlap.
  double get _labelStep => math.max(1, (series.length / 12).ceilToDouble());

  FlTitlesData _titles(BuildContext context, AppLocalizations l10n) {
    final style = TextStyle(color: context.colors.text3, fontSize: 11);
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 56,
          // The ends are rarely round figures and crowd the gridline labels.
          minIncluded: false,
          maxIncluded: false,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            child: Text(format.formatCompactNumber(value), style: style),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: _labelStep,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index != value || index < 0 || index >= series.length) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              child: Text(_axisLabel(series[index].start, l10n), style: style),
            );
          },
        ),
      ),
    );
  }

  Widget _bars(
    BuildContext context,
    List<_Series> lines,
    AppLocalizations l10n,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Rods take most of each group's share of the width, up to a cap
        // that keeps a short series from turning into slabs.
        final perGroup = (constraints.maxWidth - 56) / series.length;
        final rodWidth = (perGroup * 0.7 / lines.length).clamp(2.0, 22.0);
        return _barChart(context, lines, l10n, rodWidth);
      },
    );
  }

  Widget _barChart(
    BuildContext context,
    List<_Series> lines,
    AppLocalizations l10n,
    double rodWidth,
  ) {
    final colors = context.colors;
    return BarChart(
      BarChartData(
        barGroups: [
          for (var i = 0; i < series.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                for (final line in lines)
                  BarChartRodData(
                    toY: line.valueOf(series[i]),
                    color: _stacked ? Colors.transparent : line.color,
                    rodStackItems: _stacked
                        ? _stackItems(context, series[i], line.type!)
                        : const [],
                    width: rodWidth,
                    borderRadius: BorderRadius.circular(3),
                  ),
              ],
            ),
        ],
        titlesData: _titles(context, l10n),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: colors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colors.surface2,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  '${lines[rodIndex].label}\n${_money(rod.toY)}',
                  TextStyle(
                    color: _stacked ? colors.text : lines[rodIndex].color,
                    fontWeight: FontWeight.w600,
                  ),
                  children: _stacked
                      ? _partLines(
                          context,
                          series[groupIndex],
                          lines[rodIndex].type!,
                        )
                      : null,
                ),
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
        BarChartRodStackItem(from, from + value, _partColor(context, i)),
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
            color: _partColor(context, i),
            fontWeight: FontWeight.w500,
          ),
        ),
  ];

  Widget _lines(
    BuildContext context,
    List<_Series> lines,
    AppLocalizations l10n,
  ) {
    final colors = context.colors;
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
              barWidth: 2.5,
              dotData: FlDotData(show: series.length <= 40),
            ),
        ],
        titlesData: _titles(context, l10n),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: colors.border, strokeWidth: 1),
        ),
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

  Widget _table(
    BuildContext context,
    List<_Series> lines,
    AppLocalizations l10n,
  ) {
    final colors = context.colors;
    const money = TextStyle(
      fontFamily: 'Roboto Slab',
      fontWeight: FontWeight.w600,
    );
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
                for (final line in lines)
                  cell(line.label, style: TextStyle(color: line.color)),
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
                      cell(_longLabel(bucket.start, l10n), end: false),
                      for (final line in lines)
                        cell(_money(line.valueOf(bucket)), style: money),
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
                for (final line in lines)
                  cell(
                    _money(
                      series.fold(
                        0.0,
                        (sum, bucket) => sum + line.valueOf(bucket),
                      ),
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
