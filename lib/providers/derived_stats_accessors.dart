import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import 'data_providers.dart';

List<Account> watchCachedAccounts(Ref ref) {
  return ref.watch(accountsProvider).asData?.value ?? const [];
}

List<Transaction> watchCachedTransactions(Ref ref) {
  return ref.watch(transactionsProvider).asData?.value ?? const [];
}
