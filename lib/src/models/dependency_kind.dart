/// Classification of a dependency relative to the project.
enum DependencyKind {
  /// Declared under `dependencies:` in pubspec.yaml.
  direct,

  /// Declared under `dev_dependencies:` in pubspec.yaml.
  dev,

  /// Present in the lockfile but not declared directly.
  transitive,
}
