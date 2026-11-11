/// An entry from the `dependency_overrides:` section of pubspec.yaml.
class DependencyOverride {
  /// Creates an override description.
  const DependencyOverride({
    required this.name,
    required this.source,
    this.constraint,
    this.sourceUrl,
    this.declaredLine,
  });

  /// Overridden package name.
  final String name;

  /// Source kind: `hosted`, `git`, `path`, or `sdk`.
  final String source;

  /// Version constraint, when the override is a hosted version.
  final String? constraint;

  /// Git URL or local path, when applicable.
  final String? sourceUrl;

  /// 1-based line in `pubspec.yaml`.
  final int? declaredLine;
}
