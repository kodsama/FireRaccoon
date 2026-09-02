import '../models/account.dart';
import '../models/bill.dart';
import '../models/recurrence.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/currency.dart';
import '../models/firefly_csv_dataset.dart';
import '../models/firefly_user.dart';
import '../models/liability.dart';
import '../models/piggy_bank.dart';
import '../models/tag.dart';
import '../models/transaction.dart';
import '../models/transaction_page.dart';

abstract class FireflyService {
  Future<FireflyCurrency> getPrimaryCurrency();
  Future<void> setPrimaryCurrency(String code);
  Future<FireflyUser> getCurrentUser();
  Future<List<Account>> getAccounts({
    List<String> types = const ['asset', 'liability'],
  });
  Future<Account> getAccount(String accountId, {DateTime? date});
  Future<double> getAccountBalanceAtDate(String accountId, DateTime date);
  Future<Map<String, List<double>>> getAccountBalanceHistories({
    required List<Account> accounts,
    required DateTime start,
    required DateTime end,
    String period = '1M',
  });

  /// Fetches all transactions in the window. [onFirstPage] fires with the
  /// newest page as soon as it arrives so callers can paint progressively.
  ///
  /// [onPageProgress] fires per page with the count so far and the total, which
  /// is what lets a long walk report how far along it is rather than only that
  /// it started.
  Future<List<Transaction>> getTransactions({
    DateTime? start,
    DateTime? end,
    String? type,
    void Function(List<Transaction> firstPage)? onFirstPage,
    void Function(int loadedPages, int totalPages)? onPageProgress,
  });
  Future<TransactionPageResult> searchTransactionsPage(
    String query, {
    required int page,
    required int limit,
  });
  Future<TransactionPageResult> getTransactionsPage({
    required int page,
    required int limit,
    DateTime? start,
    DateTime? end,
  });
  Future<List<Transaction>> getAccountTransactions(
    String accountId, {
    DateTime? start,
    DateTime? end,
  });
  Future<TransactionPageResult> getBillTransactionsPage(
    String billId, {
    required int page,
    required int limit,
  });
  Future<TransactionPageResult> getRecurrenceTransactionsPage(
    String recurrenceId, {
    required int page,
    required int limit,
  });
  Future<TransactionPageResult> getAccountTransactionsPage(
    String accountId, {
    required int page,
    required int limit,
    DateTime? start,
    DateTime? end,
  });
  Future<List<Budget>> getBudgets({DateTime? start, DateTime? end});
  Future<List<Transaction>> getBudgetTransactions(
    String budgetId, {
    DateTime? start,
    DateTime? end,
  });
  Future<Transaction> getTransaction(String transactionId);
  Future<void> deleteBudget(String budgetId);
  Future<Budget> createBudget(BudgetInput input);
  Future<void> updateBudget(String budgetId, BudgetInput input);
  Future<List<BudgetLimit>> getBudgetLimits(
    String budgetId, {
    DateTime? start,
    DateTime? end,
  });
  Future<BudgetLimit> createBudgetLimit(
    String budgetId,
    BudgetLimitInput input,
  );
  Future<void> updateBudgetLimit(
    String budgetId,
    String limitId,
    BudgetLimitInput input,
  );
  Future<void> updateAccount(
    String accountId, {
    String? name,
    String? type,
    String? iban,
    String? bic,
    String? accountNumber,
    String? notes,
    bool? active,
    String? role,
    String? currencyCode,
    String? liabilityType,
    String? liabilityDirection,
    bool? includeNetWorth,
    double? openingBalance,
    DateTime? openingBalanceDate,
    double? virtualBalance,
    double? interest,
    String? interestPeriod,
  });
  Future<void> deleteAccount(String accountId);
  Future<Account> createAccount({
    required String name,
    required String type,
    required String currencyCode,
    String? role,
  });
  Future<Account> createLiability(LiabilityInput input);
  Future<List<Category>> getCategories();
  Future<Category> createCategory(String name, {String? notes});
  Future<Category> updateCategory(
    String categoryId,
    String name, {
    String? notes,
  });
  Future<void> deleteCategory(String categoryId);
  Future<List<Tag>> getTags();
  Future<Tag> createTag(String tag, {String? description});
  Future<Tag> updateTag(String tagId, String tag, {String? description});
  Future<void> deleteTag(String tagId);
  Future<List<Bill>> getBills();
  Future<List<FireflyCurrency>> getCurrencies();
  Future<Bill> createBill(BillInput input);
  Future<Bill> updateBill(String billId, BillInput input);
  Future<void> deleteBill(String billId);
  Future<List<Recurrence>> getRecurrences();
  Future<Recurrence> createRecurrence(RecurrenceInput input);

  /// [current] lets the implementation leave an unedited schedule off the
  /// request, which is what keeps Firefly from revalidating it.
  Future<Recurrence> updateRecurrence(
    String recurrenceId,
    RecurrenceInput input, {
    Recurrence? current,
  });
  Future<void> deleteRecurrence(String recurrenceId);
  Future<List<PiggyBank>> getPiggyBanks();
  Future<PiggyBank> createPiggyBank(PiggyBankInput input);
  Future<PiggyBank> updatePiggyBank(String piggyBankId, PiggyBankInput input);
  Future<void> deletePiggyBank(String piggyBankId);
  Future<Transaction> createTransaction(Transaction transaction);
  Future<Transaction> updateTransaction(Transaction transaction);
  Future<void> deleteTransaction(String transactionId);
  Future<dynamic> getPreference(String name);
  Future<void> setPreference(String name, dynamic data);

  /// One data set as Firefly's own CSV export writes it.
  ///
  /// [start] and [end] are inclusive days and only [FireflyCsvDataset
  /// .transactions] reads them; the rest come back whole either way.
  Future<String> exportCsv(
    FireflyCsvDataset dataset, {
    DateTime? start,
    DateTime? end,
  });
}
