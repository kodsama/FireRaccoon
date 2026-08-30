import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import 'theme_provider.dart';

const kDefaultTransactionPageSize = 50;
const kMinTransactionPageSize = 10;
const kMaxTransactionPageSize = 500;
const kTransactionPageSizeStep = 10;

const kTransactionPageSizeSteps =
    (kMaxTransactionPageSize - kMinTransactionPageSize) ~/
    kTransactionPageSizeStep;

int normalizeTransactionPageSize(int value) {
  final clamped = value.clamp(kMinTransactionPageSize, kMaxTransactionPageSize);
  final stepIndex =
      ((clamped - kMinTransactionPageSize) / kTransactionPageSizeStep).round();
  return kMinTransactionPageSize + stepIndex * kTransactionPageSizeStep;
}

int transactionPageSizeSliderIndex(int pageSize) {
  return (normalizeTransactionPageSize(pageSize) - kMinTransactionPageSize) ~/
      kTransactionPageSizeStep;
}

int transactionPageSizeFromSliderIndex(int index) {
  final clampedIndex = index.clamp(0, kTransactionPageSizeSteps);
  return kMinTransactionPageSize + clampedIndex * kTransactionPageSizeStep;
}

class TransactionPageSizeNotifier extends Notifier<int> {
  static const _prefsKey = 'transactionPageSize';
  static final _log = AppLogger.scoped('providers.transaction_page_size');

  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final value = normalizeTransactionPageSize(
      prefs.getInt(_prefsKey) ?? kDefaultTransactionPageSize,
    );
    _log.finer('Loaded transaction page size preference: $value');
    return value;
  }

  Future<void> setPageSize(int value) async {
    final normalized = normalizeTransactionPageSize(value);
    if (normalized == state) return;
    state = normalized;
    await ref.read(sharedPreferencesProvider).setInt(_prefsKey, normalized);
    _log.info('Updated transaction page size preference to $normalized');
  }

  Future<void> setPageSizeFromSliderIndex(int index) {
    return setPageSize(transactionPageSizeFromSliderIndex(index));
  }
}

final transactionPageSizeProvider =
    NotifierProvider<TransactionPageSizeNotifier, int>(
      TransactionPageSizeNotifier.new,
    );
