import 'dart:io';

import 'package:path/path.dart' as p;

/// Creates a throw-away Dart project on disk for a test.
Future<Directory> createTempProject({
  required String pubspec,
  String? lock,
  Map<String, String> files = const {},
  Directory? parent,
  String? subdir,
}) async {
  final base = parent ?? await Directory.systemTemp.createTemp('pub_health_');
  final dir = subdir == null ? base : Directory(p.join(base.path, subdir));
  await dir.create(recursive: true);
  await File(p.join(dir.path, 'pubspec.yaml')).writeAsString(pubspec);
  if (lock != null) {
    await File(p.join(dir.path, 'pubspec.lock')).writeAsString(lock);
  }
  for (final entry in files.entries) {
    final file = File(p.join(dir.path, entry.key));
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
  }
  return dir;
}

/// Minimal hosted entry for a hand-written pubspec.lock.
String lockEntry(
  String name,
  String version, {
  String dependency = 'direct main',
}) =>
    '''
  $name:
    dependency: "$dependency"
    description:
      name: $name
      sha256: "0000000000000000000000000000000000000000000000000000000000000000"
      url: "https://pub.dev"
    source: hosted
    version: "$version"
''';

/// Wraps lock entries into a pubspec.lock document.
String lockFile(List<String> entries) => 'packages:\n${entries.join()}';
