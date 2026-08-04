import 'dart:math';

import '../models/account.dart';
import '../models/projection.dart';
import '../models/transaction.dart';

/// Pure Dart projection engine — server-agnostic, on-device.
class ProjectionService {
  static const _discretionaryShare = 0.35;
  static const _avgDaysPerMonth = 30.437;

  /// Derive cash-flow stats from transactions.
  ///
  /// When [normalizeToMonthly] is true (default), totals are divided by the
  /// span of the transaction window so callers can treat results as monthly
  /// rates. An empty list still returns zeros (callers apply fallbacks).
  static ({double income, double expenses, double net, double discretionary})
  cashFlowStats(
    List<Transaction> transactions, {
    bool normalizeToMonthly = true,
  }) {
    final deposits = transactions
        .where((t) => t.type == 'deposit')
        .fold(0.0, (s, t) => s + t.totalAmount);
    final withdrawals = transactions
        .where((t) => t.type == 'withdrawal')
        .fold(0.0, (s, t) => s + t.totalAmount);
    final divisor = normalizeToMonthly ? _monthsCovered(transactions) : 1.0;
    final expenses = withdrawals / divisor;
    final income = deposits / divisor;
    final net = income - expenses;
    final effectiveExpenses = expenses != 0 ? expenses : 1500.0;
    final discretionary = effectiveExpenses * _discretionaryShare;
    return (
      income: income,
      expenses: expenses,
      net: net,
      discretionary: discretionary,
    );
  }

  /// Months spanned by [transactions], minimum 1.
  static double _monthsCovered(List<Transaction> transactions) {
    if (transactions.length < 2) return 1.0;
    DateTime? minDate;
    DateTime? maxDate;
    for (final t in transactions) {
      final d = t.date;
      if (minDate == null || d.isBefore(minDate)) minDate = d;
      if (maxDate == null || d.isAfter(maxDate)) maxDate = d;
    }
    final spanDays = maxDate!.difference(minDate!).inDays + 1;
    return max(1.0, spanDays / _avgDaysPerMonth);
  }

  /// Build a historical balance series from current balance and net flow.
  static List<double> buildHistorical({
    required double currentBalance,
    required double monthlyNet,
    required int points,
  }) {
    if (points <= 0) return [currentBalance];
    return List.generate(points, (i) {
      final stepsBack = points - 1 - i;
      return max(0, currentBalance - monthlyNet * stepsBack);
    });
  }

  /// Run a full projection with worst / expected / best scenarios.
  static ProjectionResult project({
    required double currentBalance,
    required List<Transaction> transactions,
    required ProjectionParams params,
    List<Account>? accounts,
  }) {
    final stats = cashFlowStats(transactions);
    final histPoints = min(10, max(4, params.months ~/ 2));
    final historical = buildHistorical(
      currentBalance: currentBalance,
      monthlyNet: stats.net != 0 ? stats.net : 100,
      points: histPoints,
    );

    final steps = params.months;
    final start = currentBalance;

    final (expected, worst, best) = switch (params.type) {
      ProjectionType.savings => _savingsProjection(
        start: start,
        monthlyNet: stats.net != 0 ? stats.net : 100,
        discretionary: stats.discretionary,
        whatIfPercent: params.whatIfPercent,
        steps: steps,
        volatility: params.volatilityPercent,
      ),
      ProjectionType.compound => _compoundProjection(
        start: start,
        monthlyContribution: stats.net > 0 ? stats.net : 100,
        annualReturn: params.annualReturnPercent,
        whatIfPercent: params.whatIfPercent,
        discretionary: stats.discretionary,
        steps: steps,
      ),
      ProjectionType.portfolio => _portfolioProjection(
        start: start,
        monthlyContribution: stats.net > 0 ? stats.net : 100,
        annualReturn: params.annualReturnPercent,
        volatility: params.volatilityPercent,
        whatIfPercent: params.whatIfPercent,
        discretionary: stats.discretionary,
        steps: steps,
      ),
      ProjectionType.cashflow => _cashflowProjection(
        start: start,
        income: stats.income != 0 ? stats.income : 2000,
        expenses: stats.expenses != 0 ? stats.expenses : 1500,
        discretionary: stats.discretionary,
        whatIfPercent: params.whatIfPercent,
        steps: steps,
      ),
    };

    final alert = _detectAlert(
      worst: worst,
      accounts: accounts,
      currentBalance: currentBalance,
    );

    return ProjectionResult(
      historical: historical,
      expected: expected,
      worst: worst,
      best: best,
      historyCount: historical.length,
      alert: alert,
    );
  }

  /// Per-account predictions at horizon.
  static List<AccountProjection> projectAccounts({
    required List<Account> accounts,
    required ProjectionParams params,
    required double whatIfBoost,
  }) {
    final growthFactor = switch (params.type) {
      ProjectionType.savings => 1 + (params.months / 12) * 0.03,
      ProjectionType.compound => pow(
        1 + params.annualReturnPercent / 100 / 12,
        params.months,
      ).toDouble(),
      ProjectionType.portfolio => pow(
        1 + params.annualReturnPercent / 100 / 12,
        params.months,
      ).toDouble(),
      ProjectionType.cashflow => 1 + (params.months / 12) * 0.025,
    };

    return accounts.map((a) {
      final isLiability = a.type == 'liability' || a.currentBalance < 0;
      final liabilityFactor = isLiability ? 0.96 : 1.0;
      var predicted = a.currentBalance * growthFactor * liabilityFactor;
      if (!isLiability && a.role == 'defaultAsset') {
        predicted += whatIfBoost;
      }
      return AccountProjection(
        name: a.name,
        icon: _iconForAccount(a),
        current: a.currentBalance,
        predicted: predicted,
        isLiability: isLiability,
      );
    }).toList();
  }

  static String _iconForAccount(Account a) {
    if (a.type == 'liability') return 'credit-card';
    if (a.role == 'savingAsset') return 'piggy-bank';
    if (a.type == 'asset') return 'wallet';
    return 'landmark';
  }

  static ProjectionAlert? _detectAlert({
    required List<double> worst,
    required List<Account>? accounts,
    required double currentBalance,
  }) {
    if (worst.any((v) => v < 0)) {
      final liability = accounts
          ?.where((a) => a.type == 'liability')
          .firstOrNull;
      if (liability != null && liability.currentBalance < 0) {
        return ProjectionAlert(
          kind: ProjectionAlertKind.liabilityRisk,
          liabilityName: liability.name,
          liabilityBalance: liability.currentBalance,
        );
      }
      if (currentBalance > 0) {
        return const ProjectionAlert(kind: ProjectionAlertKind.belowZero);
      }
    }
    return null;
  }

  static (List<double>, List<double>, List<double>) _savingsProjection({
    required double start,
    required double monthlyNet,
    required double discretionary,
    required int whatIfPercent,
    required int steps,
    required double volatility,
  }) {
    final savingsBoost = discretionary * (whatIfPercent / 100);
    final adjustedNet = monthlyNet + savingsBoost;
    final bandBase = max(50.0, monthlyNet.abs() * 0.15 + volatility * 2);

    return _buildScenarios(
      start: start,
      steps: steps,
      expectedAt: (i) => start + adjustedNet * i,
      bandAt: (i) => bandBase * sqrt(i.toDouble()) + i * 20,
    );
  }

  static (List<double>, List<double>, List<double>) _compoundProjection({
    required double start,
    required double monthlyContribution,
    required double annualReturn,
    required int whatIfPercent,
    required double discretionary,
    required int steps,
  }) {
    final monthlyRate = annualReturn / 100 / 12;
    final boost = discretionary * (whatIfPercent / 100);
    final contribution = monthlyContribution + boost;

    return _buildScenarios(
      start: start,
      steps: steps,
      expectedAt: (i) {
        if (monthlyRate == 0) return start + contribution * i;
        return start * pow(1 + monthlyRate, i) +
            contribution * ((pow(1 + monthlyRate, i) - 1) / monthlyRate);
      },
      bandAt: (i) => start * 0.02 * sqrt(i.toDouble()) + i * 15,
    );
  }

  static (List<double>, List<double>, List<double>) _portfolioProjection({
    required double start,
    required double monthlyContribution,
    required double annualReturn,
    required double volatility,
    required int whatIfPercent,
    required double discretionary,
    required int steps,
  }) {
    final monthlyReturn = annualReturn / 100 / 12;
    final monthlyVol = volatility / 100 / sqrt(12);
    final boost = discretionary * (whatIfPercent / 100);
    final contribution = monthlyContribution + boost;

    return _buildScenarios(
      start: start,
      steps: steps,
      expectedAt: (i) {
        if (monthlyReturn == 0) return start + contribution * i;
        return start * pow(1 + monthlyReturn, i) +
            contribution * ((pow(1 + monthlyReturn, i) - 1) / monthlyReturn);
      },
      bandAt: (i) {
        final volBand = start * monthlyVol * sqrt(i.toDouble()) * 1.65;
        return volBand + i * 25;
      },
    );
  }

  static (List<double>, List<double>, List<double>) _cashflowProjection({
    required double start,
    required double income,
    required double expenses,
    required double discretionary,
    required int whatIfPercent,
    required int steps,
  }) {
    final cut = discretionary * (whatIfPercent / 100);
    final monthlyNet = income - expenses + cut;

    return _buildScenarios(
      start: start,
      steps: steps,
      expectedAt: (i) => start + monthlyNet * i,
      bandAt: (i) {
        final incomeVariance = income * 0.08 * sqrt(i.toDouble());
        final expenseVariance = expenses * 0.12 * sqrt(i.toDouble());
        return incomeVariance + expenseVariance + i * 18;
      },
    );
  }

  static (List<double>, List<double>, List<double>) _buildScenarios({
    required double start,
    required int steps,
    required double Function(int month) expectedAt,
    required double Function(int month) bandAt,
  }) {
    final expected = <double>[start];
    final worst = <double>[start];
    final best = <double>[start];

    for (var i = 1; i <= steps; i++) {
      final exp = expectedAt(i);
      final band = bandAt(i);
      // Clamp expected/best for chart readability; leave worst unclamped so
      // below-zero / liability alerts can fire.
      expected.add(max(0, exp));
      worst.add(exp - band);
      best.add(exp + band);
    }

    return (expected, worst, best);
  }

  /// What-if savings boost over the projection period.
  static double whatIfImpact({
    required double discretionary,
    required int whatIfPercent,
    required int months,
  }) {
    return discretionary * (whatIfPercent / 100) * months;
  }
}
