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
    final correction = createCorrection
        ? await _correct(
            accountId: accountId,
            accountName: accountName,
            currencyCode: currencyCode,
            currencySymbol: currencySymbol,
            endDate: endDate,
            gap: gap,
            tolerance: tolerance,
          )
        : null;

    return ReconciliationStoreResult(
      reconciled: reconciled,
      correction: correction,
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
        ? null
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
      correction: corrected,
      payback: payback,
    );
  }

  /// The correction for [gap] on [endDate], or nothing when the gap is within
  /// [tolerance].
  Future<Transaction?> _correct({
    required String accountId,
    required String accountName,
    required String currencyCode,
    required String currencySymbol,
    required DateTime endDate,
    required double gap,
    required double tolerance,
  }) async {
    if (gap.abs() <= tolerance) return null;
    await _ensureReconciliationAccount(
      accountName: accountName,
      currencyCode: currencyCode,
    );
    return _api.createTransaction(
      buildReconciliationCorrection(
        accountId: accountId,
        accountName: accountName,
        currencyCode: currencyCode,
        currencySymbol: currencySymbol,
        gap: gap,
        endDate: endDate,
      ),
    );
  }

  /// Makes the `<account> reconciliation` account a correction refers to, if
  /// Firefly has not.
  ///
  /// Firefly creates one only from its own interface, so on a ledger that has
  /// never reconciled this account there is nothing for the correction to name
  /// and the write is refused. Nothing in the API surface made one either,
  /// which left the correction impossible rather than merely awkward.
  ///
  /// Asked for by type, because a plain account read covers asset and
  /// liability only and would not see an existing one.
  Future<void> _ensureReconciliationAccount({
    required String accountName,
    required String currencyCode,
  }) async {
    final wanted = reconciliationAccountName(accountName);
    final existing = await _api.getAccounts(types: const ['reconciliation']);
    final already = existing.any(
      (account) => account.name.toLowerCase() == wanted.toLowerCase(),
    );
    if (already) return;
    await _api.createAccount(
      name: wanted,
      type: 'reconciliation',
      currencyCode: currencyCode,
    );
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
