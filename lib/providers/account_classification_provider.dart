import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireracoon_engine/models/account.dart';

import 'data_providers.dart';
import 'theme_provider.dart';

const String kAccountClassificationPreferenceKey =
    'fireracoon_account_classifications';

enum AccountCategory {
  asset,
  savings,
  creditCard,
  investment,
  liability;

  static AccountCategory? fromName(String? name) {
    if (name == null) return null;
    return AccountCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => AccountCategory.asset,
    );
  }
}

AccountCategory getCategoryForAccount(
  Account account,
  Map<String, AccountCategory> customMap,
) {
  final custom = customMap[account.id];
  if (custom != null) return custom;

  final roleLower = account.role.toLowerCase();
  final typeLower = account.type.toLowerCase();
  final liabilityTypeLower = account.liabilityType?.toLowerCase() ?? '';
  final nameLower = account.name.toLowerCase();

  if (roleLower == 'ccasset' ||
      roleLower == 'cc_asset' ||
      liabilityTypeLower == 'creditcard' ||
      liabilityTypeLower == 'credit_card' ||
      nameLower.contains('credit card') ||
      nameLower.contains('creditcard')) {
    return AccountCategory.creditCard;
  }

  if (roleLower.contains('investment') ||
      typeLower == 'investment' ||
      nameLower.contains('investment') ||
      nameLower.contains('investing') ||
      nameLower.contains('brokerage') ||
      nameLower.contains('portfolio') ||
      nameLower.contains('stocks') ||
      nameLower.contains('crypto') ||
      nameLower.contains('trading')) {
    return AccountCategory.investment;
  }

  if (roleLower == 'savingasset' ||
      roleLower == 'saving_asset' ||
      roleLower == 'savings' ||
      roleLower == 'saving' ||
      nameLower.contains('savings') ||
      nameLower.contains('saving') ||
      nameLower.contains('epargne') ||
      nameLower.contains('spara')) {
    return AccountCategory.savings;
  }

  if (typeLower == 'liability') {
    return AccountCategory.liability;
  }

  return AccountCategory.asset;
}

class AccountClassificationNotifier
    extends Notifier<Map<String, AccountCategory>> {
  late SharedPreferences _prefs;

  @override
  Map<String, AccountCategory> build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    _loadLocal();
    _fetchRemote();
    return _readLocal();
  }

  Map<String, AccountCategory> _readLocal() {
    final raw = _prefs.getString(kAccountClassificationPreferenceKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final map = <String, AccountCategory>{};
      decoded.forEach((key, value) {
        final category = AccountCategory.fromName(value?.toString());
        if (category != null) {
          map[key] = category;
        }
      });
      return map;
    } catch (_) {
      return {};
    }
  }

  void _loadLocal() {
    state = _readLocal();
  }

  Future<void> _fetchRemote() async {
    try {
      final service = ref.read(apiServiceProvider);
      if (service == null) return;
      final remote = await service.getPreference(
        kAccountClassificationPreferenceKey,
      );
      if (remote != null) {
        final Map<String, dynamic> rawMap = remote is Map<String, dynamic>
            ? remote
            : jsonDecode(remote.toString()) as Map<String, dynamic>;
        final map = <String, AccountCategory>{};
        rawMap.forEach((key, value) {
          final category = AccountCategory.fromName(value?.toString());
          if (category != null) {
            map[key] = category;
          }
        });
        state = map;
        await _prefs.setString(
          kAccountClassificationPreferenceKey,
          jsonEncode({
            for (final entry in map.entries) entry.key: entry.value.name,
          }),
        );
      }
    } catch (_) {
      // Fallback to local cache if offline or error
    }
  }

  Future<void> _persist(Map<String, AccountCategory> newMap) async {
    state = newMap;
    final jsonMap = {
      for (final entry in newMap.entries) entry.key: entry.value.name,
    };
    await _prefs.setString(
      kAccountClassificationPreferenceKey,
      jsonEncode(jsonMap),
    );
    try {
      final service = ref.read(apiServiceProvider);
      if (service == null) return;
      await service.setPreference(kAccountClassificationPreferenceKey, jsonMap);
    } catch (_) {
      // Saved locally, remote sync will retry
    }
  }

  Future<void> setClassification(
    String accountId,
    AccountCategory? category,
  ) async {
    final updated = Map<String, AccountCategory>.from(state);
    if (category == null) {
      updated.remove(accountId);
    } else {
      updated[accountId] = category;
    }
    await _persist(updated);
  }

  Future<void> clearAll() async {
    await _persist({});
  }

  /// Overwrites all classifications (settings import).
  Future<void> replaceAll(Map<String, AccountCategory> map) async {
    await _persist(Map<String, AccountCategory>.from(map));
  }
}

final accountClassificationProvider =
    NotifierProvider<
      AccountClassificationNotifier,
      Map<String, AccountCategory>
    >(AccountClassificationNotifier.new);
