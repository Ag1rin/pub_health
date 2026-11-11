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
    this.suppressed = const [],
    this.warnings = const [],
    this.comparison,
    this.projects = const [],
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

  /// Findings hidden by `ignore:` entries or a baseline.
  ///
  /// Suppressed findings do not affect the score or the exit code.
  final List<HealthFinding> suppressed;

  /// Non-fatal diagnostics (expired ignores, offline cache misses, …).
  final List<String> warnings;

  /// Comparison against a previous report, when `--compare-to` was used.
  final ReportComparison? comparison;

  /// Relative paths of the projects covered (recursive / workspace mode).
  ///
  /// Empty for a single-project analysis.
  final List<String> projects;

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
        'categories': healthScore.categories,
        'suppressedCount': suppressed.length,
        'warnings': warnings,
        if (projects.isNotEmpty) 'projects': projects,
        if (comparison != null) 'comparison': comparison!.toJson(),
        'findings': findings.map((f) => f.toJson()).toList(),
        'dependencies': dependencies.map((d) => d.toJson()).toList(),
      };
}

/// Difference between the current report and a previously saved one.
class ReportComparison {
  /// Creates a comparison.
  const ReportComparison({
    required this.previousScore,
    required this.currentScore,
    required this.newFindings,
    required this.resolvedFindings,
  });

  /// Score in the previous report.
  final int previousScore;

  /// Score in the current report.
  final int currentScore;

  /// Finding keys (`ruleId|package`) present now but not before.
  final List<String> newFindings;

  /// Finding keys present before but no longer reported.
  final List<String> resolvedFindings;

  /// Score change (positive = improvement).
  int get delta => currentScore - previousScore;

  /// Serializes to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'previousScore': previousScore,
        'currentScore': currentScore,
        'delta': delta,
        'newFindings': newFindings,
        'resolvedFindings': resolvedFindings,
      };
}
