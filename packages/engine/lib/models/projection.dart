/// Financial projection type — each uses different parameters and math.
enum ProjectionType {
  savings,
  compound,
  portfolio,
  cashflow;

  String get label => switch (this) {
    ProjectionType.savings => 'Savings rate',
    ProjectionType.compound => 'Compound growth',
    ProjectionType.portfolio => 'Portfolio (volatile)',
    ProjectionType.cashflow => 'Cash flow',
  };

  String get description => switch (this) {
    ProjectionType.savings =>
      'Linear projection from your historical net savings',
    ProjectionType.compound =>
      'Balance grows with compound interest plus contributions',
    ProjectionType.portfolio =>
      'Expected return with worst/best bands from volatility',
    ProjectionType.cashflow =>
      'Income minus expenses with discretionary adjustments',
  };
}

/// How the projection chart is rendered.
enum ProjectionChartStyle {
  fan,
  lines,
  scenarios;

  String get label => switch (this) {
    ProjectionChartStyle.fan => 'Fan chart',
    ProjectionChartStyle.lines => 'Three lines',
    ProjectionChartStyle.scenarios => 'Scenario cards',
  };
}

/// Parameters that tune a projection run.
class ProjectionParams {
  final ProjectionType type;
  final int months;
  final int whatIfPercent;
  final double annualReturnPercent;
  final double volatilityPercent;
  final ProjectionChartStyle chartStyle;

  const ProjectionParams({
    this.type = ProjectionType.savings,
    this.months = 6,
    this.whatIfPercent = 0,
    this.annualReturnPercent = 7.0,
    this.volatilityPercent = 12.0,
    this.chartStyle = ProjectionChartStyle.fan,
  });

  ProjectionParams copyWith({
    ProjectionType? type,
    int? months,
    int? whatIfPercent,
    double? annualReturnPercent,
    double? volatilityPercent,
    ProjectionChartStyle? chartStyle,
  }) {
    return ProjectionParams(
      type: type ?? this.type,
      months: months ?? this.months,
      whatIfPercent: whatIfPercent ?? this.whatIfPercent,
      annualReturnPercent: annualReturnPercent ?? this.annualReturnPercent,
      volatilityPercent: volatilityPercent ?? this.volatilityPercent,
      chartStyle: chartStyle ?? this.chartStyle,
    );
  }
}

/// A single time-series projection with worst / expected / best paths.
class ProjectionResult {
  final List<double> historical;
  final List<double> expected;
  final List<double> worst;
  final List<double> best;
  final int historyCount;
  final ProjectionAlert? alert;

  const ProjectionResult({
    required this.historical,
    required this.expected,
    required this.worst,
    required this.best,
    required this.historyCount,
    this.alert,
  });

  double get startBalance => historical.isNotEmpty ? historical.last : 0;

  double get endExpected => expected.isNotEmpty ? expected.last : startBalance;

  double get endWorst => worst.isNotEmpty ? worst.last : startBalance;

  double get endBest => best.isNotEmpty ? best.last : startBalance;

  double growthPercent(double base) {
    if (base == 0) return 0;
    return ((endExpected - base) / base.abs()) * 100;
  }
}

/// Alert when a projection crosses a danger threshold.
enum ProjectionAlertKind { liabilityRisk, belowZero }

class ProjectionAlert {
  final ProjectionAlertKind kind;
  final String? liabilityName;
  final double? liabilityBalance;

  const ProjectionAlert({
    required this.kind,
    this.liabilityName,
    this.liabilityBalance,
  });
}

/// Per-account predicted balance at horizon.
class AccountProjection {
  final String name;
  final String icon;
  final double current;
  final double predicted;
  final bool isLiability;

  const AccountProjection({
    required this.name,
    required this.icon,
    required this.current,
    required this.predicted,
    this.isLiability = false,
  });

  double get change => predicted - current;
}
