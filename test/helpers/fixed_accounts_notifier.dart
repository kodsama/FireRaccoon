import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

/// Test double for [AccountsNotifier] serving a fixed account list.
class FixedAccountsNotifier extends AccountsNotifier {
  FixedAccountsNotifier(this._accounts);

  final List<Account> _accounts;

  @override
  Future<List<Account>> build() async => _accounts;
}
