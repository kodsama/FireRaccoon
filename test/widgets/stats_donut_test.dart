import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/widgets/stats_donut.dart';

import '../helpers/localized_test_app.dart';

DonutSlice _slice(String label, double value, [VoidCallback? onTap]) =>
    DonutSlice(
      label: label,
      value: value,
      color: Colors.red,
      amount: '$value',
      onTap: onTap,
    );

void main() {
  group('DonutGeometry', () {
    final geometry = DonutGeometry(const Size(800, 400), hasInner: true);
    final outer = [_slice('a', 1), _slice('b', 3)];
    final inner = [_slice('whole', 4)];

    Offset at(double radius, double clockwiseFromTop) =>
        geometry.center +
        Offset(math.sin(clockwiseFromTop), -math.cos(clockwiseFromTop)) *
            radius;

    test('slices run clockwise from twelve o\'clock by their share', () {
      final arcs = DonutGeometry.arcs(outer);
      expect(arcs.first.$1, closeTo(-math.pi / 2, 1e-9));
      expect(arcs.first.$2, closeTo(math.pi / 2, 1e-9));
      expect(arcs.last.$2, closeTo(3 * math.pi / 2, 1e-9));
      expect(DonutGeometry.arcs(const []), isEmpty);
    });

    test('wide slices end round, over the start of the next', () {
      const ring = (58.0, 100.0);
      final cap = DonutGeometry.capAngle(ring);
      final total = 2 * math.pi / cap;
      // In caps: three wide, then two slivers, then one wide again.
      final values = [total - 7.4, 3.0, 2.0, 0.2, 0.2, 2.0];
      final arcs = DonutGeometry.arcs([
        for (final value in values) _slice('', value),
      ]);
      expect(DonutGeometry.roundEnds(arcs, ring), [
        true,
        true,
        // The last wide one before the slivers stays flat so its end does
        // not cover them.
        false,
        false,
        false,
        // It wraps round onto the first, which is wide.
        true,
      ]);
    });

    test('a whole ring has no ends to round', () {
      final arcs = DonutGeometry.arcs([_slice('', 1)]);
      expect(DonutGeometry.roundEnds(arcs, (58.0, 100.0)), [false]);
    });

    test('finds the ring and the slice under a point', () {
      final (outerFrom, outerTo) = geometry.outerRing;
      final (innerFrom, innerTo) = geometry.innerRing;
      final outerMid = (outerFrom + outerTo) / 2;
      final innerMid = (innerFrom + innerTo) / 2;

      expect(geometry.hit(at(outerMid, 0.4), outer: outer, inner: inner), (
        false,
        0,
      ));
      expect(geometry.hit(at(outerMid, math.pi), outer: outer, inner: inner), (
        false,
        1,
      ));
      expect(geometry.hit(at(innerMid, 2), outer: outer, inner: inner), (
        true,
        0,
      ));
      // The hole in the middle and the space around hold no slice.
      expect(geometry.hit(geometry.center, outer: outer, inner: inner), isNull);
      expect(
        geometry.hit(at(outerTo + 40, 1), outer: outer, inner: inner),
        isNull,
      );
    });
  });

  testWidgets('a tap on a slice runs its action', (tester) async {
    var tapped = '';
    await tester.pumpWidget(
      buildLocalizedTestApp(
        child: SizedBox(
          width: 800,
          child: StatsDonut(
            formatPercent: (p) => '${p.toStringAsFixed(1)}%',
            outer: [
              _slice('Food', 1, () => tapped = 'Food'),
              _slice('Rent', 3, () => tapped = 'Rent'),
            ],
            height: 400,
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(StatsDonut));
    final geometry = DonutGeometry(box.size, hasInner: false);
    final (from, to) = geometry.outerRing;
    // A little past three o'clock sits in Rent, the larger slice.
    await tester.tapAt(
      box.topLeft + geometry.center + Offset((from + to) / 2, 10),
    );
    expect(tapped, 'Rent');
  });

  testWidgets('hovering a slice names it in full with its share and amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildLocalizedTestApp(
        child: SizedBox(
          width: 800,
          child: StatsDonut(
            formatPercent: (p) => '${p.toStringAsFixed(1)}%',
            outer: [
              _slice('Holiday > Souvenirs and small gifts', 1),
              _slice('Rent', 3),
            ],
            height: 400,
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(StatsDonut));
    final geometry = DonutGeometry(box.size, hasInner: false);
    final (from, to) = geometry.outerRing;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);

    // Just right of twelve o'clock is the first, smaller slice.
    await mouse.moveTo(
      box.topLeft + geometry.center + Offset(10, -(from + to) / 2),
    );
    await tester.pump();
    expect(find.text('Holiday > Souvenirs and small gifts'), findsOneWidget);
    expect(find.text('25.0% · 1.0'), findsOneWidget);

    await mouse.moveTo(box.topLeft + geometry.center);
    await tester.pump();
    expect(find.textContaining('25.0%'), findsNothing);
  });
}
