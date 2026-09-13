import '../models/account.dart';
import '../models/transaction.dart';
import 'transaction_splits.dart';

/// True when [account] is a Firefly credit-card asset (`ccAsset` role).
bool isCreditCardAccount(Account account) => account.role == 'ccAsset';

/// True when [transaction] increases card debt (negative signed effect on
/// [cardName]) — typically a withdrawal or transfer out of the card.
bool isCreditCardPurchase(Transaction transaction, String cardName) {
  return signedAmountForAccount(transaction, cardName) < 0;
}

/// True when [transaction] puts money back on the card from outside: a refund
/// from a shop, not a payment from another account of the person's own.
///
/// A payment into the card is a transfer between two of their accounts and is
/// the thing being built here, so it is left out either way. A refund is not:
/// the bank nets it off the statement, and so must this.
bool isCreditCardRefund(Transaction transaction, String cardName) {
  return transaction.type != 'transfer' &&
      signedAmountForAccount(transaction, cardName) > 0;
}

/// Absolute amount to repay for [transaction] on [cardName].
double creditCardPaybackAmount(Transaction transaction, String cardName) {
  return signedAmountForAccount(transaction, cardName).abs();
}

/// Asset accounts eligible as the source of a credit-card payback.
List<Account> paymentAccountsForCreditCard(
  Account creditCard,
  Iterable<Account> accounts,
) {
  return accounts
      .where(
        (account) =>
            account.active &&
            account.type == 'asset' &&
            account.id != creditCard.id &&
            account.currencyCode == creditCard.currencyCode &&
            !isCreditCardAccount(account),
      )
      .toList();
}

String creditCardPaybackLinkNote(String journalId) =>
    'fireraccoon:linked_journal:$journalId';

/// Builds a Platinum-style multi-split transfer that pays back [purchases].
///
/// Each eligible purchase becomes one transfer split from [paymentAccount] to
/// [creditCard] on [paybackDate], preserving description/category/tags and a
/// machine-readable link note.
///
/// A refund among them is netted off instead, and the whole thing collapses to
/// one leg for what is actually owed. Firefly wants every split of a transfer
/// to share one source and one destination, so a refund cannot be a leg going
/// the other way, and leaving it out altogether was the bug: the payback came
/// out larger than the bill by the size of the refund, and the card kept a
/// credit nobody had.
Transaction buildCreditCardPaybackTransfer({
  required Account paymentAccount,
  required Account creditCard,
  required DateTime paybackDate,
  required List<Transaction> purchases,
}) {
  final eligible = purchases
      .where((purchase) => isCreditCardPurchase(purchase, creditCard.name))
      .toList();
  if (eligible.isEmpty) {
    throw ArgumentError('No eligible credit card purchases to pay back');
  }
  final refunds = purchases
      .where((purchase) => isCreditCardRefund(purchase, creditCard.name))
      .toList();

  final splits = <Transaction>[
    for (final purchase in eligible)
      Transaction(
        id: '',
        type: 'transfer',
        date: paybackDate,
        amount: creditCardPaybackAmount(purchase, creditCard.name),
        description: purchase.description,
        sourceName: paymentAccount.name,
        destinationName: creditCard.name,
        sourceId: paymentAccount.id,
        destinationId: creditCard.id,
        categoryName: purchase.categoryName,
        categoryId: purchase.categoryId,
        currencySymbol: creditCard.currencySymbol,
        currencyCode: creditCard.currencyCode,
        tags: purchase.tags,
        notes: creditCardPaybackLinkNote(purchase.id),
        reconciled: true,
      ),
  ];

  if (refunds.isNotEmpty) {
    return _nettedPayback(
      paymentAccount: paymentAccount,
      creditCard: creditCard,
      paybackDate: paybackDate,
      charges: eligible,
      refunds: refunds,
    );
  }

  final first = splits.first;
  return Transaction(
    id: '',
    type: 'transfer',
    date: paybackDate,
    amount: first.amount,
    description: first.description,
    sourceName: paymentAccount.name,
    destinationName: creditCard.name,
    sourceId: paymentAccount.id,
    destinationId: creditCard.id,
    categoryName: first.categoryName,
    categoryId: first.categoryId,
    currencySymbol: creditCard.currencySymbol,
    currencyCode: creditCard.currencyCode,
    tags: first.tags,
    notes: first.notes,
    reconciled: true,
    groupTitle: '${creditCard.name} Payback',
    splits: splits,
  );
}

/// One leg for what is left to pay once the refunds are taken off.
///
/// The legs go, because none of them is true on its own any more: what left
/// the account is the difference. Every row it settles is still named in the
/// notes, refunds included, so the link back is not lost with them.
Transaction _nettedPayback({
  required Account paymentAccount,
  required Account creditCard,
  required DateTime paybackDate,
  required List<Transaction> charges,
  required List<Transaction> refunds,
}) {
  final owed =
      charges.fold<double>(
        0,
        (sum, charge) => sum + creditCardPaybackAmount(charge, creditCard.name),
      ) -
      refunds.fold<double>(
        0,
        (sum, refund) => sum + creditCardPaybackAmount(refund, creditCard.name),
      );
  if (owed <= 0.005) {
    throw ArgumentError(
      'The refunds in this selection are worth as much as the purchases, so '
      'there is nothing left to pay back',
    );
  }

  return Transaction(
    id: '',
    type: 'transfer',
    date: paybackDate,
    amount: owed,
    description: '${creditCard.name} Payback',
    sourceName: paymentAccount.name,
    destinationName: creditCard.name,
    sourceId: paymentAccount.id,
    destinationId: creditCard.id,
    categoryName: '',
    currencySymbol: creditCard.currencySymbol,
    currencyCode: creditCard.currencyCode,
    notes: [
      for (final settled in [...charges, ...refunds])
        creditCardPaybackLinkNote(settled.id),
    ].join('\n'),
    reconciled: true,
  );
}

/// The link a payback leg carries, whichever spelling wrote it.
///
/// Rows written before the raccoon rename carry `fireracoon:` with one `c`,
/// so a reader that took only the current spelling would lose a year of
/// links.
final RegExp _linkNote = RegExp(r'firerac{1,2}oon:linked_journal:(\S+)');

/// Transaction ids the link notes in [notes] name.
Set<String> linkedJournalIdsIn(String? notes) => {
  if (notes != null)
    for (final match in _linkNote.allMatches(notes)) match.group(1)!,
};

/// Every transaction a payback's legs link, once each, in note order.
List<String> paybackSettledIds(Transaction payback) {
  final seen = <String>{};
  return [
    for (final leg in payback.resolvedSplits())
      for (final id in linkedJournalIdsIn(leg.notes))
        if (seen.add(id)) id,
  ];
}

/// True when [transaction] pays [card] down from another account of the
/// person's own: a transfer whose money lands on the card.
bool isCreditCardPayback(Transaction transaction, Account card) =>
    transaction.type == 'transfer' &&
    signedAmountForAccount(transaction, card.name) > 0;

/// One payback and what its link notes say it settled.
class PaybackSettlement {
  const PaybackSettlement({
    required this.payback,
    required this.settles,
    required this.notFetched,
  });

  final Transaction payback;

  /// The linked rows among the transactions given.
  final List<Transaction> settles;

  /// Linked ids none of the transactions given carries: rows settled from
  /// before the window that was read.
  final List<String> notFetched;

  /// False for a payback written by hand, which links nothing.
  bool get linked => settles.isNotEmpty || notFetched.isNotEmpty;
}

/// What the paybacks on a card settle, and what they leave unsettled.
class CardSettlements {
  const CardSettlements({required this.paybacks, required this.unsettled});

  /// Every payback, oldest first.
  final List<PaybackSettlement> paybacks;

  /// Purchases and refunds dated before the last payback that no payback
  /// links: a row a payback missed, or one settled by hand.
  final List<Transaction> unsettled;

  Iterable<PaybackSettlement> get unlinkedPaybacks =>
      paybacks.where((settlement) => !settlement.linked);

  Transaction? get lastPayback =>
      paybacks.isEmpty ? null : paybacks.last.payback;
}

/// Reads the link notes on every payback among [transactions] back against
/// the purchases and refunds on [card].
///
/// Nothing read the notes before this, which is how a year of paybacks
/// written by hand as single untitled legs went unnoticed: the app never
/// compared purchases against paybacks.
CardSettlements analyseCardSettlements({
  required Account card,
  required List<Transaction> transactions,
}) {
  final rows = [
    for (final transaction in transactions)
      if (isCreditCardPurchase(transaction, card.name) ||
          isCreditCardRefund(transaction, card.name))
        transaction,
  ];
  final byId = {for (final row in rows) row.id: row};
  final paybacks = [
    for (final transaction in transactions)
      if (isCreditCardPayback(transaction, card)) transaction,
  ]..sort((a, b) => a.date.compareTo(b.date));

  final linked = <String>{};
  final settlements = <PaybackSettlement>[];
  for (final payback in paybacks) {
    final ids = paybackSettledIds(payback);
    linked.addAll(ids);
    settlements.add(
      PaybackSettlement(
        payback: payback,
        settles: [for (final id in ids) ?byId[id]],
        notFetched: [
          for (final id in ids)
            if (!byId.containsKey(id)) id,
        ],
      ),
    );
  }
  if (paybacks.isEmpty) {
    return CardSettlements(paybacks: settlements, unsettled: const []);
  }

  // A purchase dated on the payback day belongs to the next cycle, so only
  // strictly earlier rows count.
  final cutoff = _day(paybacks.last.date);
  final unsettled = [
    for (final row in rows)
      if (_day(row.date).isBefore(cutoff) && !linked.contains(row.id)) row,
  ]..sort((a, b) => a.date.compareTo(b.date));
  return CardSettlements(paybacks: settlements, unsettled: unsettled);
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
