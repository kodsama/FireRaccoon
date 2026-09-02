// coverage:ignore-file — platform channel / conditional import shim
import 'package:path_provider/path_provider.dart';

Future<String?> resolveBackupsDirectory() async {
  final dir = await getApplicationSupportDirectory();
  return '${dir.path}/backups';
}
