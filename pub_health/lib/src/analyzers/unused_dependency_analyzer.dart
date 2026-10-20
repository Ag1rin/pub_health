import 'dart:io';

import '../models/dependency.dart';
import '../models/dependency_kind.dart';
import '../utils/file_utils.dart';

/// Detects direct runtime dependencies that appear unused based on imports.
class UnusedDependencyAnalyzer {
  /// Package names that are commonly used without a matching import.
  static const Set<String> defaultAllowList = {
    'build_runner',
    'flutter_lints',
    'lints',
    'analyzer',
    'test',
    'flutter_test',
    'integration_test',
    'mocktail',
    'mockito',
    'build',
    'build_config',
    'build_resolvers',
    'build_web_compilers',
    'source_gen',
    'json_serializable',
    'freezed',
    'freezed_annotation',
    'riverpod_generator',
    'go_router_builder',
    'flutter_gen',
    'flutter_gen_runner',
    'intl_utils',
    'pigeon',
    'msix',
    'flutter_launcher_icons',
    'flutter_native_splash',
    'very_good_analysis',
    'pedantic',
    'meta',
    'collection',
    'cupertino_icons',
  };

  /// Roots scanned for Dart imports.
  static const List<String> defaultRoots = ['lib', 'bin', 'test'];

  /// Returns names of unused direct runtime dependencies.
  Future<Set<String>> findUnused({
    required String projectPath,
    required List<Dependency> dependencies,
    Set<String> allowList = defaultAllowList,
    List<String> roots = defaultRoots,
  }) async {
    final candidates = dependencies
        .where((d) => d.kind == DependencyKind.direct)
        .where((d) => !d.isSdk)
        .where((d) => d.source == 'hosted')
        .where((d) => !allowList.contains(d.name))
        .map((d) => d.name)
        .toSet();

    if (candidates.isEmpty) return {};

    final imported = await _collectImportedPackages(projectPath, roots);
    return candidates.difference(imported);
  }

  Future<Set<String>> _collectImportedPackages(
    String projectPath,
    List<String> roots,
  ) async {
    final imported = <String>{};
    final files = FileUtils.listDartFiles(projectPath, roots);
    final importPattern = RegExp(
      r'''^\s*import\s+['"]package:([^/'"]+)/''',
      multiLine: true,
    );
    final exportPattern = RegExp(
      r'''^\s*export\s+['"]package:([^/'"]+)/''',
      multiLine: true,
    );

    for (final file in files) {
      String content;
      try {
        content = await file.readAsString();
      } on FileSystemException {
        continue;
      }
      for (final match in importPattern.allMatches(content)) {
        imported.add(match.group(1)!);
      }
      for (final match in exportPattern.allMatches(content)) {
        imported.add(match.group(1)!);
      }
    }
    return imported;
  }
}
