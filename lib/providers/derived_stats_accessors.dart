import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import 'data_providers.dart';

List<Account> watchCachedAccounts(Ref ref) {
  return ref.watch(accountsProvider).asData?.value ?? const [];
}

List<Transaction> watchCachedTransactions(Ref ref) {
  return ref.watch(transactionsProvider).asData?.value ?? const [];
}
