import '../utils/balance_check.dart';
import '../models/transaction.dart';
import '../utils/bank_amount.dart';
import '../utils/name_matching.dart';
import '../utils/reconciliation.dart';

/// Calendar days a recorded transaction may sit from a statement row and still
/// be claimed as the same event.
const int kStatementDateToleranceDays = 3;

/// Wider window for the near pass, which reports a candidate for a human to
/// judge rather than claiming the row is already in the ledger.
const int kStatementNearDateToleranceDays = 5;

/// Fraction of the statement amount a near candidate may differ by.
const double kStatementNearAmountTolerancePct = 0.10;

/// Two amounts closer than this are the same amount, matching what
/// `compareBalances` calls equal.

const String _dateField = 'date';
const String _bookDateField = 'book_date';
const String _splitGroupBlock = 'split_group';
const String _bookDateReason = 'matched on the book date, not the value date';
const String _payeeTextReason =
    'payee text differs from the recorded description';

const String _unparsedRowsPresent = 'unparsed_rows_present';
const String _statementSelfCheckFailed = 'statement_self_check_failed';
const String _planDoesNotCloseGap = 'plan_does_not_close_gap';
const String _balancesNotSupplied = 'balances_not_supplied';

const String _amountFormatField = 'amount_format';
const String _openingBalanceField = 'opening_balance';
const String _closingBalanceField = 'closing_balance';

/// One export line as the bank printed it, before a decimal grammar is chosen.
class RawStatementRow {
  const RawStatementRow({
    required this.rowId,
    required this.date,
    required this.rawAmount,
    this.bookDate,
    this.text,
  });

  final String rowId;
  final DateTime date;
  final DateTime? bookDate;
  final String rawAmount;
  final String? text;
}

/// One export line, read under the grammar the whole export settled on.
class StatementRow {
  const StatementRow({
    required this.rowId,
    required this.date,
    required this.amount,
    this.bookDate,
    this.text,
  });

  final String rowId;
  final DateTime date;
  final DateTime? bookDate;

  /// Signed: negative leaves the account.
  final double amount;
  final String? text;
}

/// A row the settled grammar could not read.
class StatementNeedsInput {
  const StatementNeedsInput({
    required this.rowId,
    required this.rawAmount,
    required this.reason,
    required this.candidates,
  });

  final String rowId;
  final String rawAmount;

  /// The parser's own reason: `double_sign` or `unreadable`.
  final String reason;

  /// What the row would be worth under each grammar, dot decimals first, so the
  /// human answering sees the readings rather than being asked to re-type the
  /// number.
  final List<double> candidates;
}

/// One consumable ledger unit: a single split leg, not a journal.
///
/// A statement line pays one leg, so a split group offers as many units as it
/// has legs touching the account and each is spent at most once.
class LedgerLeg {
  const LedgerLeg({
    required this.group,
    required this.split,
    required this.index,
    required this.journalId,
    required this.signedAmount,
  });

  final Transaction group;
  final Transaction split;
  final int index;
  final String? journalId;

  /// Effect on the statement's account, signed as the bank signs it.
  final double signedAmount;

  String get transactionId => group.id;
  DateTime get date => split.date;
  bool get isSplitGroup => group.isSplitGroup;
}

/// A row paired with the leg it was assigned to.
class StatementMatch {
  const StatementMatch({
    required this.row,
    required this.leg,
    required this.dateDeltaDays,
    required this.dateFieldUsed,
    required this.amountDeltaPct,
    required this.reasons,
    this.legsConsumed = 1,
    this.groupAmount,
    this.blockedReason,
  });

  final StatementRow row;
  final LedgerLeg leg;
  final int dateDeltaDays;

  /// `date` or `book_date`, whichever landed closer.
  final String dateFieldUsed;

  /// Signed against the statement amount, so a recorded estimate that came in
  /// higher reads positive.
  final double amountDeltaPct;

  /// Legs this row paid. More than one when a single bank line settled a whole
  /// split journal, which is how a mortgage arrives: one debit covering
  /// amortisation and the interest on each loan.
  final int legsConsumed;

  /// The summed legs when this row paid a whole journal, null for a single leg.
  final double? groupAmount;

  final List<String> reasons;

  /// `split_group` when correcting this leg would move a journal whose other
  /// legs the statement says nothing about.
  final String? blockedReason;

  double get statementAmount => row.amount;
  double get recordedAmount => groupAmount ?? leg.signedAmount;
  double get amountDelta => recordedAmount - row.amount;
}

/// Whether the statement's own numbers add up, before the ledger is consulted.
class StatementSelfCheck {
  const StatementSelfCheck({
    required this.opening,
    required this.rowsSum,
    required this.impliedClosing,
    required this.statedClosing,
    required this.agrees,
  });

  final double opening;
  final double rowsSum;
  final double impliedClosing;
  final double statedClosing;
  final bool agrees;
}

class StatementArithmetic {
  const StatementArithmetic({
    required this.statementRowsSum,
    required this.recordedSum,
    required this.missingRowsSum,
    required this.gapClosedByPlan,
    required this.agrees,
    this.openingBalance,
    this.closingBalance,
    this.balanceGap,
    this.disagreementReason,
  });

  final double statementRowsSum;
  final double recordedSum;
  final double missingRowsSum;

  /// Whether writing the missing rows would make the ledger move by exactly the
  /// balance gap.
  final bool gapClosedByPlan;

  /// Null when no balances were supplied and there is nothing to agree with.
  final bool? agrees;

  final double? openingBalance;
  final double? closingBalance;
  final double? balanceGap;
  final String? disagreementReason;

  double get rowsMinusRecorded => statementRowsSum - recordedSum;
}

class StatementPlan {
  const StatementPlan({
    required this.matched,
    required this.near,
    required this.missing,
    required this.unmatchedRecorded,
    required this.needsInput,
    required this.excludedForeignCurrencySplits,
    required this.excludedOutsidePeriod,
    required this.arithmetic,
    this.selfCheck,
  });

  final List<StatementMatch> matched;
  final List<StatementMatch> near;
  final List<StatementRow> missing;
  final List<LedgerLeg> unmatchedRecorded;
  final List<StatementNeedsInput> needsInput;
  final int excludedForeignCurrencySplits;

  /// Legs pulled in by the fetch padding either side of the period. They stay
  /// matchable, because a row on the first of the month is routinely booked on
  /// the last of the previous one, but they are not part of the period's
  /// accounting.
  final int excludedOutsidePeriod;

  final StatementArithmetic arithmetic;
  final StatementSelfCheck? selfCheck;
}

sealed class StatementParseResult {
  const StatementParseResult();
}

class StatementParsed extends StatementParseResult {
  const StatementParsed({
    required this.grammar,
    required this.rows,
    required this.needsInput,
    this.openingBalance,
    this.closingBalance,
  });

  final AmountGrammar grammar;
  final List<StatementRow> rows;
  final List<StatementNeedsInput> needsInput;
  final double? openingBalance;
  final double? closingBalance;
}

class StatementParseFailure extends StatementParseResult {
  const StatementParseFailure({required this.field, required this.message});

  /// `amount_format`, `opening_balance` or `closing_balance`.
  final String field;
  final String message;
}

/// Reads a whole export under one grammar.
///
/// The grammar is settled once, over the rows and both balances together, and
/// then applied to every amount: a row reading `1,234` is undecidable alone and
/// decided by the corpus. When the corpus decides nothing the call fails asking
/// for [amountFormat] rather than picking a separator, and a balance that will
/// not read under the settled grammar fails naming its own field rather than
/// falling back to the other grammar for that one number.
StatementParseResult parseStatementRows({
  required List<RawStatementRow> rows,
  String? openingBalance,
  String? closingBalance,
  AmountGrammar? amountFormat,
}) {
  final grammar =
      amountFormat ??
      inferAmountGrammar([
        for (final row in rows) row.rawAmount,
        ?openingBalance,
        ?closingBalance,
      ]);
  if (grammar == null) {
    return const StatementParseFailure(
      field: _amountFormatField,
      message:
          'no amount in the export settles the decimal separator; '
          'pass amount_format',
    );
  }

  final opening = _readAmount(openingBalance, grammar);
  if (openingBalance != null && opening == null) {
    return const StatementParseFailure(
      field: _openingBalanceField,
      message: 'opening_balance does not read under the settled amount format',
    );
  }
  final closing = _readAmount(closingBalance, grammar);
  if (closingBalance != null && closing == null) {
    return const StatementParseFailure(
      field: _closingBalanceField,
      message: 'closing_balance does not read under the settled amount format',
    );
  }

  final parsedRows = <StatementRow>[];
  final needsInput = <StatementNeedsInput>[];
  for (final row in rows) {
    final parsed = parseBankAmount(row.rawAmount, grammar: grammar);
    if (parsed is BankAmountValue) {
      parsedRows.add(
        StatementRow(
          rowId: row.rowId,
          date: row.date,
          bookDate: row.bookDate,
          amount: parsed.value,
          text: row.text,
        ),
      );
      continue;
    }
    needsInput.add(
      StatementNeedsInput(
        rowId: row.rowId,
        rawAmount: row.rawAmount,
        reason: _needsInputReason(parsed as BankAmountUnreadable),
        candidates: _candidateReadings(row.rawAmount),
      ),
    );
  }

  return StatementParsed(
    grammar: grammar,
    rows: parsedRows,
    needsInput: needsInput,
    openingBalance: opening,
    closingBalance: closing,
  );
}

/// Assigns [rows] to the legs of [recorded] one to one.
///
/// Exact pairs are consumed first, then near pairs over what is left on both
/// sides, so two rows of the same amount on the same day take two different
/// legs and the second cannot be absorbed by the first's transaction. A row
/// that takes no leg is missing, and writing it is the caller's decision.
///
/// [needsInput] carries the rows the parser could not read: they are in no sum
/// and no pass, and their presence alone is enough to refuse to say the
/// arithmetic agrees.
StatementPlan matchStatementRows({
  required String accountId,
  required List<StatementRow> rows,
  required List<Transaction> recorded,
  required DateTime periodStart,
  required DateTime periodEnd,
  required String currencyCode,
  double? openingBalance,
  double? closingBalance,
  List<StatementNeedsInput> needsInput = const [],
}) {
  var foreignCurrencySplits = 0;
  final legs = <LedgerLeg>[];
  for (final group in recorded) {
    final splits = group.resolvedSplits();
    for (var index = 0; index < splits.length; index++) {
      final split = splits[index];
      var signed = signedAmountForSplitById(split, accountId);
      if (signed == 0) continue;
      if (split.currencyCode != currencyCode) {
        // A conversion between two pockets of the same wallet is booked in the
        // source currency, with the amount that landed on the other side in
        // foreign_amount. Skipping it left the statement's own row with no leg
        // to pair against, so a Revolut export reported every exchange as
        // missing and writing them would have double-counted what is already
        // there.
        final foreign = split.foreignAmount;
        if (foreign == null || split.foreignCurrencyCode != currencyCode) {
          foreignCurrencySplits++;
          continue;
        }
        signed = signed.isNegative ? -foreign.abs() : foreign.abs();
      }
      legs.add(
        LedgerLeg(
          group: group,
          split: split,
          index: index,
          journalId: split.journalId,
          signedAmount: signed,
        ),
      );
    }
  }

  final takenRows = <int>{};
  final takenLegs = <int>{};
  final matched = <StatementMatch>[
    ..._consume(
      candidates: _exactCandidates(rows, legs),
      rows: rows,
      legs: legs,
      takenRows: takenRows,
      takenLegs: takenLegs,
      blockSplitGroups: false,
    ),
  ];
  matched.addAll(
    _consumeGroups(
      rows: rows,
      legs: legs,
      takenRows: takenRows,
      takenLegs: takenLegs,
    ),
  );

  final near = _consume(
    candidates: _nearCandidates(rows, legs, takenRows, takenLegs),
    rows: rows,
    legs: legs,
    takenRows: takenRows,
    takenLegs: takenLegs,
    blockSplitGroups: true,
  );

  final missing = [
    for (var index = 0; index < rows.length; index++)
      if (!takenRows.contains(index)) rows[index],
  ];

  // The period's ledger total and the legs reported as unmatched come out of
  // one walk over one set: computed apart, they could disagree and still be
  // presented as if each proved the other.
  var recordedSum = 0.0;
  var outsidePeriod = 0;
  final unmatchedRecorded = <LedgerLeg>[];
  for (var index = 0; index < legs.length; index++) {
    final leg = legs[index];
    if (!isDateInInclusiveRange(leg.date, periodStart, periodEnd)) {
      outsidePeriod++;
      continue;
    }
    recordedSum += leg.signedAmount;
    if (!takenLegs.contains(index)) unmatchedRecorded.add(leg);
  }

  final statementRowsSum = rows.fold<double>(0, (sum, row) => sum + row.amount);
  final missingRowsSum = missing.fold<double>(
    0,
    (sum, row) => sum + row.amount,
  );
  final hasBalances = openingBalance != null && closingBalance != null;
  final balanceGap = hasBalances ? closingBalance - openingBalance : null;
  final selfCheck = hasBalances
      ? StatementSelfCheck(
          opening: openingBalance,
          rowsSum: statementRowsSum,
          impliedClosing: openingBalance + statementRowsSum,
          statedClosing: closingBalance,
          agrees: _equal(openingBalance + statementRowsSum, closingBalance),
        )
      : null;
  final gapClosedByPlan =
      balanceGap != null && _equal(recordedSum + missingRowsSum, balanceGap);

  bool? agrees;
  String? disagreementReason;
  if (needsInput.isNotEmpty) {
    agrees = false;
    disagreementReason = _unparsedRowsPresent;
  } else if (selfCheck == null) {
    disagreementReason = _balancesNotSupplied;
  } else if (!selfCheck.agrees) {
    agrees = false;
    disagreementReason = _statementSelfCheckFailed;
  } else {
    agrees = gapClosedByPlan;
    // Without this the commonest disagreement, a plan that leaves the balance
    // gap open, came back as agrees:false with no reason at all.
    if (!gapClosedByPlan) disagreementReason = _planDoesNotCloseGap;
  }

  return StatementPlan(
    matched: matched,
    near: near,
    missing: missing,
    unmatchedRecorded: unmatchedRecorded,
    needsInput: needsInput,
    excludedForeignCurrencySplits: foreignCurrencySplits,
    excludedOutsidePeriod: outsidePeriod,
    selfCheck: selfCheck,
    arithmetic: StatementArithmetic(
      statementRowsSum: statementRowsSum,
      recordedSum: recordedSum,
      missingRowsSum: missingRowsSum,
      gapClosedByPlan: gapClosedByPlan,
      agrees: agrees,
      openingBalance: openingBalance,
      closingBalance: closingBalance,
      balanceGap: balanceGap,
      disagreementReason: disagreementReason,
    ),
  );
}

class _DateFit {
  const _DateFit(this.days, this.field);

  final int days;
  final String field;
}

class _Candidate {
  const _Candidate({
    required this.rowIndex,
    required this.legIndex,
    required this.fit,
    required this.alike,
    required this.amountDeltaPct,
  });

  final int rowIndex;
  final int legIndex;
  final _DateFit fit;

  /// Null when either side carries no text to compare.
  final bool? alike;

  final double amountDeltaPct;
}

List<_Candidate> _exactCandidates(
  List<StatementRow> rows,
  List<LedgerLeg> legs,
) {
  final candidates = <_Candidate>[];
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    for (var legIndex = 0; legIndex < legs.length; legIndex++) {
      final leg = legs[legIndex];
      if (!_equal(leg.signedAmount, row.amount)) continue;
      final fit = _dateFit(row, leg.date);
      if (fit.days > kStatementDateToleranceDays) continue;
      candidates.add(
        _Candidate(
          rowIndex: rowIndex,
          legIndex: legIndex,
          fit: fit,
          alike: _textAlike(row.text, leg.split.description),
          amountDeltaPct: _deltaPct(row.amount, leg.signedAmount),
        ),
      );
    }
  }
  candidates.sort(_byExactConfidence);
  return candidates;
}

List<_Candidate> _nearCandidates(
  List<StatementRow> rows,
  List<LedgerLeg> legs,
  Set<int> takenRows,
  Set<int> takenLegs,
) {
  final candidates = <_Candidate>[];
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    if (takenRows.contains(rowIndex)) continue;
    final row = rows[rowIndex];
    for (var legIndex = 0; legIndex < legs.length; legIndex++) {
      if (takenLegs.contains(legIndex)) continue;
      final leg = legs[legIndex];
      // Same payee side: a refund is never a near miss of a payment.
      if (row.amount * leg.signedAmount <= 0) continue;
      final fit = _dateFit(row, leg.date);
      if (fit.days > kStatementNearDateToleranceDays) continue;
      final pct = _deltaPct(row.amount, leg.signedAmount);
      if (pct.abs() > kStatementNearAmountTolerancePct) continue;
      candidates.add(
        _Candidate(
          rowIndex: rowIndex,
          legIndex: legIndex,
          fit: fit,
          alike: _textAlike(row.text, leg.split.description),
          amountDeltaPct: pct,
        ),
      );
    }
  }
  candidates.sort(_byNearConfidence);
  return candidates;
}

/// Pairs a row with a whole split journal when one bank line paid all its legs.
///
/// A card statement lists each split separately, so a leg is the right unit
/// there. A mortgage arrives the other way round: the bank debits one amount
/// and the ledger records amortisation and the interest on each loan as legs of
/// one journal. Matching legs only, that row looks missing and its legs look
/// like strangers, which is the shape that makes an importer create a second
/// mortgage payment every month.
List<StatementMatch> _consumeGroups({
  required List<StatementRow> rows,
  required List<LedgerLeg> legs,
  required Set<int> takenRows,
  required Set<int> takenLegs,
}) {
  final byGroup = <String, List<int>>{};
  for (var index = 0; index < legs.length; index++) {
    if (takenLegs.contains(index)) continue;
    byGroup.putIfAbsent(legs[index].transactionId, () => <int>[]).add(index);
  }
  // Sorted so the same statement always produces the same assignment.
  final groupIds = byGroup.keys.toList()..sort();

  final matches = <StatementMatch>[];
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    if (takenRows.contains(rowIndex)) continue;
    final row = rows[rowIndex];
    for (final id in groupIds) {
      final indexes = byGroup[id]!;
      if (indexes.length < 2) continue;
      if (indexes.any(takenLegs.contains)) continue;
      final total = indexes.fold<double>(
        0,
        (sum, index) => sum + legs[index].signedAmount,
      );
      if (!_equal(total, row.amount)) continue;
      final fit = _dateFit(row, legs[indexes.first].date);
      if (fit.days > kStatementDateToleranceDays) continue;

      takenRows.add(rowIndex);
      takenLegs.addAll(indexes);
      matches.add(
        StatementMatch(
          row: row,
          leg: legs[indexes.first],
          dateDeltaDays: fit.days,
          dateFieldUsed: fit.field,
          amountDeltaPct: 0,
          legsConsumed: indexes.length,
          groupAmount: total,
          reasons: [
            'one line paid the whole journal: ${indexes.length} legs summing '
                'to ${total.toStringAsFixed(2)}',
          ],
        ),
      );
      break;
    }
  }
  return matches;
}

List<StatementMatch> _consume({
  required List<_Candidate> candidates,
  required List<StatementRow> rows,
  required List<LedgerLeg> legs,
  required Set<int> takenRows,
  required Set<int> takenLegs,
  required bool blockSplitGroups,
}) {
  final matches = <StatementMatch>[];
  for (final candidate in candidates) {
    if (takenRows.contains(candidate.rowIndex)) continue;
    if (takenLegs.contains(candidate.legIndex)) continue;
    takenRows.add(candidate.rowIndex);
    takenLegs.add(candidate.legIndex);
    final leg = legs[candidate.legIndex];
    matches.add(
      StatementMatch(
        row: rows[candidate.rowIndex],
        leg: leg,
        dateDeltaDays: candidate.fit.days,
        dateFieldUsed: candidate.fit.field,
        amountDeltaPct: candidate.amountDeltaPct,
        reasons: [
          if (candidate.fit.field == _bookDateField) _bookDateReason,
          if (candidate.alike == false) _payeeTextReason,
        ],
        blockedReason: blockSplitGroups && leg.isSplitGroup
            ? _splitGroupBlock
            : null,
      ),
    );
  }
  return matches;
}

int _byExactConfidence(_Candidate a, _Candidate b) {
  final byDate = a.fit.days.compareTo(b.fit.days);
  if (byDate != 0) return byDate;
  final byText = _textRank(a.alike).compareTo(_textRank(b.alike));
  if (byText != 0) return byText;
  return _byPosition(a, b);
}

int _byNearConfidence(_Candidate a, _Candidate b) {
  final byAmount = a.amountDeltaPct.abs().compareTo(b.amountDeltaPct.abs());
  if (byAmount != 0) return byAmount;
  final byDate = a.fit.days.compareTo(b.fit.days);
  if (byDate != 0) return byDate;
  return _byPosition(a, b);
}

int _byPosition(_Candidate a, _Candidate b) {
  final byRow = a.rowIndex.compareTo(b.rowIndex);
  return byRow != 0 ? byRow : a.legIndex.compareTo(b.legIndex);
}

int _textRank(bool? alike) => alike == true ? 0 : (alike == null ? 1 : 2);

/// Whether the bank's payee text and the recorded description name the same
/// party. Only ever a tie-break: the bank routinely prints the acquirer where
/// the ledger names the shop.
bool? _textAlike(String? rowText, String description) {
  final row = foldAccountName(rowText ?? '');
  final recorded = foldAccountName(description);
  if (row.isEmpty || recorded.isEmpty) return null;
  return row == recorded || prefixMatches(row, recorded);
}

/// The closer of the value date and the book date, and which one it was.
_DateFit _dateFit(StatementRow row, DateTime recorded) {
  final onDate = _dayDelta(row.date, recorded);
  final bookDate = row.bookDate;
  if (bookDate == null) return _DateFit(onDate, _dateField);
  final onBookDate = _dayDelta(bookDate, recorded);
  return onBookDate < onDate
      ? _DateFit(onBookDate, _bookDateField)
      : _DateFit(onDate, _dateField);
}

/// Calendar days apart, floored in UTC so an hour lost to a daylight-saving
/// change cannot make consecutive days read as the same day.
int _dayDelta(DateTime a, DateTime b) =>
    _dayFloor(a).difference(_dayFloor(b)).inDays.abs();

DateTime _dayFloor(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

double _deltaPct(double statement, double recorded) =>
    statement == 0 ? 0 : (recorded - statement) / statement.abs();

bool _equal(double a, double b) => (a - b).abs() <= kAmountEqualityTolerance;

double? _readAmount(String? raw, AmountGrammar grammar) {
  if (raw == null) return null;
  final parsed = parseBankAmount(raw, grammar: grammar);
  return parsed is BankAmountValue ? parsed.value : null;
}

/// A settled grammar decides grouping, so an unreadable row is the only thing
/// left that needs a person.
String _needsInputReason(BankAmountUnreadable parsed) => parsed.reason;

List<double> _candidateReadings(String raw) => [
  for (final grammar in AmountGrammar.values)
    if (parseBankAmount(raw, grammar: grammar) case BankAmountValue(
      :final value,
    ))
      value,
];
