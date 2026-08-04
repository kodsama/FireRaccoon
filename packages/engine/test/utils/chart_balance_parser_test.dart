import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:test/test.dart';

void main() {
  group('parseChartBalanceHistories', () {
    test('parses datasets from top-level list', () {
      final histories = parseChartBalanceHistories([
        {
          'label': 'Checking',
          'entries': {'2026-01-01': '100.50', '2026-02-01': '200'},
        },
      ]);

      expect(histories['Checking'], [100.5, 200]);
    });

    test('parses datasets from data envelope', () {
      final histories = parseChartBalanceHistories({
        'data': [
          {
            'label': 'Savings',
            'entries': {'2026-03-15': '10', '2026-03-01': '5'},
          },
        ],
      });

      expect(histories['Savings'], [5, 10]);
    });

    test('skips invalid datasets and returns empty map for unknown shape', () {
      expect(parseChartBalanceHistories(null), isEmpty);
      expect(parseChartBalanceHistories({'data': 'nope'}), isEmpty);
      expect(
        parseChartBalanceHistories([
          {
            'label': '',
            'entries': {'2026-01-01': '1'},
          },
          {'label': 'No entries'},
        ]),
        isEmpty,
      );
    });
  });
}
