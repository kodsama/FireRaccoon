import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

const String _accountId = '1';
const String _currency = 'SEK';

final DateTime _periodStart = DateTime(2026, 8, 1);
final DateTime _periodEnd = DateTime(2026, 8, 31);

Transaction _leg({
  required String id,
  required DateTime date,
  required double amount,
  String description = 'Coop Malmo',
  String? journalId,
  String currencyCode = _currency,
  String sourceId = _accountId,
  String destinationId = '9',
  double? foreignAmount,
  String? foreignCurrencyCode,
}) {
  return Transaction(
    id: id,
    journalId: journalId,
    type: 'withdrawal',
    date: date,
    amount: amount,
    description: description,
    sourceName: 'Checking',
    destinationName: 'Shop',
    categoryName: '',
    currencySymbol: 'kr',
    currencyCode: currencyCode,
    sourceId: sourceId,
    destinationId: destinationId,
    foreignAmount: foreignAmount,
    foreignCurrencyCode: foreignCurrencyCode,
  );
}

Transaction _splitGroup({
  required String id,
  required List<Transaction> splits,
}) {
  return splits.first.copyWith(id: id, splits: splits, groupTitle: 'Weekly');
}

StatementRow _row({
  required String rowId,
  required DateTime date,
  required double amount,
  DateTime? bookDate,
  String? text,
}) {
  return StatementRow(
    rowId: rowId,
    date: date,
    amount: amount,
    bookDate: bookDate,
    text: text,
  );
}

StatementPlan _match({
  required List<StatementRow> rows,
  required List<Transaction> recorded,
  double? openingBalance,
  double? closingBalance,
  List<StatementNeedsInput> needsInput = const [],
  DateTime? periodStart,
  DateTime? periodEnd,
}) {
  return matchStatementRows(
    accountId: _accountId,
    rows: rows,
    recorded: recorded,
    periodStart: periodStart ?? _periodStart,
    periodEnd: periodEnd ?? _periodEnd,
    currencyCode: _currency,
    openingBalance: openingBalance,
    closingBalance: closingBalance,
    needsInput: needsInput,
  );
}

void main() {
  group('matchStatementRows', () {
    test('two identical rows on one day take two different transactions', () {
      // One transaction absorbing both rows would hide a real gap.
      final plan = _match(
        rows: [
          _row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481),
          _row(rowId: 'r2', date: DateTime(2026, 8, 3), amount: -481),
        ],
        recorded: [
          _leg(id: 'a', date: DateTime(2026, 8, 3), amount: 481),
          _leg(id: 'b', date: DateTime(2026, 8, 3), amount: 481),
        ],
      );

      expect(plan.matched, hasLength(2));
      expect(plan.matched.map((match) => match.leg.transactionId).toSet(), {
        'a',
        'b',
      });
      expect(plan.matched.map((match) => match.row.rowId).toSet(), {
        'r1',
        'r2',
      });
      expect(plan.missing, isEmpty);
      expect(plan.unmatchedRecorded, isEmpty);
    });

    test('a second identical row with only one transaction is missing', () {
      // The one-to-one rule has to leave the gap visible, not double-book.
      final plan = _match(
        rows: [
          _row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481),
          _row(rowId: 'r2', date: DateTime(2026, 8, 3), amount: -481),
        ],
        recorded: [_leg(id: 'a', date: DateTime(2026, 8, 3), amount: 481)],
      );

      expect(plan.matched, hasLength(1));
      expect(plan.near, isEmpty);
      expect(plan.missing.single.rowId, 'r2');
      expect(plan.arithmetic.missingRowsSum, -481);
    });

    test('the closest recorded date wins when two legs carry the amount', () {
      // Ordering by list position instead of date delta picks the wrong leg
      // and leaves the right one reported as unmatched.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: [
          _leg(id: 'far', date: DateTime(2026, 8, 5), amount: 481),
          _leg(id: 'near', date: DateTime(2026, 8, 3), amount: 481),
        ],
      );

      expect(plan.matched.single.leg.transactionId, 'near');
      expect(plan.matched.single.dateDeltaDays, 0);
      expect(plan.unmatchedRecorded.single.transactionId, 'far');
    });

    test('payee text only breaks a tie between equal candidates', () {
      // Without the tie-break the first leg in fetch order wins and the row is
      // attached to the wrong transaction.
      final plan = _match(
        rows: [
          _row(
            rowId: 'r1',
            date: DateTime(2026, 8, 3),
            amount: -481,
            text: 'ICA KVANTUM',
          ),
        ],
        recorded: [
          _leg(id: 'coop', date: DateTime(2026, 8, 3), amount: 481),
          _leg(
            id: 'ica',
            date: DateTime(2026, 8, 3),
            amount: 481,
            description: 'ICA Kvantum',
          ),
        ],
      );

      expect(plan.matched.single.leg.transactionId, 'ica');
      expect(plan.matched.single.reasons, isEmpty);
    });

    test('a differing payee text is reported and never blocks the match', () {
      // Name similarity must not demote a row that agrees on amount and date.
      final plan = _match(
        rows: [
          _row(
            rowId: 'r1',
            date: DateTime(2026, 8, 3),
            amount: -481,
            text: 'NETS DENMARK',
          ),
        ],
        recorded: [_leg(id: 'a', date: DateTime(2026, 8, 5), amount: 481)],
      );

      final match = plan.matched.single;
      expect(match.dateDeltaDays, 2);
      expect(match.reasons, [
        'payee text differs from the recorded description',
      ]);
      expect(plan.missing, isEmpty);
    });

    test('a row matches one leg of a split journal, not the group', () {
      // Matching the group total would consume the whole journal for one row.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: [
          _splitGroup(
            id: 'g1',
            splits: [
              _leg(
                id: 'g1',
                date: DateTime(2026, 8, 3),
                amount: 300,
                journalId: 'j0',
              ),
              _leg(
                id: 'g1',
                date: DateTime(2026, 8, 3),
                amount: 481,
                journalId: 'j1',
              ),
            ],
          ),
        ],
      );

      final match = plan.matched.single;
      expect(match.leg.index, 1);
      expect(match.leg.journalId, 'j1');
      expect(match.leg.transactionId, 'g1');
      expect(match.blockedReason, isNull);
      expect(plan.unmatchedRecorded.single.journalId, 'j0');
    });

    test('a near match on a split leg is blocked as split_group', () {
      // Correcting the amount would move the journal's other legs with it.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 4), amount: -500)],
        recorded: [
          _splitGroup(
            id: 'g1',
            splits: [
              _leg(
                id: 'g1',
                date: DateTime(2026, 8, 3),
                amount: 300,
                journalId: 'j0',
              ),
              _leg(
                id: 'g1',
                date: DateTime(2026, 8, 3),
                amount: 481,
                journalId: 'j1',
              ),
            ],
          ),
        ],
      );

      expect(plan.matched, isEmpty);
      expect(plan.near.single.leg.journalId, 'j1');
      expect(plan.near.single.blockedReason, 'split_group');
    });

    test('a recorded estimate slightly off in amount and date is near', () {
      // Reported as a candidate with both amounts, not silently matched and
      // not silently missing.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: [_leg(id: 'a', date: DateTime(2026, 8, 6), amount: 500)],
      );

      expect(plan.matched, isEmpty);
      final near = plan.near.single;
      expect(near.statementAmount, -481);
      expect(near.recordedAmount, -500);
      expect(near.amountDelta, closeTo(-19, 0.0001));
      expect(near.amountDeltaPct, closeTo(-19 / 481, 0.0001));
      expect(near.dateDeltaDays, 3);
      expect(near.blockedReason, isNull);
      expect(plan.missing, isEmpty);
    });

    test('the near pass takes the closest amount, then the closest date', () {
      final byAmount = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: [
          _leg(id: 'far', date: DateTime(2026, 8, 4), amount: 500),
          _leg(id: 'near', date: DateTime(2026, 8, 4), amount: 490),
        ],
      );
      expect(byAmount.near.single.leg.transactionId, 'near');

      final byDate = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: [
          _leg(id: 'far', date: DateTime(2026, 8, 8), amount: 500),
          _leg(id: 'near', date: DateTime(2026, 8, 4), amount: 500),
        ],
      );
      expect(byDate.near.single.leg.transactionId, 'near');

      final byPosition = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: [
          _leg(id: 'first', date: DateTime(2026, 8, 4), amount: 500),
          _leg(id: 'second', date: DateTime(2026, 8, 4), amount: 500),
        ],
      );
      expect(byPosition.near.single.leg.transactionId, 'first');
    });

    test('an exact amount past 3 days is a candidate, not a match', () {
      // Widening the exact window to the near one would claim a row is already
      // recorded when only a human can say so.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: [_leg(id: 'a', date: DateTime(2026, 8, 8), amount: 481)],
      );

      expect(plan.matched, isEmpty);
      expect(plan.near.single.dateDeltaDays, 5);
      expect(plan.near.single.amountDeltaPct, 0);
    });

    test('the near pass never crosses the payee side', () {
      // A refund of the same size is not a near miss of a payment.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: 481)],
        recorded: [_leg(id: 'a', date: DateTime(2026, 8, 3), amount: 481)],
      );

      expect(plan.matched, isEmpty);
      expect(plan.near, isEmpty);
      expect(plan.missing.single.rowId, 'r1');
    });

    test('the near pass stops at 5 days and at 10 percent', () {
      final tooLate = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: [_leg(id: 'a', date: DateTime(2026, 8, 12), amount: 500)],
      );
      expect(tooLate.near, isEmpty);
      expect(tooLate.missing, hasLength(1));

      final tooFar = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: [_leg(id: 'a', date: DateTime(2026, 8, 4), amount: 600)],
      );
      expect(tooFar.near, isEmpty);
      expect(tooFar.missing, hasLength(1));
    });

    test('the book date is used when the value date is out of range', () {
      // A card row posted a week after the purchase is one payment, not two.
      final plan = _match(
        rows: [
          _row(
            rowId: 'r1',
            date: DateTime(2026, 8, 10),
            amount: -481,
            bookDate: DateTime(2026, 8, 3),
          ),
          _row(
            rowId: 'r2',
            date: DateTime(2026, 8, 4),
            amount: -200,
            bookDate: DateTime(2026, 8, 4),
          ),
        ],
        recorded: [
          _leg(id: 'a', date: DateTime(2026, 8, 3), amount: 481),
          _leg(id: 'b', date: DateTime(2026, 8, 4), amount: 200),
        ],
      );

      final onBookDate = plan.matched.firstWhere(
        (match) => match.row.rowId == 'r1',
      );
      expect(onBookDate.dateFieldUsed, 'book_date');
      expect(onBookDate.reasons, [
        'matched on the book date, not the value date',
      ]);
      final onValueDate = plan.matched.firstWhere(
        (match) => match.row.rowId == 'r2',
      );
      expect(onValueDate.dateFieldUsed, 'date');
      expect(onValueDate.reasons, isEmpty);
    });

    test('a leg in another currency is excluded and counted', () {
      // Folding it into the total would label two currencies with one code.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: [
          _leg(
            id: 'a',
            date: DateTime(2026, 8, 3),
            amount: 481,
            currencyCode: 'EUR',
          ),
        ],
      );

      expect(plan.excludedForeignCurrencySplits, 1);
      expect(plan.matched, isEmpty);
      expect(plan.arithmetic.recordedSum, 0);
      expect(plan.missing.single.rowId, 'r1');
    });

    test('a conversion into this account pairs on its foreign amount', () {
      // A pocket-to-pocket exchange is booked in the source currency, and the
      // statement only ever shows what landed. Excluding it reported the row as
      // missing, and writing it would have duplicated the conversion.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: 3228.98)],
        recorded: [
          _leg(
            id: 'a',
            date: DateTime(2026, 8, 3),
            amount: 4600,
            currencyCode: 'EUR',
            sourceId: '9',
            destinationId: _accountId,
            foreignAmount: 3228.98,
            foreignCurrencyCode: _currency,
          ),
        ],
      );

      expect(plan.excludedForeignCurrencySplits, 0);
      expect(plan.missing, isEmpty);
      expect(plan.matched.single.recordedAmount, 3228.98);
      expect(plan.arithmetic.recordedSum, 3228.98);
    });

    test('a conversion out of this account keeps its sign', () {
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -1500)],
        recorded: [
          _leg(
            id: 'a',
            date: DateTime(2026, 8, 3),
            amount: 2137,
            currencyCode: 'EUR',
            foreignAmount: 1500,
            foreignCurrencyCode: _currency,
          ),
        ],
      );

      expect(plan.matched.single.recordedAmount, -1500);
      expect(plan.arithmetic.recordedSum, -1500);
    });

    test('a foreign leg whose other side is a third currency stays out', () {
      // Neither figure is in the statement's currency, so there is nothing to
      // compare and folding it in would label two currencies with one code.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: [
          _leg(
            id: 'a',
            date: DateTime(2026, 8, 3),
            amount: 481,
            currencyCode: 'EUR',
            foreignAmount: 52,
            foreignCurrencyCode: 'USD',
          ),
        ],
      );

      expect(plan.excludedForeignCurrencySplits, 1);
      expect(plan.missing.single.rowId, 'r1');
    });

    test('a transaction touching neither leg of the account is no unit', () {
      final plan = _match(
        rows: const [],
        recorded: [
          _leg(
            id: 'a',
            date: DateTime(2026, 8, 3),
            amount: 481,
            sourceId: '5',
            destinationId: '9',
          ),
        ],
      );

      expect(plan.unmatchedRecorded, isEmpty);
      expect(plan.excludedForeignCurrencySplits, 0);
      expect(plan.arithmetic.recordedSum, 0);
    });

    test('a leg outside the period stays matchable but out of the total', () {
      // The fetch pads the window so a boundary row is not written twice.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 1), amount: -481)],
        recorded: [_leg(id: 'a', date: DateTime(2026, 7, 31), amount: 481)],
      );

      expect(plan.matched.single.leg.transactionId, 'a');
      expect(plan.excludedOutsidePeriod, 1);
      expect(plan.arithmetic.recordedSum, 0);
      expect(plan.unmatchedRecorded, isEmpty);
    });

    test('a future-dated transaction is in the sum and in unmatched, or in '
        'neither', () {
      // Two figures over two different sets would look like each other's proof.
      final future = DateTime.now().add(const Duration(days: 3));
      final plan = _match(
        rows: const [],
        recorded: [_leg(id: 'future', date: future, amount: 481)],
        periodStart: future.subtract(const Duration(days: 30)),
        periodEnd: future.add(const Duration(days: 1)),
      );

      expect(plan.arithmetic.recordedSum, -481);
      expect(plan.unmatchedRecorded.single.transactionId, 'future');
    });

    test('opening plus rows not equalling closing fails both checks', () {
      // A plan built on an incomplete export must not read as trustworthy.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: const [],
        openingBalance: 1000,
        closingBalance: 600,
      );

      final selfCheck = plan.selfCheck!;
      expect(selfCheck.opening, 1000);
      expect(selfCheck.rowsSum, -481);
      expect(selfCheck.impliedClosing, 519);
      expect(selfCheck.statedClosing, 600);
      expect(selfCheck.agrees, isFalse);
      expect(plan.arithmetic.agrees, isFalse);
      expect(plan.arithmetic.disagreementReason, 'statement_self_check_failed');
    });

    test('a plan that closes the balance gap agrees', () {
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: const [],
        openingBalance: 1000,
        closingBalance: 519,
      );

      expect(plan.selfCheck!.agrees, isTrue);
      expect(plan.arithmetic.balanceGap, -481);
      expect(plan.arithmetic.rowsMinusRecorded, -481);
      expect(plan.arithmetic.gapClosedByPlan, isTrue);
      expect(plan.arithmetic.agrees, isTrue);
      expect(plan.arithmetic.disagreementReason, isNull);
    });

    test('without balances the arithmetic answers null, never true', () {
      // A missing balance is not evidence that the ledger is complete.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: [_leg(id: 'a', date: DateTime(2026, 8, 3), amount: 481)],
      );

      expect(plan.selfCheck, isNull);
      expect(plan.arithmetic.balanceGap, isNull);
      expect(plan.arithmetic.gapClosedByPlan, isFalse);
      expect(plan.arithmetic.agrees, isNull);
      expect(plan.arithmetic.disagreementReason, 'balances_not_supplied');
    });

    test('an unreadable row forces the arithmetic to disagree', () {
      // The sums are short by that row, so they cannot be said to agree.
      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 3), amount: -481)],
        recorded: const [],
        openingBalance: 1000,
        closingBalance: 519,
        needsInput: const [
          StatementNeedsInput(
            rowId: 'r2',
            rawAmount: '1,234.56',
            reason: 'unreadable',
            candidates: [1234.56],
          ),
        ],
      );

      expect(plan.needsInput.single.rowId, 'r2');
      expect(plan.arithmetic.statementRowsSum, -481);
      expect(plan.arithmetic.agrees, isFalse);
      expect(plan.arithmetic.disagreementReason, 'unparsed_rows_present');
    });
  });

  group('parseStatementRows', () {
    RawStatementRow raw(String rowId, String amount) => RawStatementRow(
      rowId: rowId,
      date: DateTime(2026, 8, 3),
      rawAmount: amount,
    );

    test('one grammar reads every row in the export', () {
      final result =
          parseStatementRows(
                rows: [raw('r1', '-481,00'), raw('r2', '-1 234,56')],
              )
              as StatementParsed;

      expect(result.grammar, AmountGrammar.commaDecimal);
      expect(result.rows.map((row) => row.amount).toList(), [-481.0, -1234.56]);
      expect(result.needsInput, isEmpty);
      expect(result.openingBalance, isNull);
    });

    test('the balances settle the grammar the rows cannot', () {
      // Settling over the rows alone would refuse a readable export.
      final result =
          parseStatementRows(
                rows: [raw('r1', '1,234')],
                closingBalance: '-9 889,00',
              )
              as StatementParsed;

      expect(result.grammar, AmountGrammar.commaDecimal);
      expect(result.rows.single.amount, 1.234);
      expect(result.closingBalance, -9889.0);
    });

    test('a corpus with no evidence asks for amount_format', () {
      // Picking a separator here books a thousandth of the real amount.
      final result =
          parseStatementRows(rows: [raw('r1', '1,234'), raw('r2', '2,345')])
              as StatementParseFailure;

      expect(result.field, 'amount_format');
      expect(result.message, contains('amount_format'));
    });

    test('a caller-supplied format is used instead of inference', () {
      final result =
          parseStatementRows(
                rows: [raw('r1', '1,234')],
                amountFormat: AmountGrammar.dotDecimal,
              )
              as StatementParsed;

      expect(result.rows.single.amount, 1234.0);
    });

    test('a balance that will not read names its own field', () {
      // Falling back to the other grammar for one number would misread it.
      final opening =
          parseStatementRows(
                rows: [raw('r1', '-481,00')],
                openingBalance: 'n/a',
              )
              as StatementParseFailure;
      expect(opening.field, 'opening_balance');

      final closing =
          parseStatementRows(
                rows: [raw('r1', '-481,00')],
                openingBalance: '1 000,00',
                closingBalance: 'n/a',
              )
              as StatementParseFailure;
      expect(closing.field, 'closing_balance');
    });

    test('a row the grammar cannot read comes back with its readings', () {
      // The human answering sees both values instead of re-typing the number.
      final result =
          parseStatementRows(
                rows: [raw('r1', '-481,00'), raw('r2', '1,234.56')],
                amountFormat: AmountGrammar.commaDecimal,
              )
              as StatementParsed;

      expect(result.rows.single.rowId, 'r1');
      final needsInput = result.needsInput.single;
      expect(needsInput.rowId, 'r2');
      expect(needsInput.rawAmount, '1,234.56');
      expect(needsInput.reason, 'unreadable');
      expect(needsInput.candidates, [1234.56]);
    });

    test('a double-signed row is surfaced, never guessed', () {
      final result =
          parseStatementRows(
                rows: [raw('r1', '-481,00'), raw('r2', '-9 889,00-')],
              )
              as StatementParsed;

      expect(result.needsInput.single.reason, 'double_sign');
      expect(result.needsInput.single.candidates, isEmpty);
    });
  });

  group('one line paying a whole journal', () {
    test('a mortgage split is matched by its summed legs', () {
      // Found against a real ledger: the bank debits one amount and the
      // journal records amortisation plus the interest on each loan. Matching
      // legs only, the row read as missing and its legs as strangers, which is
      // the shape that makes an importer add a second mortgage payment.
      final group = _splitGroup(
        id: '500',
        splits: [
          _leg(
            id: '500',
            journalId: '9001',
            date: DateTime(2026, 8, 1),
            amount: 3400,
            description: 'amortisation',
          ),
          _leg(
            id: '500',
            journalId: '9002',
            date: DateTime(2026, 8, 1),
            amount: 3473,
            description: 'interest loan 1',
          ),
          _leg(
            id: '500',
            journalId: '9003',
            date: DateTime(2026, 8, 1),
            amount: 3016,
            description: 'interest loan 2',
          ),
        ],
      );

      final plan = _match(
        rows: [
          _row(
            rowId: 'r1',
            date: DateTime(2026, 8, 3),
            amount: -9889,
            text: 'BOLANEBANK',
          ),
        ],
        recorded: [group],
      );

      expect(plan.matched, hasLength(1));
      final match = plan.matched.single;
      expect(match.legsConsumed, 3);
      expect(match.groupAmount, closeTo(-9889, 0.005));
      expect(match.recordedAmount, closeTo(-9889, 0.005));
      expect(match.amountDelta, closeTo(0, 0.005));
      expect(match.reasons.single, contains('3 legs'));
      // Every leg is spent, so none is reported as unexplained.
      expect(plan.unmatchedRecorded, isEmpty);
      expect(plan.missing, isEmpty);
    });

    test('a leg that matches outright keeps priority over its group', () {
      // The more specific reading wins: a row equal to one leg must not eat
      // the whole journal and orphan the rest.
      final group = _splitGroup(
        id: '600',
        splits: [
          _leg(
            id: '600',
            journalId: '1',
            date: DateTime(2026, 8, 1),
            amount: 100,
          ),
          _leg(
            id: '600',
            journalId: '2',
            date: DateTime(2026, 8, 1),
            amount: 50,
          ),
        ],
      );

      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 1), amount: -100)],
        recorded: [group],
      );

      expect(plan.matched.single.legsConsumed, 1);
      expect(plan.unmatchedRecorded, hasLength(1));
      expect(plan.unmatchedRecorded.single.signedAmount, closeTo(-50, 0.005));
    });

    test('a group whose sum is off by a krona is not claimed', () {
      final group = _splitGroup(
        id: '700',
        splits: [
          _leg(
            id: '700',
            journalId: '1',
            date: DateTime(2026, 8, 1),
            amount: 100,
          ),
          _leg(
            id: '700',
            journalId: '2',
            date: DateTime(2026, 8, 1),
            amount: 50,
          ),
        ],
      );

      final plan = _match(
        rows: [_row(rowId: 'r1', date: DateTime(2026, 8, 1), amount: -151)],
        recorded: [group],
      );

      expect(plan.matched, isEmpty);
      expect(plan.missing, hasLength(1));
    });
  });
}
