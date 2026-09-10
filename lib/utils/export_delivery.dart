import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'json_file_store.dart';

/// True where the person has a filesystem they browse themselves.
///
/// Desktop saves, phones share. A share sheet on macOS is
/// NSSharingServicePicker, which lists applications to send a file to and
/// carries no save-to-disk service, so an export asked which app should
/// receive it and never offered a folder. Windows and Linux have the same
/// shape of problem. A phone has no file manager to save into and a share
/// sheet is how a file leaves an app there, so those keep sharing.
///
/// Read from [defaultTargetPlatform] rather than dart:io, which the web build
/// cannot import.
bool get _savesToAFolder =>
    !kIsWeb &&
    defaultTargetPlatform != TargetPlatform.iOS &&
    defaultTargetPlatform != TargetPlatform.android;

/// Puts [contents] in the person's hands as a file called [fileName].
///
/// Returns where it went, or null when the person dismissed the save dialog.
Future<String?> deliverExportFile({
  required String fileName,
  required String contents,

  /// Both are for the share sheet on a phone, and unused on desktop, where
  /// the save dialog carries the name and nothing else.
  String? subject,
  String? text,
}) async {
  if (_savesToAFolder) {
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (location == null) return null;
    await jsonStoreWrite(location.path, contents);
    return location.path;
  }

  // The phone and web path, unchanged from what every export used to do.
  // Driving it in a test means mocking path_provider's channel and
  // share_plus's, after which the only thing left to assert is that share_plus
  // was called. The branch above it, which is the change, is covered.
  // coverage:ignore-start
  //
  // Written first so the share sheet has a real file behind it and the person
  // keeps a copy whether or not they pick a destination.
  final path = await jsonStoreDocumentsPath(fileName);
  await jsonStoreWrite(path, contents);
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: subject,
      files: [
        XFile.fromData(
          utf8.encode(contents),
          mimeType: 'application/json',
          name: fileName,
        ),
      ],
    ),
  );
  return path;
  // coverage:ignore-end
}
