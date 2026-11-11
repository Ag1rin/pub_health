import 'dart:io';

import '../models/dependency.dart';
import '../models/dependency_kind.dart';
import '../utils/file_utils.dart';

/// Package imports found in a project, split by where they occur.
class ImportUsage {
  /// Creates an import usage summary.
  const ImportUsage({
    this.production = const {},
    this.nonProduction = const {},
  });

  /// Packages imported or exported from shipped code (`lib/`, `bin/`).
  final Set<String> production;

  /// Packages imported only from non-shipped code (`test/`, …).
  final Set<String> nonProduction;

  /// Every imported package.
  Set<String> get all => {...production, ...nonProduction};
}

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

  /// Roots whose code ships to package consumers / end users.
  static const List<String> productionRoots = ['lib', 'bin'];

  /// Returns names of unused direct runtime dependencies.
  Future<Set<String>> findUnused({
    required String projectPath,
    required List<Dependency> dependencies,
    Set<String> allowList = defaultAllowList,
    List<String> roots = defaultRoots,
  }) async {
    if (_candidates(dependencies, allowList).isEmpty) return {};
    final imported = await _collectImportedPackages(projectPath, roots);
    return unusedFrom(
      ImportUsage(production: imported),
      dependencies,
      allowList: allowList,
    );
  }

  /// Derives unused direct dependencies from an already computed [usage].
  Set<String> unusedFrom(
    ImportUsage usage,
    List<Dependency> dependencies, {
    Set<String> allowList = defaultAllowList,
  }) {
    return _candidates(dependencies, allowList).difference(usage.all);
  }

  Set<String> _candidates(
    List<Dependency> dependencies,
    Set<String> allowList,
  ) {
    return dependencies
        .where((d) => d.kind == DependencyKind.direct)
        .where((d) => !d.isSdk)
        .where((d) => d.source == 'hosted')
        .where((d) => !allowList.contains(d.name))
        .map((d) => d.name)
        .toSet();
  }

  /// Collects imports, separating shipped code from everything else.
  Future<ImportUsage> collectUsage(
    String projectPath, {
    List<String> roots = defaultRoots,
  }) async {
    final production = await _collectImportedPackages(
      projectPath,
      roots.where(productionRoots.contains).toList(),
    );
    final everything = await _collectImportedPackages(projectPath, roots);
    return ImportUsage(
      production: production,
      nonProduction: everything.difference(production),
    );
  }

  Future<Set<String>> _collectImportedPackages(
    String projectPath,
    List<String> roots,
  ) async {
    final imported = <String>{};
    if (roots.isEmpty) return imported;
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
