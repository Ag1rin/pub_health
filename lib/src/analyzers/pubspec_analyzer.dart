import 'package:yaml/yaml.dart';

import '../models/dependency.dart';
import '../models/dependency_kind.dart';
import '../models/dependency_override.dart';
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
    this.overrides = const [],
    this.isFlutter = false,
    this.workspaceMembers = const [],
    this.resolvesWithWorkspace = false,
  });

  /// Package name from pubspec.
  final String name;

  /// Dart SDK constraint from `environment.sdk`.
  final String? sdkConstraint;

  /// Runtime dependencies.
  final List<Dependency> directDependencies;

  /// Dev dependencies.
  final List<Dependency> devDependencies;

  /// Entries of `dependency_overrides:`.
  final List<DependencyOverride> overrides;

  /// Whether the project depends on the Flutter SDK.
  final bool isFlutter;

  /// Members listed under `workspace:` (Dart 3.6+ pub workspaces).
  final List<String> workspaceMembers;

  /// Whether the project declares `resolution: workspace`.
  final bool resolvesWithWorkspace;

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
    final overrides = _parseOverrides(
      YamlUtils.readMap(map, 'dependency_overrides'),
    );

    final isFlutter = [...direct, ...dev].any(
      (d) => d.name == 'flutter' && d.isSdk,
    );

    final workspaceNode = map['workspace'];
    final members = workspaceNode is Iterable
        ? workspaceNode.map((e) => e.toString()).toList()
        : const <String>[];

    return PubspecData(
      name: name,
      sdkConstraint: sdkConstraint,
      directDependencies: direct,
      devDependencies: dev,
      overrides: overrides,
      isFlutter: isFlutter,
      workspaceMembers: members,
      resolvesWithWorkspace: map['resolution']?.toString() == 'workspace',
    );
  }

  List<Dependency> _parseDependencySection(
    YamlMap? section,
    DependencyKind kind,
  ) {
    if (section == null) return const [];

    final results = <Dependency>[];
    for (final entry in section.nodes.entries) {
      final keyNode = entry.key as YamlNode;
      final name = keyNode.value.toString();
      final line = keyNode.span.start.line + 1;
      final value = entry.value.value;

      if (name == 'flutter' || name == 'dart' || name == 'flutter_test') {
        results.add(
          Dependency(
            name: name,
            kind: kind,
            constraint: _constraintOf(value),
            isSdk: true,
            source: 'sdk',
            declaredLine: line,
          ),
        );
        continue;
      }

      final description = _describe(value);
      results.add(
        Dependency(
          name: name,
          kind: kind,
          constraint: description.constraint,
          source: description.source,
          isSdk: description.source == 'sdk',
          declaredLine: line,
          sourceUrl: description.url,
        ),
      );
    }
    return results;
  }

  List<DependencyOverride> _parseOverrides(YamlMap? section) {
    if (section == null) return const [];
    final results = <DependencyOverride>[];
    for (final entry in section.nodes.entries) {
      final keyNode = entry.key as YamlNode;
      final description = _describe(entry.value.value);
      results.add(
        DependencyOverride(
          name: keyNode.value.toString(),
          source: description.source,
          constraint: description.constraint,
          sourceUrl: description.url,
          declaredLine: keyNode.span.start.line + 1,
        ),
      );
    }
    return results;
  }

  _Described _describe(Object? value) {
    var constraint = _constraintOf(value);
    var source = 'hosted';
    String? url;

    if (value is Map) {
      if (value.containsKey('sdk')) {
        source = 'sdk';
        constraint = value['sdk']?.toString();
      } else if (value.containsKey('path')) {
        source = 'path';
        url = value['path']?.toString();
      } else if (value.containsKey('git')) {
        source = 'git';
        final git = value['git'];
        url = git is Map ? git['url']?.toString() : git?.toString();
      } else if (value.containsKey('version')) {
        constraint = value['version']?.toString();
      }
    }
    return _Described(source, constraint, url);
  }

  String? _constraintOf(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num) return value.toString();
    return null;
  }
}

class _Described {
  const _Described(this.source, this.constraint, this.url);
  final String source;
  final String? constraint;
  final String? url;
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
