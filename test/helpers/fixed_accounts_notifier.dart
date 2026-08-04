import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

/// Test double for [AccountsNotifier] serving a fixed account list.
class FixedAccountsNotifier extends AccountsNotifier {
  FixedAccountsNotifier(this._accounts);

  final List<Account> _accounts;

  @override
  Future<List<Account>> build() async => _accounts;
}
