import 'dart:io';

import 'package:path/path.dart' as p;

/// File-system helpers used by analyzers.
class FileUtils {
  /// Returns true if [path] exists as a file.
  static bool fileExists(String path) => File(path).existsSync();

  /// Returns true if [path] exists as a directory.
  static bool directoryExists(String path) => Directory(path).existsSync();

  /// Reads a UTF-8 text file, or null if missing.
  static Future<String?> readText(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  /// Reads a UTF-8 text file synchronously, or null if missing.
  static String? readTextSync(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  }

  /// Joins [projectPath] with [relative].
  static String join(String projectPath, String relative) =>
      p.join(projectPath, relative);

  /// Absolute path for [path].
  static String absolute(String path) => p.absolute(path);

  /// Lists all Dart source files under [roots] (relative to [projectPath]).
  static List<File> listDartFiles(String projectPath, List<String> roots) {
    final files = <File>[];
    for (final root in roots) {
      final dir = Directory(p.join(projectPath, root));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          files.add(entity);
        }
      }
    }
    return files;
  }

  /// Writes [content] to [path], creating parent directories as needed.
  static Future<void> writeText(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }
}
