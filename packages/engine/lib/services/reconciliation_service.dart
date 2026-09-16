import '../models/account.dart';
import '../models/transaction.dart';
import '../utils/credit_card_payback.dart';
import '../utils/reconciliation.dart';
import 'firefly_service.dart';

/// Persists a reconciliation session through the Firefly transaction API.
class ReconciliationService {
  const ReconciliationService(this._api);

  final FireflyService _api;

  Future<ReconciliationStoreResult> store({
    required List<Transaction> journalsToReconcile,
    required String accountId,
    required String accountName,
    required String currencyCode,
    required String currencySymbol,
    required DateTime endDate,
    required double gap,
    bool createCorrection = true,
    double tolerance = 0.005,
  }) async {
    final reconciled = await _markReconciled(journalsToReconcile);
    final corrected = createCorrection
        ? await _correct(
            accountId: accountId,
            accountName: accountName,
            currencyCode: currencyCode,
            currencySymbol: currencySymbol,
            endDate: endDate,
            gap: gap,
            tolerance: tolerance,
          )
        : const (correction: null, error: null, code: null);

    return ReconciliationStoreResult(
      reconciled: reconciled,
      correction: corrected.correction,
      correctionError: corrected.error,
      correctionErrorCode: corrected.code,
    );
  }

  /// Marks [journalsToReconcile] reconciled and creates a Platinum-style
  /// payback transfer from [paymentAccount] to [creditCard]: one leg per
  /// purchase, or a single netted leg when a refund is among them.
  ///
  /// [correction] is the gap the statement leaves at its close, as [store]
  /// takes it, and is written after the payback. The payback is dated past
  /// the close and never part of the gap, so a card whose ledger sat a fixed
  /// amount off the bank's balance had no way through this path to be put
  /// right.
  Future<ReconciliationStoreResult> storeCreditCardPayback({
    required List<Transaction> journalsToReconcile,
    required Account creditCard,
    required Account paymentAccount,
    required DateTime paybackDate,
    ({double gap, DateTime endDate})? correction,
    double tolerance = 0.005,
  }) async {
    if (!isCreditCardAccount(creditCard)) {
      throw ArgumentError('creditCard must have role ccAsset');
    }
    if (paymentAccount.type != 'asset' ||
        paymentAccount.currencyCode != creditCard.currencyCode ||
        paymentAccount.id == creditCard.id) {
      throw ArgumentError(
        'paymentAccount must be a different asset in the same currency',
      );
    }

    final reconciled = await _markReconciled(journalsToReconcile);
    final payback = await _api.createTransaction(
      buildCreditCardPaybackTransfer(
        paymentAccount: paymentAccount,
        creditCard: creditCard,
        paybackDate: paybackDate,
        purchases: journalsToReconcile,
      ),
    );
    final corrected = correction == null
        ? const (correction: null, error: null, code: null)
        : await _correct(
            accountId: creditCard.id,
            accountName: creditCard.name,
            currencyCode: creditCard.currencyCode,
            currencySymbol: creditCard.currencySymbol,
            endDate: correction.endDate,
            gap: correction.gap,
            tolerance: tolerance,
          );

    return ReconciliationStoreResult(
      reconciled: reconciled,
      correction: corrected.correction,
      payback: payback,
      correctionError: corrected.error,
      correctionErrorCode: corrected.code,
    );
  }

  /// The correction for [gap] on [endDate], or nothing when the gap is within
  /// [tolerance].
  ///
  /// The account the other side goes against is read, never guessed and never
  /// made. Firefly keeps one per asset account, names it itself, and makes it
  /// only from its own interface: its API refuses the type outright, and a
  /// correction naming an account it cannot find is refused as well. Guessing
  /// the name missed the currency Firefly puts in it, and leaving the side
  /// empty, which is how its own interface asks the factory to fill the
  /// account in, does not survive the REST layer: an absent name arrives as an
  /// empty string, so the validator searches for an account called nothing and
  /// the request builds zero journals.
  ///
  /// Still true of 6.7.1, checked against its source rather than assumed from
  /// 6.6.6. The account endpoint validates the type against the keys of
  /// `firefly.subTitlesByIdentifier`, which are asset, expense, revenue, cash,
  /// liabilities and liability. The empty side is `clearString`, which returns
  /// null for null but the empty string for the empty string, and the
  /// transaction request casts the absent name to string before it gets there.
  ///
  /// A refusal comes back rather than up. The journals are marked first and
  /// that half stands, so an account the interface has never reconciled, or
  /// one Firefly will not reconcile at all, is reported rather than thrown.
  Future<({Transaction? correction, String? error, String? code})> _correct({
    required String accountId,
    required String accountName,
    required String currencyCode,
    required String currencySymbol,
    required DateTime endDate,
    required double gap,
    required double tolerance,
  }) async {
    if (gap.abs() <= tolerance) {
      return (correction: null, error: null, code: null);
    }
    final Account? against;
    try {
      against = findReconciliationAccount(
        await _api.getAccounts(types: const ['reconciliation']),
        accountName: accountName,
        currencyCode: currencyCode,
      );
    } on Object catch (error) {
      return (
        correction: null,
        code: reconciliationAccountsUnreadable,
        error:
            'the accounts Firefly keeps for corrections could not be read: '
            '$error',
      );
    }
    if (against == null) {
      return (
        correction: null,
        code: reconciliationAccountMissing,
        error:
            'Firefly keeps one reconciliation account per asset account and '
            'has none for "$accountName". Its API cannot make one, so this '
            'is not a step that can be retried from here: the account '
            'endpoint takes asset, expense, revenue, cash and liability and '
            'refuses the reconciliation type, and the correction cannot ask '
            'Firefly to fill the account in either, because a side left '
            'empty reaches the validator as an empty name rather than as no '
            'name and matches nothing. Reconcile "$accountName" once in '
            "Firefly's own interface to make the account, after which "
            'corrections for it can be written here.',
      );
    }
    try {
      final correction = await _api.createTransaction(
        buildReconciliationCorrection(
          accountId: accountId,
          accountName: accountName,
          reconciliationAccountId: against.id,
          reconciliationAccountName: against.name,
          currencyCode: currencyCode,
          currencySymbol: currencySymbol,
          gap: gap,
          endDate: endDate,
        ),
      );
      return (correction: correction, error: null, code: null);
    } on Object catch (error) {
      return (correction: null, code: correctionRefused, error: '$error');
    }
  }

  Future<List<Transaction>> _markReconciled(
    List<Transaction> journalsToReconcile,
  ) async {
    final reconciled = <Transaction>[];
    for (final journal in journalsToReconcile) {
      if (journal.isReconciled) {
        reconciled.add(journal);
        continue;
      }
      try {
        reconciled.add(
          await _api.updateTransaction(journal.withReconciled(true)),
        );
      } catch (error) {
        // Non-atomic: already-reconciled journals stay reconciled. Surface
        // how far we got so callers can retry the remainder.
        Error.throwWithStackTrace(
          StateError(
            'Reconciliation failed after marking ${reconciled.length} of '
            '${journalsToReconcile.length} journals: $error',
          ),
          StackTrace.current,
        );
      }
    }
    return reconciled;
  }
}
