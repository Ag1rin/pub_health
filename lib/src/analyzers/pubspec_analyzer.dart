import '../models/dependency.dart';
import '../models/dependency_kind.dart';
import '../utils/file_utils.dart';
import '../utils/yaml_utils.dart';

/// Result of parsing a project's pubspec.yaml.
class PubspecData {
  /// Creates parsed pubspec data.
  const PubspecData({
    required this.name,
    required this.sdkConstraint,
    required this.directDependencies,
    required this.devDependencies,
  });

  /// Package name from pubspec.
  final String name;

  /// Dart SDK constraint from `environment.sdk`.
  final String? sdkConstraint;

  /// Runtime dependencies.
  final List<Dependency> directDependencies;

  /// Dev dependencies.
  final List<Dependency> devDependencies;

  /// All declared dependencies (direct + dev).
  List<Dependency> get allDeclared => [
        ...directDependencies,
        ...devDependencies,
      ];
}

/// Reads and interprets pubspec.yaml.
class PubspecAnalyzer {
  /// Parses pubspec.yaml under [projectPath].
  Future<PubspecData> analyze(String projectPath) async {
    final path = FileUtils.join(projectPath, 'pubspec.yaml');
    final content = await FileUtils.readText(path);
    if (content == null) {
      throw PubspecAnalysisException(
        'Missing pubspec.yaml at $path',
      );
    }
    return parse(content);
  }

  /// Parses [content] as a pubspec.yaml document.
  PubspecData parse(String content) {
    final map = YamlUtils.parseMap(content);
    final name = YamlUtils.readString(map, 'name') ?? 'unknown';
    final environment = YamlUtils.readMap(map, 'environment');
    final sdkConstraint =
        environment == null ? null : YamlUtils.readString(environment, 'sdk');

    final direct = _parseDependencySection(
      YamlUtils.readMap(map, 'dependencies'),
      DependencyKind.direct,
    );
    final dev = _parseDependencySection(
      YamlUtils.readMap(map, 'dev_dependencies'),
      DependencyKind.dev,
    );

    return PubspecData(
      name: name,
      sdkConstraint: sdkConstraint,
      directDependencies: direct,
      devDependencies: dev,
    );
  }

  List<Dependency> _parseDependencySection(
    dynamic section,
    DependencyKind kind,
  ) {
    if (section == null) return const [];
    if (section is! Map) return const [];

    final results = <Dependency>[];
    for (final entry in section.entries) {
      final name = entry.key.toString();
      if (name == 'flutter' || name == 'dart' || name == 'flutter_test') {
        results.add(
          Dependency(
            name: name,
            kind: kind,
            constraint: _constraintOf(entry.value),
            isSdk: true,
            source: 'sdk',
          ),
        );
        continue;
      }

      final value = entry.value;
      var constraint = _constraintOf(value);
      var source = 'hosted';
      var isSdk = false;

      if (value is Map) {
        if (value.containsKey('sdk')) {
          source = 'sdk';
          isSdk = true;
          constraint = value['sdk']?.toString();
        } else if (value.containsKey('path')) {
          source = 'path';
        } else if (value.containsKey('git')) {
          source = 'git';
        } else if (value.containsKey('version')) {
          constraint = value['version']?.toString();
        }
      }

      results.add(
        Dependency(
          name: name,
          kind: kind,
          constraint: constraint,
          source: source,
          isSdk: isSdk,
        ),
      );
    }
    return results;
  }

  String? _constraintOf(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num) return value.toString();
    return null;
  }
}

/// Thrown when pubspec.yaml cannot be analyzed.
class PubspecAnalysisException implements Exception {
  /// Creates an exception.
  PubspecAnalysisException(this.message);

  /// Error message.
  final String message;

  @override
  String toString() => 'PubspecAnalysisException: $message';
}
