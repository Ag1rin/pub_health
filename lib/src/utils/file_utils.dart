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

  /// Parent directory of [path].
  static String parent(String path) => p.dirname(path);

  /// [path] relative to [from], using forward slashes.
  static String relative(String path, {required String from}) =>
      p.relative(path, from: from).replaceAll('\\', '/');

  /// Absolute, normalized path for [path] (`.` becomes the working directory
  /// itself, not `<cwd>/.`).
  static String absolute(String path) => p.normalize(p.absolute(path));

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

  /// Directory names never descended into when discovering projects.
  static const Set<String> _skippedDirs = {
    'build',
    'node_modules',
    'ephemeral',
    '.symlinks',
    '.plugin_symlinks',
    '.pub-cache',
  };

  /// Finds every directory under [root] that contains a `pubspec.yaml`.
  ///
  /// Hidden directories (`.git`, `.dart_tool`, …) and build output are
  /// skipped. [excludePrefixes] are paths relative to [root] (forward
  /// slashes) whose subtrees are ignored. Results are sorted.
  static List<String> findProjects(
    String root, {
    Set<String> excludePrefixes = const {},
  }) {
    final found = <String>[];
    void walk(Directory dir) {
      final rel = relative(dir.path, from: root);
      final normalized = rel == '.' ? '' : rel;
      if (excludePrefixes.any(
        (e) => normalized == e || normalized.startsWith('$e/'),
      )) {
        return;
      }
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        found.add(dir.path);
      }
      List<FileSystemEntity> children;
      try {
        children = dir.listSync(followLinks: false);
      } on FileSystemException {
        return;
      }
      for (final child in children) {
        if (child is! Directory) continue;
        final name = p.basename(child.path);
        if (name.startsWith('.') || _skippedDirs.contains(name)) continue;
        walk(child);
      }
    }

    walk(Directory(root));
    found.sort();
    return found;
  }

  /// Writes [content] to [path], creating parent directories as needed.
  static Future<void> writeText(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }
}
