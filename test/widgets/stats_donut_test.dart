import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/widgets/stats_donut.dart';

import '../helpers/localized_test_app.dart';

DonutSlice _slice(String label, double value, [VoidCallback? onTap]) =>
    DonutSlice(
      label: label,
      value: value,
      color: Colors.red,
      inside: '$value',
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
}
