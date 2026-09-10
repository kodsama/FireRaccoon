import 'dart:io';

// The save-dialog seam lives in file_selector's platform interface, which
// comes in transitively with file_selector itself.
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:fireraccoon/utils/export_delivery.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the OS save dialog, which blocks on a native window.
class _FakeSaveDialog extends FileSelectorPlatform {
  _FakeSaveDialog(this._directory);

  /// Null stands for the person dismissing the dialog.
  final String? _directory;
  final suggested = <String?>[];

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    suggested.add(options.suggestedName);
    if (_directory == null) return null;
    return FileSaveLocation('$_directory/${options.suggestedName}');
  }
}

void main() {
  late FileSelectorPlatform original;
  late Directory temp;

  setUp(() {
    original = FileSelectorPlatform.instance;
    temp = Directory.systemTemp.createTempSync('fireraccoon_export_test');
    // The share sheet on macOS is NSSharingServicePicker: it lists apps to
    // send a file to and has no save-to-disk service, so an export asked for
    // an application and never offered a folder. Windows and Linux the same.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  });

  tearDown(() {
    FileSelectorPlatform.instance = original;
    debugDefaultTargetPlatformOverride = null;
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('a desktop export is written where the person chose', () async {
    final dialog = _FakeSaveDialog(temp.path);
    FileSelectorPlatform.instance = dialog;

    final path = await deliverExportFile(
      fileName: 'fireraccoon_settings_20260910.json',
      contents: '{"hello":"world"}',
    );

    expect(path, '${temp.path}/fireraccoon_settings_20260910.json');
    expect(File(path!).readAsStringSync(), '{"hello":"world"}');
    // The name is offered, so the dialog opens on something sensible.
    expect(dialog.suggested, ['fireraccoon_settings_20260910.json']);
  });

  test('dismissing the dialog writes nothing and says so', () async {
    FileSelectorPlatform.instance = _FakeSaveDialog(null);

    final path = await deliverExportFile(
      fileName: 'fireraccoon_settings_20260910.json',
      contents: '{"hello":"world"}',
    );

    // Null rather than a path, so a caller does not report an export that
    // never happened.
    expect(path, isNull);
    expect(temp.listSync(), isEmpty);
  });
}
