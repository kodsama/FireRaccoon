import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backup_service.dart';

/// Backups kept by a FireRaccoon server rather than on the machine reading them.
///
/// Server mode seals its DATA_DIR, so the app and the standalone MCP binary both
/// reach the same backups over HTTP instead of each keeping a copy of their own.
/// The credential comes from the caller: a session for the app, an agent key for
/// an MCP client. The server is the authority on what either may do.
class RemoteBackupStore implements BackupStore {
  RemoteBackupStore({
    required String baseUrl,
    required this.headers,
    http.Client? client,
  }) : baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _client = client ?? http.Client();

  final String baseUrl;
  final Map<String, String> headers;
  final http.Client _client;

  Uri _backupUri(String backupId) =>
      Uri.parse('$baseUrl/api/backups/${Uri.encodeComponent(backupId)}');

  Uri _fileUri(String backupId, String fileName) => Uri.parse(
    '${_backupUri(backupId)}/files/'
    '${fileName.split('/').map(Uri.encodeComponent).join('/')}',
  );

  @override
  Future<void> put(String backupId, String fileName, List<int> bytes) async {
    final response = await _client.put(
      _fileUri(backupId, fileName),
      headers: {...headers, 'content-type': 'application/octet-stream'},
      body: bytes,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError(
        'Failed to store $backupId/$fileName: HTTP ${response.statusCode}',
      );
    }
  }

  @override
  Future<List<int>?> get(String backupId, String fileName) async {
    final response = await _client.get(
      _fileUri(backupId, fileName),
      headers: headers,
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw StateError(
        'Failed to read $backupId/$fileName: HTTP ${response.statusCode}',
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<List<String>> listBackupIds() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/backups'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw StateError('Failed to list backups: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) return const [];
    return [for (final id in (decoded['backups'] as List? ?? const [])) '$id'];
  }

  @override
  Future<void> deleteBackup(String backupId) async {
    final response = await _client.delete(
      _backupUri(backupId),
      headers: headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw StateError(
        'Failed to delete $backupId: HTTP ${response.statusCode}',
      );
    }
  }
}
