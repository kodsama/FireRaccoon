import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/providers/stats_layout_provider.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> container(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('opens separated and in detail the first time', () async {
    final c = await container({});
    final layout = c.read(statsLayoutProvider);
    expect(layout.merged, isFalse);
    expect(layout.level, StatsLevel.groups);
  });

  test('keeps the last choice for the next run', () async {
    final c = await container({});
    c.read(statsLayoutProvider.notifier)
      ..setMerged(true)
      ..setLevel(StatsLevel.types);
    final prefs = c.read(sharedPreferencesProvider);
    final next = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(next.dispose);
    final layout = next.read(statsLayoutProvider);
    expect(layout.merged, isTrue);
    expect(layout.level, StatsLevel.types);
  });

  test('an unknown saved level falls back to in detail', () async {
    final c = await container({'statsLevel': 'nonsense'});
    expect(c.read(statsLayoutProvider).level, StatsLevel.groups);
  });
}
