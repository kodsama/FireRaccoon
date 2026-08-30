import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/widgets/fun_decorated_surface.dart';

void main() {
  testWidgets('shows only child when no fun mode is active', (tester) async {
    SharedPreferences.setMockInitialValues({'funMode': 'none'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: FunDecoratedSurface(
            decorationKey: 'test',
            child: Text('hello'),
          ),
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
    expect(find.byType(Stack), findsNothing);
  });

  testWidgets('wraps child in stack when Raccoon Mode is on', (tester) async {
    SharedPreferences.setMockInitialValues({'funMode': 'raccoon'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: FunDecoratedSurface(
            decorationKey: 'test',
            child: Text('hello'),
          ),
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
    expect(find.byType(Stack), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('legacy isRaccoonMode pref still enables stickers', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'isRaccoonMode': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: FunDecoratedSurface(
            decorationKey: 'test',
            child: Text('hello'),
          ),
        ),
      ),
    );

    expect(find.byType(Stack), findsOneWidget);
  });
}
