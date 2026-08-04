import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ViewMode { standard, compact, tight }

class ViewModeNotifier extends Notifier<ViewMode> {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'globalViewMode';

  @override
  ViewMode build() {
    _load();
    return ViewMode.standard;
  }

  Future<void> _load() async {
    final stored = await _storage.read(key: _storageKey);
    if (stored == 'compact') {
      state = ViewMode.compact;
    } else if (stored == 'tight') {
      state = ViewMode.tight;
    } else {
      state = ViewMode.standard;
    }
  }

  Future<void> setMode(ViewMode mode) async {
    if (state == mode) return;
    state = mode;
    await _storage.write(key: _storageKey, value: state.name);
  }

  void toggle() {
    final next = switch (state) {
      ViewMode.standard => ViewMode.compact,
      ViewMode.compact => ViewMode.tight,
      ViewMode.tight => ViewMode.standard,
    };
    setMode(next);
  }
}

final viewModeProvider = NotifierProvider<ViewModeNotifier, ViewMode>(
  ViewModeNotifier.new,
);
