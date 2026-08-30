import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

/// Test double for [TransactionsNotifier] serving a fixed transaction list.
class FixedTransactionsNotifier extends TransactionsNotifier {
  FixedTransactionsNotifier(this._transactions);

  final List<Transaction> _transactions;

  @override
  Future<List<Transaction>> build() async => _transactions;
}
