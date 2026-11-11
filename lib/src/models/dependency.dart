import 'dependency_kind.dart';

/// A resolved dependency from pubspec.yaml / pubspec.lock.
class Dependency {
  /// Creates a dependency description.
  const Dependency({
    required this.name,
    required this.kind,
    this.constraint,
    this.lockedVersion,
    this.source = 'hosted',
    this.isSdk = false,
    this.declaredLine,
    this.sourceUrl,
  });

  /// Package name (e.g. `http`).
  final String name;

  /// How the dependency is related to the project.
  final DependencyKind kind;

  /// Version constraint from pubspec.yaml, if declared.
  final String? constraint;

  /// Locked version from pubspec.lock, if available.
  final String? lockedVersion;

  /// Lockfile source (`hosted`, `git`, `path`, `sdk`).
  final String source;

  /// Whether this is an SDK pseudo-package (Dart/Flutter).
  final bool isSdk;

  /// 1-based line in `pubspec.yaml` where the dependency is declared.
  final int? declaredLine;

  /// Git URL or local path for `git` / `path` dependencies.
  final String? sourceUrl;

  /// Serializes to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'name': name,
        'kind': kind.name,
        'constraint': constraint,
        'lockedVersion': lockedVersion,
        'source': source,
        'isSdk': isSdk,
      };

  /// Creates a copy with selected fields replaced.
  Dependency copyWith({
    String? name,
    DependencyKind? kind,
    String? constraint,
    String? lockedVersion,
    String? source,
    bool? isSdk,
    int? declaredLine,
    String? sourceUrl,
  }) {
    return Dependency(
      name: name ?? this.name,
      kind: kind ?? this.kind,
      constraint: constraint ?? this.constraint,
      lockedVersion: lockedVersion ?? this.lockedVersion,
      source: source ?? this.source,
      isSdk: isSdk ?? this.isSdk,
      declaredLine: declaredLine ?? this.declaredLine,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }

  @override
  String toString() =>
      'Dependency($name, kind: ${kind.name}, locked: $lockedVersion)';
}
