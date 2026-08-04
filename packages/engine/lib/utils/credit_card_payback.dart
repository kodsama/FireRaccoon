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
    'fireracoon:linked_journal:$journalId';

/// Builds a Platinum-style multi-split transfer that pays back [purchases].
///
/// Each eligible purchase becomes one transfer split from [paymentAccount] to
/// [creditCard] on [paybackDate], preserving description/category/tags and a
/// machine-readable link note.
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
    groupTitle: 'Credit card payback — ${creditCard.name}',
    splits: splits,
  );
}
