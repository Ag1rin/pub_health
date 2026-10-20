import 'dependency.dart';
import 'health_finding.dart';
import 'health_score.dart';
import 'severity.dart';

/// Full result of analyzing a project's dependency health.
class DependencyReport {
  /// Creates a dependency report.
  const DependencyReport({
    required this.projectPath,
    required this.generatedAt,
    required this.dependencies,
    required this.findings,
    required this.healthScore,
  });

  /// Absolute or relative path that was analyzed.
  final String projectPath;

  /// Generation timestamp (UTC).
  final DateTime generatedAt;

  /// All discovered dependencies.
  final List<Dependency> dependencies;

  /// Findings produced by rules.
  final List<HealthFinding> findings;

  /// Calculated overall health score.
  final HealthScore healthScore;

  /// Count of direct (runtime) dependencies.
  int get directDependencyCount =>
      dependencies.where((d) => d.kind.name == 'direct').length;

  /// Count of transitive dependencies.
  int get transitiveDependencyCount =>
      dependencies.where((d) => d.kind.name == 'transitive').length;

  /// Count of findings at [severity].
  int countBySeverity(Severity severity) =>
      findings.where((f) => f.severity == severity).length;

  /// Serializes to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'projectPath': projectPath,
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'score': healthScore.score,
        'riskLevel': healthScore.riskLevel,
        'summary': {
          'directDependencies': directDependencyCount,
          'transitiveDependencies': transitiveDependencyCount,
          'critical': countBySeverity(Severity.critical),
          'high': countBySeverity(Severity.high),
          'medium': countBySeverity(Severity.medium),
          'low': countBySeverity(Severity.low),
        },
        'findings': findings.map((f) => f.toJson()).toList(),
        'dependencies': dependencies.map((d) => d.toJson()).toList(),
      };
}
