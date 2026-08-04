import '../models/account.dart';
import '../models/account_prognosis.dart';
import '../models/bill.dart';
import '../models/recurrence.dart';
import '../models/transaction.dart';
import '../utils/account_balance.dart';
import 'recurrence_scheduler.dart';

class BillAccountTemplate {
  final String transactionType;
  final String? sourceId;
  final String? sourceName;
  final String? destinationId;
  final String? destinationName;

  const BillAccountTemplate({
    required this.transactionType,
    this.sourceId,
    this.sourceName,
    this.destinationId,
    this.destinationName,
  });
}

DateTime prognosisEndOfNextMonth(DateTime reference) =>
    DateTime(reference.year, reference.month + 2, 1);

class AccountPrognosisService {
  static AccountPrognosisResult compute({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required List<Bill> bills,
    required List<Recurrence> recurrences,
    PrognosisOptions options = const PrognosisOptions(),
  }) {
    final reference = options.reference ?? DateTime.now();
    final endOfThisMonth = prognosisHorizonEnd(
      reference,
      PrognosisHorizon.endOfMonth,
    );
    final endOfNextMonth = prognosisHorizonEnd(
      reference,
      PrognosisHorizon.endOfNextMonth,
    );
    final horizonEnd = prognosisHorizonEnd(reference, options.horizon);
    final rangeStart = prognosisStartOfDay(
      reference,
    ).add(const Duration(days: 1));
    final flowHorizonEnd = prognosisStartOfDay(
      horizonEnd,
    ).add(const Duration(days: 1));

    if (options.mode == PrognosisViewMode.projected) {
      return _computeProjected(
        accounts: accounts,
        transactions: transactions,
        reference: reference,
        endOfThisMonth: endOfThisMonth,
        endOfNextMonth: endOfNextMonth,
        horizonEnd: horizonEnd,
        options: options,
      );
    }

    return _computeExpected(
      accounts: accounts,
      transactions: transactions,
      bills: bills,
      recurrences: recurrences,
      reference: reference,
      rangeStart: rangeStart,
      flowHorizonEnd: flowHorizonEnd,
      endOfThisMonth: endOfThisMonth,
      endOfNextMonth: endOfNextMonth,
      horizonEnd: horizonEnd,
      options: options,
    );
  }

  static AccountPrognosisResult _computeExpected({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required List<Bill> bills,
    required List<Recurrence> recurrences,
    required DateTime reference,
    required DateTime rangeStart,
    required DateTime flowHorizonEnd,
    required DateTime endOfThisMonth,
    required DateTime endOfNextMonth,
    required DateTime horizonEnd,
    required PrognosisOptions options,
  }) {
    final accountsById = {for (final account in accounts) account.id: account};
    final accountsByName = {
      for (final account in accounts) account.name: account,
    };
    final billTemplates = _inferBillTemplates(transactions, accounts);

    final flows = <ScheduledCashFlow>[
      ..._scheduledTransactionFlows(
        transactions: transactions,
        rangeStart: rangeStart,
        rangeEnd: flowHorizonEnd,
        accountsById: accountsById,
        accountsByName: accountsByName,
      ),
      ..._recurrenceFlows(
        recurrences: recurrences,
        rangeStart: rangeStart,
        rangeEnd: flowHorizonEnd,
      ),
      ..._billFlows(
        bills: bills,
        billTemplates: billTemplates,
        transactions: transactions,
        rangeStart: rangeStart,
        rangeEnd: flowHorizonEnd,
      ),
    ];

    final dedupedFlows = _dedupeFlows(flows);
    final eventsByAccount = <String, List<PrognosisEvent>>{};
    final balances = resolvedAccountBalances(
      accounts,
      transactions,
      reference: reference,
    );
    for (final account in accounts) {
      eventsByAccount[account.id] = [];
    }

    for (final flow in dedupedFlows) {
      if (!_shouldIncludeFlow(
        flow,
        options.inclusion,
        accountsById,
        accountsByName,
      )) {
        continue;
      }

      final isCcRelated = _isCreditCardRelated(
        flow,
        accountsById,
        accountsByName,
      );
      final scenarioDeltas = _flowScenarioDeltas(
        flow: flow,
        accountsById: accountsById,
        accountsByName: accountsByName,
        marginPercent: options.marginPercent,
      );

      for (final entry in scenarioDeltas.entries) {
        eventsByAccount
            .putIfAbsent(entry.key, () => [])
            .add(
              PrognosisEvent(
                date: flow.date,
                accountId: entry.key,
                expectedDelta: entry.value.expected,
                pessimisticDelta: entry.value.pessimistic,
                optimisticDelta: entry.value.optimistic,
                description: flow.description,
                source: _flowSource(flow),
                isCreditCardRelated: isCcRelated,
              ),
            );
      }
    }

    final prognoses = accounts
        .where(
          (account) => account.type == 'asset' || account.type == 'liability',
        )
        .map((account) {
          final currentBalance = balances[account.id] ?? account.currentBalance;
          final events = eventsByAccount[account.id] ?? const [];
          final sorted = [...events]..sort((a, b) => a.date.compareTo(b.date));
          final rawTimeline = _buildTimelineRaw(
            startBalance: currentBalance,
            events: sorted,
            rangeStart: prognosisStartOfDay(reference),
            rangeEnd: horizonEnd,
          );
          final timeline = _sampleTimeline(rawTimeline);
          final milestones = _buildMilestones(
            timeline: rawTimeline,
            reference: reference,
            fallback: currentBalance,
          );
          final endOfMonthSnapshot = milestones[PrognosisMilestone.endOfMonth]!;
          final endOfNextMonthSnapshot =
              milestones[PrognosisMilestone.endOfNextMonth]!;
          final firstNegativeDate = _firstNegativeDate(
            timeline: rawTimeline,
            accountType: account.type,
          );
          final showWarning = account.type == 'asset'
              ? firstNegativeDate != null
              : endOfMonthSnapshot.optimistic > currentBalance &&
                    endOfMonthSnapshot.optimistic > 0;

          return AccountPrognosis(
            accountId: account.id,
            accountName: account.name,
            accountType: account.type,
            currencySymbol: account.currencySymbol,
            currentBalance: currentBalance,
            endOfMonth: endOfMonthSnapshot,
            endOfNextMonth: endOfNextMonthSnapshot,
            milestones: milestones,
            showWarning: showWarning,
            firstNegativeDate: firstNegativeDate,
            events: sorted,
            timeline: timeline,
          );
        })
        .toList();

    return AccountPrognosisResult(
      reference: reference,
      endOfThisMonth: endOfThisMonth,
      endOfNextMonth: endOfNextMonth,
      horizonEnd: horizonEnd,
      mode: options.mode,
      horizon: options.horizon,
      accounts: prognoses,
    );
  }

  static AccountPrognosisResult _computeProjected({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required DateTime reference,
    required DateTime endOfThisMonth,
    required DateTime endOfNextMonth,
    required DateTime horizonEnd,
    required PrognosisOptions options,
  }) {
    final margin = options.marginPercent.clamp(0, 100) / 100;
    final monthlyNets = _accountMonthlyNets(accounts, transactions);
    final balances = resolvedAccountBalances(
      accounts,
      transactions,
      reference: reference,
    );

    final prognoses = accounts
        .where(
          (account) => account.type == 'asset' || account.type == 'liability',
        )
        .map((account) {
          final currentBalance = balances[account.id] ?? account.currentBalance;
          final monthlyNet = monthlyNets[account.id] ?? 0;
          final rawTimeline = _buildProjectedTimelineRaw(
            startBalance: currentBalance,
            monthlyNet: monthlyNet,
            rangeStart: prognosisStartOfDay(reference),
            rangeEnd: horizonEnd,
            marginPercent: margin,
            isLiability: account.isLiability,
          );
          final timeline = _sampleTimeline(rawTimeline);
          final milestones = _buildMilestones(
            timeline: rawTimeline,
            reference: reference,
            fallback: currentBalance,
          );
          final endOfMonthSnapshot = milestones[PrognosisMilestone.endOfMonth]!;
          final endOfNextMonthSnapshot =
              milestones[PrognosisMilestone.endOfNextMonth]!;
          final firstNegativeDate = _firstNegativeDate(
            timeline: rawTimeline,
            accountType: account.type,
          );
          final showWarning = account.type == 'asset'
              ? firstNegativeDate != null
              : endOfMonthSnapshot.optimistic > currentBalance &&
                    endOfMonthSnapshot.optimistic > 0;

          return AccountPrognosis(
            accountId: account.id,
            accountName: account.name,
            accountType: account.type,
            currencySymbol: account.currencySymbol,
            currentBalance: currentBalance,
            endOfMonth: endOfMonthSnapshot,
            endOfNextMonth: endOfNextMonthSnapshot,
            milestones: milestones,
            showWarning: showWarning,
            firstNegativeDate: firstNegativeDate,
            events: const [],
            timeline: timeline,
          );
        })
        .toList();

    return AccountPrognosisResult(
      reference: reference,
      endOfThisMonth: endOfThisMonth,
      endOfNextMonth: endOfNextMonth,
      horizonEnd: horizonEnd,
      mode: options.mode,
      horizon: options.horizon,
      accounts: prognoses,
    );
  }
}

class _ScenarioDelta {
  final double expected;
  final double pessimistic;
  final double optimistic;

  const _ScenarioDelta({
    required this.expected,
    required this.pessimistic,
    required this.optimistic,
  });
}

bool _shouldIncludeFlow(
  ScheduledCashFlow flow,
  PrognosisInclusionOptions inclusion,
  Map<String, Account> accountsById,
  Map<String, Account> accountsByName,
) {
  final isCcRelated = _isCreditCardRelated(flow, accountsById, accountsByName);
  final isCcPayment = _isCreditCardPayment(flow, accountsById, accountsByName);

  if (!inclusion.includeCreditCards && isCcRelated) return false;

  if (flow.source == ScheduledFlowSource.recurrence &&
      !inclusion.includeRecurringTransactions) {
    return false;
  }
  if (flow.source == ScheduledFlowSource.bill && !inclusion.includeBills) {
    return false;
  }
  if (flow.source == ScheduledFlowSource.transaction &&
      !inclusion.includeScheduledTransactions) {
    return false;
  }

  if (!inclusion.includeIncome && flow.transactionType == 'deposit') {
    return false;
  }
  if (!inclusion.includeExpenses && flow.transactionType == 'withdrawal') {
    return false;
  }
  if (!inclusion.includeTransfers &&
      flow.transactionType == 'transfer' &&
      !isCcPayment) {
    return false;
  }

  return true;
}

Map<String, _ScenarioDelta> _flowScenarioDeltas({
  required ScheduledCashFlow flow,
  required Map<String, Account> accountsById,
  required Map<String, Account> accountsByName,
  required double marginPercent,
}) {
  final margin = marginPercent.clamp(0, 100) / 100;
  final amounts = _flowAmounts(flow, margin);
  final result = <String, _ScenarioDelta>{};

  void applyAccountDelta(
    String? accountId,
    Account? account,
    double expectedAmount,
    double pessimisticAmount,
    double optimisticAmount, {
    required bool isSource,
    required bool isDestination,
  }) {
    if (accountId == null || account == null) return;

    final expectedSigned = _signedDelta(
      account: account,
      transactionType: flow.transactionType,
      amount: expectedAmount,
      isSource: isSource,
      isDestination: isDestination,
    );
    final altPessimisticSigned = _signedDelta(
      account: account,
      transactionType: flow.transactionType,
      amount: pessimisticAmount,
      isSource: isSource,
      isDestination: isDestination,
    );
    final altOptimisticSigned = _signedDelta(
      account: account,
      transactionType: flow.transactionType,
      amount: optimisticAmount,
      isSource: isSource,
      isDestination: isDestination,
    );

    final pessimisticSigned = account.isLiability
        ? [
            expectedSigned,
            altPessimisticSigned,
            altOptimisticSigned,
          ].reduce((a, b) => a > b ? a : b)
        : [
            expectedSigned,
            altPessimisticSigned,
            altOptimisticSigned,
          ].reduce((a, b) => a < b ? a : b);
    final optimisticSigned = account.isLiability
        ? [
            expectedSigned,
            altPessimisticSigned,
            altOptimisticSigned,
          ].reduce((a, b) => a < b ? a : b)
        : [
            expectedSigned,
            altPessimisticSigned,
            altOptimisticSigned,
          ].reduce((a, b) => a > b ? a : b);

    final existing = result[accountId];
    result[accountId] = _ScenarioDelta(
      expected: (existing?.expected ?? 0) + expectedSigned,
      pessimistic: (existing?.pessimistic ?? 0) + pessimisticSigned,
      optimistic: (existing?.optimistic ?? 0) + optimisticSigned,
    );
  }

  String? resolveId(String? id, String? name) {
    if (id != null && accountsById.containsKey(id)) return id;
    return accountsByName[name]?.id;
  }

  final sourceId = resolveId(flow.sourceId, flow.sourceName);
  final destinationId = resolveId(flow.destinationId, flow.destinationName);
  final sourceAccount = sourceId != null ? accountsById[sourceId] : null;
  final destinationAccount = destinationId != null
      ? accountsById[destinationId]
      : null;

  switch (flow.transactionType) {
    case 'deposit':
      applyAccountDelta(
        destinationId,
        destinationAccount,
        amounts.expected,
        amounts.pessimistic,
        amounts.optimistic,
        isSource: false,
        isDestination: true,
      );
    case 'withdrawal':
      applyAccountDelta(
        sourceId,
        sourceAccount,
        amounts.expected,
        amounts.pessimistic,
        amounts.optimistic,
        isSource: true,
        isDestination: false,
      );
    case 'transfer':
      applyAccountDelta(
        sourceId,
        sourceAccount,
        amounts.expected,
        amounts.pessimistic,
        amounts.optimistic,
        isSource: true,
        isDestination: false,
      );
      applyAccountDelta(
        destinationId,
        destinationAccount,
        amounts.expected,
        amounts.pessimistic,
        amounts.optimistic,
        isSource: false,
        isDestination: true,
      );
  }

  return result;
}

class _FlowAmounts {
  final double expected;
  final double pessimistic;
  final double optimistic;

  const _FlowAmounts({
    required this.expected,
    required this.pessimistic,
    required this.optimistic,
  });
}

_FlowAmounts _flowAmounts(ScheduledCashFlow flow, double margin) {
  final expected = flow.amount;
  if (flow.amountMin != null && flow.amountMax != null) {
    return _FlowAmounts(
      expected: expected,
      pessimistic: flow.amountMax!,
      optimistic: flow.amountMin!,
    );
  }

  return switch (flow.transactionType) {
    'deposit' => _FlowAmounts(
      expected: expected,
      pessimistic: expected * (1 - margin),
      optimistic: expected * (1 + margin),
    ),
    'withdrawal' => _FlowAmounts(
      expected: expected,
      pessimistic: expected * (1 + margin),
      optimistic: expected * (1 - margin),
    ),
    'transfer' => _FlowAmounts(
      expected: expected,
      pessimistic: expected * (1 + margin),
      optimistic: expected * (1 - margin),
    ),
    _ => _FlowAmounts(
      expected: expected,
      pessimistic: expected * (1 - margin),
      optimistic: expected * (1 + margin),
    ),
  };
}

double _signedDelta({
  required Account account,
  required String transactionType,
  required double amount,
  required bool isSource,
  required bool isDestination,
}) {
  return switch (transactionType) {
    'deposit' when isDestination => account.isLiability ? -amount : amount,
    'withdrawal' when isSource => account.isLiability ? amount : -amount,
    'transfer' when isSource => account.isLiability ? amount : -amount,
    'transfer' when isDestination => account.isLiability ? -amount : amount,
    _ => 0,
  };
}

List<PrognosisBalancePoint> _buildTimelineRaw({
  required double startBalance,
  required List<PrognosisEvent> events,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final points = <PrognosisBalancePoint>[];
  var expected = startBalance;
  var pessimistic = startBalance;
  var optimistic = startBalance;
  var eventIndex = 0;
  var day = prognosisStartOfDay(rangeStart);

  while (!day.isAfter(rangeEnd)) {
    while (eventIndex < events.length &&
        prognosisStartOfDay(events[eventIndex].date).isAtSameMomentAs(day)) {
      final event = events[eventIndex];
      expected += event.expectedDelta;
      pessimistic += event.pessimisticDelta;
      optimistic += event.optimisticDelta;
      eventIndex++;
    }

    points.add(
      PrognosisBalancePoint(
        date: day,
        expected: expected,
        pessimistic: pessimistic,
        optimistic: optimistic,
      ),
    );
    day = day.add(const Duration(days: 1));
  }

  return points;
}

List<PrognosisBalancePoint> _sampleTimeline(
  List<PrognosisBalancePoint> points,
) {
  if (points.length <= 48) return points;
  final sampled = <PrognosisBalancePoint>[];
  final step = (points.length / 48).ceil();
  for (var i = 0; i < points.length; i += step) {
    sampled.add(points[i]);
  }
  if (sampled.last != points.last) {
    sampled.add(points.last);
  }
  return sampled;
}

PrognosisBalanceSnapshot _snapshotOnDate(
  List<PrognosisBalancePoint> timeline,
  DateTime date,
  double fallback,
) {
  final target = prognosisStartOfDay(date);
  PrognosisBalancePoint? match;
  for (final point in timeline) {
    if (prognosisStartOfDay(point.date).isAfter(target)) break;
    match = point;
  }
  if (match == null) {
    return PrognosisBalanceSnapshot(
      expected: fallback,
      pessimistic: fallback,
      optimistic: fallback,
    );
  }
  return PrognosisBalanceSnapshot(
    expected: match.expected,
    pessimistic: match.pessimistic,
    optimistic: match.optimistic,
  );
}

Map<PrognosisMilestone, PrognosisBalanceSnapshot> _buildMilestones({
  required List<PrognosisBalancePoint> timeline,
  required DateTime reference,
  required double fallback,
}) {
  return {
    for (final milestone in prognosisDisplayMilestones)
      milestone: _snapshotOnDate(
        timeline,
        prognosisMilestoneDate(reference, milestone),
        fallback,
      ),
  };
}

DateTime? _firstNegativeDate({
  required List<PrognosisBalancePoint> timeline,
  required String accountType,
}) {
  if (accountType != 'asset') return null;
  for (final point in timeline) {
    if (point.expected <= 0) {
      return point.date;
    }
  }
  return null;
}

Map<String, double> _accountMonthlyNets(
  List<Account> accounts,
  List<Transaction> transactions,
) {
  final accountIds = accounts.map((account) => account.id).toSet();
  final nets = {for (final id in accountIds) id: 0.0};
  if (transactions.isEmpty) return nets;

  // Only the extremes matter; a min/max scan avoids sorting a full copy.
  var minDate = transactions.first.date;
  var maxDate = transactions.first.date;
  for (final transaction in transactions) {
    if (transaction.date.isBefore(minDate)) minDate = transaction.date;
    if (transaction.date.isAfter(maxDate)) maxDate = transaction.date;
  }
  final spanDays = prognosisStartOfDay(
    maxDate,
  ).difference(prognosisStartOfDay(minDate)).inDays.clamp(30, 365);
  final monthFactor = spanDays / 30.0;

  for (final transaction in transactions) {
    for (final split in transaction.resolvedSplits()) {
      if (split.type == 'deposit' &&
          split.destinationId != null &&
          accountIds.contains(split.destinationId)) {
        nets[split.destinationId!] = nets[split.destinationId!]! + split.amount;
      }
      if (split.type == 'withdrawal' &&
          split.sourceId != null &&
          accountIds.contains(split.sourceId)) {
        nets[split.sourceId!] = nets[split.sourceId!]! - split.amount;
      }
      if (split.type == 'transfer') {
        if (split.sourceId != null && accountIds.contains(split.sourceId)) {
          nets[split.sourceId!] = nets[split.sourceId!]! - split.amount;
        }
        if (split.destinationId != null &&
            accountIds.contains(split.destinationId)) {
          nets[split.destinationId!] =
              nets[split.destinationId!]! + split.amount;
        }
      }
    }
  }

  return {
    for (final entry in nets.entries) entry.key: entry.value / monthFactor,
  };
}

List<PrognosisBalancePoint> _buildProjectedTimelineRaw({
  required double startBalance,
  required double monthlyNet,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required double marginPercent,
  required bool isLiability,
}) {
  const annualReturn = 0.03;
  final monthlyRate = annualReturn / 12;
  final liabilityFactor = isLiability ? 0.96 : 1.0;
  final effectiveNet = monthlyNet * liabilityFactor;

  final points = <PrognosisBalancePoint>[];
  var expected = startBalance;
  var pessimistic = startBalance;
  var optimistic = startBalance;
  var day = prognosisStartOfDay(rangeStart);

  while (!day.isAfter(rangeEnd)) {
    final monthEnd = DateTime(day.year, day.month + 1, 0);
    if (prognosisStartOfDay(day) == prognosisStartOfDay(monthEnd)) {
      expected = expected * (1 + monthlyRate) + effectiveNet;
      pessimistic =
          pessimistic * (1 + monthlyRate * (1 - marginPercent)) +
          effectiveNet * (1 + marginPercent);
      optimistic =
          optimistic * (1 + monthlyRate * (1 + marginPercent)) +
          effectiveNet * (1 - marginPercent);
    }

    points.add(
      PrognosisBalancePoint(
        date: day,
        expected: expected,
        pessimistic: pessimistic,
        optimistic: optimistic,
      ),
    );

    day = day.add(const Duration(days: 1));
  }

  return points;
}

List<ScheduledCashFlow> _scheduledTransactionFlows({
  required List<Transaction> transactions,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required Map<String, Account> accountsById,
  required Map<String, Account> accountsByName,
}) {
  final flows = <ScheduledCashFlow>[];
  for (final transaction in transactions) {
    final day = prognosisStartOfDay(transaction.date);
    if (day.isBefore(rangeStart) || !day.isBefore(rangeEnd)) continue;
    if (!_transactionTouchesKnownAccount(
      transaction,
      accountsById,
      accountsByName,
    )) {
      continue;
    }
    flows.add(
      ScheduledCashFlow(
        date: day,
        description: transaction.description,
        transactionType: transaction.type,
        sourceId: transaction.sourceId,
        sourceName: transaction.sourceName,
        destinationId: transaction.destinationId,
        destinationName: transaction.destinationName,
        amount: transaction.amount,
        billId: transaction.billId,
        source: ScheduledFlowSource.transaction,
      ),
    );
  }
  return flows;
}

List<ScheduledCashFlow> _recurrenceFlows({
  required List<Recurrence> recurrences,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final flows = <ScheduledCashFlow>[];
  for (final recurrence in recurrences) {
    flows.addAll(
      expandRecurrenceCashFlows(
        recurrence: recurrence,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
  }
  return flows;
}

List<ScheduledCashFlow> _billFlows({
  required List<Bill> bills,
  required Map<String, BillAccountTemplate> billTemplates,
  required List<Transaction> transactions,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final flows = <ScheduledCashFlow>[];
  // One O(n) pass replaces a full-list scan per bill occurrence.
  final billTransactionDays = <String>{};
  for (final transaction in transactions) {
    final billId = transaction.billId;
    if (billId == null || billId.isEmpty) continue;
    final day = transaction.date;
    billTransactionDays.add('$billId|${day.year}-${day.month}-${day.day}');
  }
  for (final bill in bills) {
    final template = billTemplates[bill.id];
    if (template == null) continue;

    final billDates = expandBillOccurrences(
      bill: bill,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    for (final date in billDates) {
      if (billTransactionDays.contains(
        '${bill.id}|${date.year}-${date.month}-${date.day}',
      )) {
        continue;
      }
      flows.add(
        ScheduledCashFlow(
          date: date,
          description: bill.name,
          transactionType: template.transactionType,
          sourceId: template.sourceId,
          sourceName: template.sourceName,
          destinationId: template.destinationId,
          destinationName: template.destinationName,
          amount: bill.amountAvg,
          amountMin: bill.amountMin,
          amountMax: bill.amountMax,
          billId: bill.id,
          source: ScheduledFlowSource.bill,
        ),
      );
    }
  }
  return flows;
}

Map<String, BillAccountTemplate> _inferBillTemplates(
  List<Transaction> transactions,
  List<Account> accounts,
) {
  final accountIds = accounts.map((account) => account.id).toSet();
  final templates = <String, BillAccountTemplate>{};
  final grouped = <String, List<Transaction>>{};

  for (final transaction in transactions) {
    final billId = transaction.billId;
    if (billId == null || billId.isEmpty) continue;
    grouped.putIfAbsent(billId, () => []).add(transaction);
  }

  for (final entry in grouped.entries) {
    final counts = <String, int>{};
    BillAccountTemplate? best;
    var bestCount = 0;

    for (final transaction in entry.value) {
      final template = BillAccountTemplate(
        transactionType: transaction.type,
        sourceId: transaction.sourceId,
        sourceName: transaction.sourceName,
        destinationId: transaction.destinationId,
        destinationName: transaction.destinationName,
      );
      final key = _templateKey(template);
      final count = (counts[key] ?? 0) + 1;
      counts[key] = count;
      if (count > bestCount) {
        bestCount = count;
        best = template;
      }
    }

    if (best != null &&
        _templateUsesKnownAccounts(best, accountIds, accounts)) {
      templates[entry.key] = best;
    }
  }

  return templates;
}

bool _templateUsesKnownAccounts(
  BillAccountTemplate template,
  Set<String> accountIds,
  List<Account> accounts,
) {
  final names = accounts.map((account) => account.name).toSet();
  return switch (template.transactionType) {
    'withdrawal' =>
      (template.sourceId != null && accountIds.contains(template.sourceId)) ||
          names.contains(template.sourceName),
    'deposit' =>
      (template.destinationId != null &&
              accountIds.contains(template.destinationId)) ||
          names.contains(template.destinationName),
    'transfer' =>
      ((template.sourceId != null && accountIds.contains(template.sourceId)) ||
              names.contains(template.sourceName)) &&
          ((template.destinationId != null &&
                  accountIds.contains(template.destinationId)) ||
              names.contains(template.destinationName)),
    _ => false,
  };
}

String _templateKey(BillAccountTemplate template) {
  return '${template.transactionType}|${template.sourceId}|${template.sourceName}|'
      '${template.destinationId}|${template.destinationName}';
}

List<ScheduledCashFlow> _dedupeFlows(List<ScheduledCashFlow> flows) {
  final sorted = [...flows]
    ..sort((a, b) {
      final priority = _flowPriority(a).compareTo(_flowPriority(b));
      if (priority != 0) return priority;
      return a.date.compareTo(b.date);
    });

  final seen = <String>{};
  final result = <ScheduledCashFlow>[];
  for (final flow in sorted) {
    if (seen.add(_flowKey(flow))) {
      result.add(flow);
    }
  }
  return result;
}

int _flowPriority(ScheduledCashFlow flow) {
  if (flow.source == ScheduledFlowSource.transaction) return 0;
  if (flow.source == ScheduledFlowSource.recurrence) return 1;
  return 2;
}

String _flowKey(ScheduledCashFlow flow) {
  final date = prognosisStartOfDay(flow.date).toIso8601String();
  final amount = flow.amount.toStringAsFixed(2);
  return switch (flow.transactionType) {
    'withdrawal' =>
      '$date|withdrawal|${flow.sourceId}|${flow.sourceName}|$amount',
    'deposit' =>
      '$date|deposit|${flow.destinationId}|${flow.destinationName}|$amount',
    'transfer' =>
      '$date|transfer|${flow.sourceId}|${flow.sourceName}|'
          '${flow.destinationId}|${flow.destinationName}|$amount',
    _ =>
      '$date|${flow.transactionType}|${flow.sourceId}|${flow.sourceName}|'
          '${flow.destinationId}|${flow.destinationName}|$amount',
  };
}

bool _transactionTouchesKnownAccount(
  Transaction transaction,
  Map<String, Account> accountsById,
  Map<String, Account> accountsByName,
) {
  final sourceKnown =
      (transaction.sourceId != null &&
          accountsById.containsKey(transaction.sourceId)) ||
      accountsByName.containsKey(transaction.sourceName);
  final destinationKnown =
      (transaction.destinationId != null &&
          accountsById.containsKey(transaction.destinationId)) ||
      accountsByName.containsKey(transaction.destinationName);
  return sourceKnown || destinationKnown;
}

bool _isCreditCardPayment(
  ScheduledCashFlow flow,
  Map<String, Account> accountsById,
  Map<String, Account> accountsByName,
) {
  if (flow.transactionType != 'transfer') return false;

  Account? destination;
  if (flow.destinationId != null) {
    destination = accountsById[flow.destinationId];
  }
  destination ??= accountsByName[flow.destinationName];
  if (destination == null) return false;

  return destination.type == 'liability' || destination.role == 'ccAsset';
}

bool _isCreditCardRelated(
  ScheduledCashFlow flow,
  Map<String, Account> accountsById,
  Map<String, Account> accountsByName,
) {
  if (_isCreditCardPayment(flow, accountsById, accountsByName)) return true;

  Account? source;
  if (flow.sourceId != null) {
    source = accountsById[flow.sourceId];
  }
  source ??= accountsByName[flow.sourceName];
  if (source != null &&
      (source.type == 'liability' || source.role == 'ccAsset')) {
    return true;
  }

  Account? destination;
  if (flow.destinationId != null) {
    destination = accountsById[flow.destinationId];
  }
  destination ??= accountsByName[flow.destinationName];
  if (destination != null &&
      (destination.type == 'liability' || destination.role == 'ccAsset')) {
    return true;
  }

  return false;
}

PrognosisEventSource _flowSource(ScheduledCashFlow flow) {
  return switch (flow.source) {
    ScheduledFlowSource.recurrence => PrognosisEventSource.recurrence,
    ScheduledFlowSource.bill => PrognosisEventSource.bill,
    ScheduledFlowSource.transaction =>
      PrognosisEventSource.scheduledTransaction,
  };
}

List<double> forwardAccountBalanceSparkline(AccountPrognosis prognosis) {
  return prognosis.forwardSparkline;
}
