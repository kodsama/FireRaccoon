import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

Transaction _tx({
  required String id,
  required String type,
  required DateTime date,
  required double amount,
  required String source,
  required String destination,
}) {
  return Transaction(
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
}

void main() {
  test(
    'reconstructAccountBalanceInRange starts at opening and applies in-range deltas',
    () {
      final history = reconstructAccountBalanceInRange(
        accountName: 'Checking',
        openingBalance: 100,
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
        transactions: [
          _tx(
            id: 'old',
            type: 'deposit',
            date: DateTime(2026, 6, 30),
            amount: 999,
            source: 'Employer',
            destination: 'Checking',
          ),
          _tx(
            id: 'in',
            type: 'deposit',
            date: DateTime(2026, 7, 2),
            amount: 50,
            source: 'Employer',
            destination: 'Checking',
          ),
          _tx(
            id: 'out',
            type: 'withdrawal',
            date: DateTime(2026, 7, 3),
            amount: 20,
            source: 'Checking',
            destination: 'Store',
          ),
        ],
      );

      expect(history, [100, 150, 130]);
    },
  );
}
