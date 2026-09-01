import '../models/firefly_csv_dataset.dart';
import 'firefly_service.dart';

/// One data set as Firefly exported it, or the reason it is missing.
class FireflyCsvFile {
  const FireflyCsvFile.written(this.dataset, this.contents)
    : error = null,
      chunks = 1;

  const FireflyCsvFile.chunked(this.dataset, this.contents, this.chunks)
    : error = null;

  const FireflyCsvFile.failed(this.dataset, this.error)
    : contents = '',
      chunks = 0;

  final FireflyCsvDataset dataset;
  final String contents;

  /// Requests the data set took, above one when the window was split.
  final int chunks;

  /// Why this data set is missing, null when it is not.
  final String? error;

  bool get ok => error == null;

  /// Rows below the header, which is what tells an empty export from a full one.
  ///
  /// Counted quote-aware rather than by splitting on newlines: Firefly quotes a
  /// description that carries one instead of escaping it, and counting lines
  /// reports such a row twice.
  int get rowCount {
    if (!ok || contents.isEmpty) return 0;
    var rows = 0;
    var inQuotes = false;
    var pending = false;
    for (var i = 0; i < contents.length; i++) {
      final char = contents[i];
      if (char == '"') {
        // A doubled quote inside a quoted field stands for one quote.
        if (inQuotes && i + 1 < contents.length && contents[i + 1] == '"') {
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        pending = true;
      } else if (char == '\n' && !inQuotes) {
        if (pending) rows++;
        pending = false;
      } else if (char != '\r') {
        pending = true;
      }
    }
    if (pending) rows++;
    return rows == 0 ? 0 : rows - 1;
  }
}

/// Reads Firefly's own CSV exports, which are the archival half of a backup.
///
/// A whole ledger asked for in one request is how the export times out: 6.6.6
/// answered a fifteen-year window with 6.7MB and a thirty-year one with a
/// gateway error, so transactions are read a year at a time and stitched back
/// together. Every other data set ignores the window and is read whole.
class FireflyCsvExportService {
  const FireflyCsvExportService(this._api);

  final FireflyService _api;

  /// Reads every data set, transactions over [from]..[to].
  ///
  /// [onChunk] fires once per request, which is what a caller counts to show a
  /// year-at-a-time walk moving.
  ///
  /// A data set that fails is reported rather than thrown: an export that loses
  /// its rules is still worth keeping, and the manifest is where that shows up.
  /// Reads run one after another for the same reason the snapshot does, so a
  /// backup never turns into a burst against someone's live instance.
  Future<List<FireflyCsvFile>> exportAll({
    required DateTime from,
    required DateTime to,
    void Function(FireflyCsvDataset dataset)? onDataset,
    void Function()? onChunk,
  }) async {
    final files = <FireflyCsvFile>[];
    for (final dataset in FireflyCsvDataset.values) {
      onDataset?.call(dataset);
      try {
        if (dataset.isWindowed) {
          files.add(
            await _exportWindowed(
              dataset,
              from: from,
              to: to,
              onChunk: onChunk,
            ),
          );
        } else {
          files.add(
            FireflyCsvFile.written(dataset, await _api.exportCsv(dataset)),
          );
          onChunk?.call();
        }
      } on Object catch (error) {
        files.add(FireflyCsvFile.failed(dataset, '$error'));
      }
    }
    return files;
  }

  Future<FireflyCsvFile> _exportWindowed(
    FireflyCsvDataset dataset, {
    required DateTime from,
    required DateTime to,
    void Function()? onChunk,
  }) async {
    final buffer = StringBuffer();
    var chunks = 0;
    for (var year = from.year; year <= to.year; year++) {
      final start = year == from.year ? from : DateTime(year);
      final end = year == to.year ? to : DateTime(year, 12, 31);
      final chunk = await _api.exportCsv(dataset, start: start, end: end);
      chunks++;
      onChunk?.call();
      final body = chunks == 1 ? chunk : _withoutHeader(chunk);
      if (body.trim().isEmpty) continue;
      if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
        buffer.write('\n');
      }
      buffer.write(body);
    }
    return FireflyCsvFile.chunked(dataset, buffer.toString(), chunks);
  }

  /// Drops the header line only.
  ///
  /// Split by the first newline rather than by lines: a description carrying a
  /// newline is quoted, not escaped, so any line-wise pass over the body loses
  /// track of where a row ends. The header never wraps.
  String _withoutHeader(String csv) {
    final breakAt = csv.indexOf('\n');
    return breakAt < 0 ? '' : csv.substring(breakAt + 1);
  }
}
