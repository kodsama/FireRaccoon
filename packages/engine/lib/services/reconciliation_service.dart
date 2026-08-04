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

    Transaction? correction;
    if (createCorrection && gap.abs() > tolerance) {
      correction = await _api.createTransaction(
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

    return ReconciliationStoreResult(
      reconciled: reconciled,
      correction: correction,
    );
  }

  /// Marks [journalsToReconcile] reconciled and creates a Platinum-style
  /// multi-split payback transfer from [paymentAccount] to [creditCard].
  Future<ReconciliationStoreResult> storeCreditCardPayback({
    required List<Transaction> journalsToReconcile,
    required Account creditCard,
    required Account paymentAccount,
    required DateTime paybackDate,
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

    return ReconciliationStoreResult(reconciled: reconciled, payback: payback);
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
