/// The data sets Firefly III hands over as CSV from `/api/v1/data/export`.
///
/// This is Firefly's own export, not FireRaccoon's snapshot, and the two do not
/// overlap completely: rules and budget limits appear here and nowhere else the
/// API will give up, which is why a backup carries both halves.
enum FireflyCsvDataset {
  accounts('accounts'),
  bills('bills'),
  budgets('budgets'),
  categories('categories'),
  piggyBanks('piggy-banks'),
  recurring('recurring'),
  rules('rules'),
  tags('tags'),
  transactions('transactions');

  const FireflyCsvDataset(this.apiValue);

  /// Path segment Firefly names this data set by.
  final String apiValue;

  /// Name the file carrying this data set takes inside a backup.
  String get fileName => '$apiValue.csv';

  /// Whether the export reads the date window it is given.
  ///
  /// Only the transactions export does. Measured against 6.6.6: every other
  /// data set answers a one-day window, a fifteen-year window and no window at
  /// all with the same rows, so narrowing them buys nothing and risks losing
  /// rows to a bound that turns out to matter.
  bool get isWindowed => this == FireflyCsvDataset.transactions;
}
