import '../models/transaction.dart';
import 'money.dart';
import 'transaction_splits.dart';

/// One bucket of an account's balance series: what it closed at, and the
/// flows that took it there.
class AccountBalancePoint {
  const AccountBalancePoint({
    required this.date,
    required this.balance,
    required this.earned,
    required this.spent,
  });

  /// Last day the bucket covers, inclusive.
  final DateTime date;

  /// The account's balance at the close of [date].
  final double balance;

  /// Money that arrived in the bucket, zero or above.
  final double earned;

  /// Money that left in the bucket, zero or below.
  final double spent;

  Map<String, Object?> toJson() => {
    'date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'balance': balance,
    'earned': earned,
    'spent': spent,
  };
}

/// Inclusive last day of each bucket between [start] and [end].
///
/// A calendar period closes on the last day of its month so that a monthly
/// series reads as month ends, which is what comparing statements wants. A day
/// or week period advances by its own length from [start]. The final bucket is
/// cut at [end] rather than run past it, so the series never claims a balance
/// for a date the caller did not ask about.
List<DateTime> balanceSeriesBucketEnds({
  required DateTime start,
  required DateTime end,
  required String period,
}) {
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(end.year, end.month, end.day);
  if (to.isBefore(from)) return const [];

  final months = _calendarMonths(period);
  final ends = <DateTime>[];
  if (months != null) {
    var cursor = DateTime(
      from.year,
      from.month + months,
      1,
    ).subtract(const Duration(days: 1));
    while (cursor.isBefore(to)) {
      ends.add(cursor);
      cursor = DateTime(
        cursor.year,
        cursor.month + 1 + months,
        1,
      ).subtract(const Duration(days: 1));
    }
    ends.add(to);
    return ends;
  }

  final days = _fixedDays(period);
  var cursor = from.add(Duration(days: days - 1));
  while (cursor.isBefore(to)) {
    ends.add(cursor);
    cursor = cursor.add(Duration(days: days));
  }
  ends.add(to);
  return ends;
}

/// Periods this builds a series for, as Firefly spells them.
const List<String> balanceSeriesPeriods = ['1D', '1W', '1M', '3M', '6M', '1Y'];

int? _calendarMonths(String period) => switch (period.toUpperCase()) {
  '1M' => 1,
  '3M' => 3,
  '6M' => 6,
  '1Y' => 12,
  _ => null,
};

int _fixedDays(String period) => switch (period.toUpperCase()) {
  '1W' => 7,
  _ => 1,
};

/// The balance an account closes each bucket at, walked forward from
/// [openingBalance].
///
/// [openingBalance] is what the account stood at before [bucketEnds] begins,
/// so one balance read plus one pass over the transactions answers the whole
/// window. Asking Firefly for a balance per bucket instead costs a call per
/// date, which is what made sweeping a card against its invoice history
/// impractical.
///
/// A transaction after the last bucket end is left out; one before the first
/// belongs in [openingBalance], not here.
List<AccountBalancePoint> buildAccountBalanceSeries({
  required double openingBalance,
  required Iterable<Transaction> transactions,
  required String accountName,
  required List<DateTime> bucketEnds,
  int decimals = defaultCurrencyDecimals,
}) {
  if (bucketEnds.isEmpty) return const [];

  final ordered = transactions.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final points = <AccountBalancePoint>[];
  var balance = openingBalance;
  var index = 0;

  for (final end in bucketEnds) {
    final closesAt = DateTime(end.year, end.month, end.day, 23, 59, 59);
    var earned = 0.0;
    var spent = 0.0;
    while (index < ordered.length && !ordered[index].date.isAfter(closesAt)) {
      final effect = signedAmountForAccount(ordered[index], accountName);
      if (effect >= 0) {
        earned += effect;
      } else {
        spent += effect;
      }
      balance += effect;
      index++;
    }
    points.add(
      AccountBalancePoint(
        date: DateTime(end.year, end.month, end.day),
        balance: roundMoney(balance, decimals: decimals),
        earned: roundMoney(earned, decimals: decimals),
        spent: roundMoney(spent, decimals: decimals),
      ),
    );
  }
  return points;
}
