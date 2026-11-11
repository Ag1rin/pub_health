import 'package:pub_health/src/models/dependency.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:pub_health/src/models/dependency_report.dart';
import 'package:pub_health/src/models/health_finding.dart';
import 'package:pub_health/src/models/health_score.dart';
import 'package:pub_health/src/models/severity.dart';

/// A report covering every severity, used by reporter tests.
DependencyReport sampleReport({
  String package = 'firebase_messaging',
  String detail = 'The package is marked as discontinued on pub.dev.',
  List<String> warnings = const [],
  ReportComparison? comparison,
}) {
  return DependencyReport(
    projectPath: '/repo/app',
    generatedAt: DateTime.utc(2026, 11, 10, 12),
    dependencies: const [
      Dependency(name: 'a', kind: DependencyKind.direct),
      Dependency(name: 'b', kind: DependencyKind.transitive),
    ],
    findings: [
      HealthFinding(
        ruleId: 'discontinued_package',
        package: package,
        severity: Severity.critical,
        title: 'Package is discontinued',
        detail: detail,
        recommendation: 'Find an alternative.',
        metadata: const {
          'lockedVersion': '14.7.10',
          'line': 17,
          'file': 'pubspec.yaml',
          'suggestedCommand': 'dart pub remove x && dart pub add y',
        },
      ),
      const HealthFinding(
        ruleId: 'outdated_dependency',
        package: 'http',
        severity: Severity.medium,
        title: 'Dependency is outdated',
        detail: 'Locked 0.13.0 is older than 1.2.0.',
        recommendation: 'Update.',
        metadata: {'file': 'pubspec.lock'},
      ),
      const HealthFinding(
        ruleId: 'git_dependency',
        package: 'g',
        severity: Severity.low,
        title: 'Dependency comes from git',
        detail: 'From git.',
        recommendation: 'Pin.',
      ),
    ],
    healthScore: const HealthScore(
      score: 69,
      riskLevel: 'medium',
      categories: {'maintenance': 70, 'hygiene': 99},
    ),
    suppressed: const [
      HealthFinding(
        ruleId: 'stale_package',
        package: 'z',
        severity: Severity.medium,
        title: 't',
        detail: 'd',
        recommendation: 'r',
      ),
    ],
    warnings: warnings,
    comparison: comparison,
  );
}
