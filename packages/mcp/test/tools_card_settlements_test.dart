import 'package:fireraccoon_mcp/fireraccoon_mcp.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'helpers/firefly_mock.dart';

const _target = FireflyTarget(baseUrl: fireflyBaseUrl, bearer: fireflyToken);

McpTool _tool(String name, MockClient client) => buildTools(
  target: _target,
  httpClient: client,
).firstWhere((tool) => tool.name == name);

Map<String, Object?> _account(String id, String name, String role) => {
  'id': id,
  'type': 'accounts',
  'attributes': {
    'name': name,
    'type': 'asset',
    'account_role': role,
    'current_balance': '0.00',
    'currency_symbol': '€',
    'currency_code': 'EUR',
  },
};

Map<String, Object?> _leg({
  required String journalId,
  required String type,
  required String date,
  required String amount,
  required String source,
  required String sourceId,
  required String destination,
  required String destinationId,
  String description = 'Purchase',
  String? notes,
}) => {
  'transaction_journal_id': journalId,
  'type': type,
  'date': date,
  'amount': amount,
  'description': description,
  'source_id': sourceId,
  'source_name': source,
  'destination_id': destinationId,
  'destination_name': destination,
  'currency_code': 'EUR',
  'currency_symbol': '€',
  'notes': notes,
  'reconciled': false,
};

Map<String, Object?> _group(
  String id,
  List<Map<String, Object?>> legs, {
  String? title,
}) => {
  'id': id,
  'type': 'transactions',
  'attributes': {'group_title': title, 'transactions': legs},
};

Map<String, Object?> _purchase(
  String id,
  String date,
  String amount, {
  String description = 'Purchase',
}) => _group(id, [
  _leg(
    journalId: 'j$id',
    type: 'withdrawal',
    date: date,
    amount: amount,
    source: 'Credit Card',
    sourceId: '6',
    destination: 'Store',
    destinationId: '9',
    description: description,
  ),
]);

Map<String, Object?> _refund(String id, String date, String amount) =>
    _group(id, [
      _leg(
        journalId: 'j$id',
        type: 'deposit',
        date: date,
        amount: amount,
        source: 'Store',
        sourceId: '9',
        destination: 'Credit Card',
        destinationId: '6',
        description: 'Refund',
      ),
    ]);

Map<String, Object?> _payback(
  String id,
  String date,
  List<(String, String?)> legs, {
  String? title,
}) => _group(id, [
  for (final (index, leg) in legs.indexed)
    _leg(
      journalId: 'j$id$index',
      type: 'transfer',
      date: date,
      amount: leg.$1,
      source: 'Checking',
      sourceId: '5',
      destination: 'Credit Card',
      destinationId: '6',
      description: 'Payback',
      notes: leg.$2,
    ),
], title: title);

// A card as a ledger holds one: two months of purchases and a refund, one
// payback the app wrote with a link per leg, one written by hand with none.
final _rows = <Map<String, Object?>>[
  _purchase('p1', '2026-06-01', '40.00', description: 'Coffee'),
  _purchase('p2', '2026-06-10', '60.00', description: 'Books'),
  _refund('r1', '2026-06-12', '10.00'),
  _payback('a', '2026-06-15', [
    ('40.00', 'fireraccoon:linked_journal:p1'),
    // The spelling from before the rename, and a row from before the window.
    ('60.00', 'fireracoon:linked_journal:p2\nfireraccoon:linked_journal:p0'),
  ], title: 'Credit Card Payback'),
  _purchase('p3', '2026-06-20', '25.00'),
  _payback('b', '2026-06-30', [('35.00', null)]),
  _purchase('p4', '2026-07-05', '15.00'),
];

MockClient _client({List<Uri>? record}) => MockClient((request) async {
  record?.add(request.url);
  final path = request.url.path;
  if (path == '/api/v1/accounts/6') {
    return jsonHttpResponse({'data': _account('6', 'Credit Card', 'ccAsset')});
  }
  if (path == '/api/v1/accounts/5') {
    return jsonHttpResponse({
      'data': _account('5', 'Checking', 'defaultAsset'),
    });
  }
  if (path == '/api/v1/accounts/6/transactions') {
    return jsonHttpResponse(
      transactionsPageBody(items: _rows, total: _rows.length),
    );
  }
  if (path == '/api/v1/transactions/a') {
    return jsonHttpResponse(transactionEnvelope(_rows[3]));
  }
  if (path == '/api/v1/transactions/p1') {
    return jsonHttpResponse(transactionEnvelope(_rows[0]));
  }
  return http.Response('unexpected $path', 500);
});

List<String> _ids(Object? rows) => [
  for (final row in rows! as List) (row as Map)['transaction_id'] as String,
];

void main() {
  group('get_card_settlements', () {
    test('reads what each payback settles and what none does', () async {
      final result = await _tool(
        'get_card_settlements',
        _client(),
      ).run({'account_id': '6'});

      expect(result['ok'], isTrue);
      expect((result['account'] as Map)['name'], 'Credit Card');
      expect(result['window'], {'start': null, 'end': null});
      expect((result['last_payback'] as Map)['transaction_id'], 'b');

      final paybacks = result['paybacks'] as List;
      expect(_ids(paybacks), ['a', 'b']);
      final linked = paybacks.first as Map;
      expect(linked['linked'], isTrue);
      expect(linked['amount'], 100.0);
      expect(linked['description'], 'Credit Card Payback');
      expect(_ids(linked['settles']), ['p1', 'p2']);
      expect(
        ((linked['settles'] as List).first as Map)['description'],
        'Coffee',
      );
      expect(linked['settles_outside_window'], ['p0']);
      final handWritten = paybacks.last as Map;
      expect(handWritten['linked'], isFalse);
      expect(handWritten['settles'], isEmpty);

      // The refund and the later purchase that no payback links, oldest
      // first; the July purchase is after the last payback and not yet due.
      expect(_ids(result['unsettled']), ['r1', 'p3']);
      expect(((result['unsettled'] as List).first as Map)['type'], 'deposit');
      expect(result['counts'], {
        'paybacks': 2,
        'unlinked_paybacks': 1,
        'unsettled': 2,
      });
      expect(result.containsKey('unsettled_truncated'), isFalse);
    });

    test('bounds the unsettled rows and counts them whole', () async {
      final result = await _tool(
        'get_card_settlements',
        _client(),
      ).run({'account_id': '6', 'max_rows': 1});

      expect(_ids(result['unsettled']), ['r1']);
      expect(result['unsettled_truncated'], 1);
      expect((result['counts'] as Map)['unsettled'], 2);
    });

    test('passes the window through and reports it', () async {
      final urls = <Uri>[];
      final result = await _tool('get_card_settlements', _client(record: urls))
          .run({
            'account_id': '6',
            'start_date': '2026-06-01',
            'end_date': '2026-06-30',
          });

      expect(result['window'], {'start': '2026-06-01', 'end': '2026-06-30'});
      final read = urls.firstWhere(
        (url) => url.path == '/api/v1/accounts/6/transactions',
      );
      expect(read.queryParameters['start'], '2026-06-01');
      expect(read.queryParameters, contains('end'));
    });

    test('refuses an account that is not a card, and bad input', () async {
      final tool = _tool('get_card_settlements', _client());

      final checking = await tool.run({'account_id': '5'});
      expect(checking['code'], 'bad_input');
      expect(checking['error'], contains('ccAsset'));
      expect(checking['error'], contains('defaultAsset'));

      expect((await tool.run({}))['code'], 'bad_input');
      expect(
        (await tool.run({'account_id': '6', 'start_date': 'June'}))['code'],
        'bad_input',
      );
      expect(
        (await tool.run({
          'account_id': '6',
          'start_date': '2026-06-30',
          'end_date': '2026-06-01',
        }))['code'],
        'bad_input',
      );
    });
  });

  group('a payback read on its own', () {
    test('lists what it settles, and a purchase lists nothing', () async {
      final payback = await _tool(
        'get_transaction',
        _client(),
      ).run({'transaction_id': 'a'});
      final purchase = await _tool(
        'get_transaction',
        _client(),
      ).run({'transaction_id': 'p1'});

      expect((payback['transaction'] as Map)['settles'], ['p1', 'p2', 'p0']);
      expect((purchase['transaction'] as Map).containsKey('settles'), isFalse);
    });
  });
}
