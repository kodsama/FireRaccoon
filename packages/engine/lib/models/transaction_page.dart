import 'transaction.dart';

class TransactionPageResult {
  final List<Transaction> transactions;
  final int currentPage;
  final int totalPages;
  final int total;

  const TransactionPageResult({
    required this.transactions,
    required this.currentPage,
    required this.totalPages,
    required this.total,
  });
}
