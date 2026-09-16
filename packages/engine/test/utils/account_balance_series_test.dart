import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

Transaction _tx({
  required String id,
  required DateTime date,
  required double amount,
  String type = 'withdrawal',
  String source = 'Card',
  String destination = 'Store',
}) => Transaction(
  id: id,
  type: type,
  date: date,
  amount: amount,
  description: id,
  sourceName: source,
  destinationName: destination,
  categoryName: '',
  currencySymbol: '€',
  currencyCode: 'EUR',
);

void main() {
  group('balanceSeriesBucketEnds', () {
    test('a monthly period closes on month ends', () {
      final ends = balanceSeriesBucketEnds(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 9, 16),
        period: '1M',
      );

      // Comparing statements wants month ends, and the last bucket is cut at
      // end_date rather than run on to the 30th.
      expect(ends, [
        DateTime(2026, 7, 31),
        DateTime(2026, 8, 31),
        DateTime(2026, 9, 16),
      ]);
    });

    test('a daily period covers the window inclusively and no further', () {
      final ends = balanceSeriesBucketEnds(
        start: DateTime(2026, 9, 10),
        end: DateTime(2026, 9, 16),
        period: '1D',
      );

      // A 7-day inclusive window is 7 buckets. It answered 8, so a reader
      // could not even align the series by counting.
      expect(ends, hasLength(7));
      expect(ends.first, DateTime(2026, 9, 10));
      expect(ends.last, DateTime(2026, 9, 16));
    });

    test('a window of one day is one bucket', () {
      expect(
        balanceSeriesBucketEnds(
          start: DateTime(2026, 9, 16),
          end: DateTime(2026, 9, 16),
          period: '1M',
        ),
        [DateTime(2026, 9, 16)],
      );
    });

    test('an end before the start is no series at all', () {
      expect(
        balanceSeriesBucketEnds(
          start: DateTime(2026, 9, 16),
          end: DateTime(2026, 9, 10),
          period: '1D',
        ),
        isEmpty,
      );
    });
  });

  group('buildAccountBalanceSeries', () {
    test('each bucket closes at the balance the flows leave', () {
      final points = buildAccountBalanceSeries(
        openingBalance: -1000.00,
        transactions: [
          _tx(id: '1', date: DateTime(2026, 7, 4), amount: 200.00),
          _tx(
            id: '2',
            date: DateTime(2026, 8, 9),
            amount: 500.00,
            type: 'deposit',
            source: 'Employer',
            destination: 'Card',
          ),
          _tx(id: '3', date: DateTime(2026, 9, 2), amount: 50.00),
        ],
        accountName: 'Card',
        bucketEnds: balanceSeriesBucketEnds(
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 9, 16),
          period: '1M',
        ),
      );

      expect(points.map((p) => p.balance), [-1200.00, -700.00, -750.00]);
      expect(points.map((p) => p.earned), [0.0, 500.00, 0.0]);
      expect(points.map((p) => p.spent), [-200.00, 0.0, -50.00]);
      expect(points.map((p) => p.toJson()['date']), [
        '2026-07-31',
        '2026-08-31',
        '2026-09-16',
      ]);
    });

    test('a transaction dated on the closing day lands in that bucket', () {
      // Firefly dates a journal at midnight, so a bucket that closed at the
      // start of its last day would push it into the next one.
      final points = buildAccountBalanceSeries(
        openingBalance: 0,
        transactions: [
          _tx(id: '1', date: DateTime(2026, 7, 31), amount: 10.00),
        ],
        accountName: 'Card',
        bucketEnds: [DateTime(2026, 7, 31), DateTime(2026, 8, 31)],
      );

      expect(points.first.spent, -10.00);
      expect(points.first.balance, -10.00);
      expect(points.last.balance, -10.00);
    });

    test('a balance made of many flows is money, not a float tail', () {
      final points = buildAccountBalanceSeries(
        openingBalance: 0,
        transactions: [
          for (final (index, amount) in [133.14, 326.50, 120.44].indexed)
            _tx(
              id: '$index',
              date: DateTime(2026, 7, index + 1),
              amount: amount,
            ),
        ],
        accountName: 'Card',
        bucketEnds: [DateTime(2026, 7, 31)],
      );

      expect(points.single.balance, -580.08);
    });

    test('no buckets is no series', () {
      expect(
        buildAccountBalanceSeries(
          openingBalance: 5,
          transactions: const [],
          accountName: 'Card',
          bucketEnds: const [],
        ),
        isEmpty,
      );
    });
  });
}
