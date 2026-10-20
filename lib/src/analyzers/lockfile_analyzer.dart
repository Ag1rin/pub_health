import '../models/dependency.dart';
import '../models/dependency_kind.dart';
import '../utils/file_utils.dart';
import '../utils/yaml_utils.dart';
import 'pubspec_analyzer.dart';

/// Result of parsing pubspec.lock.
class LockfileData {
  /// Creates lockfile data.
  const LockfileData({
    required this.packages,
    this.missing = false,
  });

  /// Package name → locked dependency details.
  final Map<String, LockedPackage> packages;

  /// Whether pubspec.lock was missing.
  final bool missing;
}

/// A single package entry from pubspec.lock.
class LockedPackage {
  /// Creates a locked package.
  const LockedPackage({
    required this.name,
    required this.version,
    required this.dependency,
    required this.source,
  });

  /// Package name.
  final String name;

  /// Locked version.
  final String version;

  /// Lockfile dependency classification (`direct main`, `direct dev`,
  /// `transitive`).
  final String dependency;

  /// Source (`hosted`, `sdk`, `git`, `path`).
  final String source;
}

/// Reads and interprets pubspec.lock.
class LockfileAnalyzer {
  /// Parses pubspec.lock under [projectPath].
  Future<LockfileData> analyze(String projectPath) async {
    final path = FileUtils.join(projectPath, 'pubspec.lock');
    final content = await FileUtils.readText(path);
    if (content == null) {
      return const LockfileData(packages: {}, missing: true);
    }
    return parse(content);
  }

  /// Parses [content] as a pubspec.lock document.
  LockfileData parse(String content) {
    final map = YamlUtils.parseMap(content);
    final packagesNode = YamlUtils.readMap(map, 'packages');
    if (packagesNode == null) {
      return const LockfileData(packages: {});
    }

    final packages = <String, LockedPackage>{};
    for (final entry in packagesNode.entries) {
      final name = entry.key.toString();
      final value = entry.value;
      if (value is! Map) continue;

      final version = value['version']?.toString() ?? '';
      final dependency = value['dependency']?.toString() ?? 'transitive';
      final source = value['source']?.toString() ?? 'hosted';

      packages[name] = LockedPackage(
        name: name,
        version: version,
        dependency: dependency,
        source: source,
      );
    }
    return LockfileData(packages: packages);
  }

  /// Merges pubspec declarations with lockfile versions into a flat list.
  List<Dependency> mergeWithPubspec(
    PubspecData pubspec,
    LockfileData lockfile,
  ) {
    final declared = <String, Dependency>{
      for (final d in pubspec.allDeclared) d.name: d,
    };

    final results = <Dependency>[];
    final seen = <String>{};

    for (final dep in pubspec.allDeclared) {
      final locked = lockfile.packages[dep.name];
      results.add(
        dep.copyWith(
          lockedVersion: locked?.version ?? dep.lockedVersion,
          source: locked?.source ?? dep.source,
          isSdk: dep.isSdk || locked?.source == 'sdk',
        ),
      );
      seen.add(dep.name);
    }

    for (final locked in lockfile.packages.values) {
      if (seen.contains(locked.name)) continue;
      final isSdk = locked.source == 'sdk' ||
          locked.name == 'flutter' ||
          locked.name == 'flutter_test' ||
          locked.name == 'sky_engine' ||
          locked.name == 'dart';

      // Prefer lockfile classification when available.
      final kind = _kindFromLockfile(locked.dependency) ??
          declared[locked.name]?.kind ??
          DependencyKind.transitive;

      results.add(
        Dependency(
          name: locked.name,
          kind: kind,
          lockedVersion: locked.version,
          source: locked.source,
          isSdk: isSdk,
        ),
      );
    }

    return results;
  }

  DependencyKind? _kindFromLockfile(String dependency) {
    switch (dependency) {
      case 'direct main':
        return DependencyKind.direct;
      case 'direct dev':
        return DependencyKind.dev;
      case 'transitive':
        return DependencyKind.transitive;
      default:
        return null;
    }
  }
}
