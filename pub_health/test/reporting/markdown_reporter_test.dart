import 'package:pub_health/src/models/dependency_report.dart';
import 'package:pub_health/src/models/health_finding.dart';
import 'package:pub_health/src/models/health_score.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/reporting/markdown_reporter.dart';
import 'package:test/test.dart';

void main() {
  test('renders markdown tables by severity', () {
    final report = DependencyReport(
      projectPath: '.',
      generatedAt: DateTime.utc(2026, 10, 20, 12),
      dependencies: const [],
      findings: const [
        HealthFinding(
          ruleId: 'discontinued_package',
          package: 'firebase_messaging',
          severity: Severity.critical,
          title: 'Package is discontinued',
          detail: 'Package is discontinued',
          recommendation: 'Find an alternative',
        ),
        HealthFinding(
          ruleId: 'sdk_constraint_risk',
          package: 'http',
          severity: Severity.high,
          title: 'SDK constraint risk',
          detail: 'SDK constraint risk',
          recommendation: 'Update dependency',
        ),
      ],
      healthScore: const HealthScore(score: 58, riskLevel: 'poor'),
    );

    final output = const MarkdownReporter().report(report);
    expect(output, contains('# pub_health report'));
    expect(output, contains('## Critical'));
    expect(output, contains('## High'));
    expect(output, contains('| firebase_messaging | discontinued_package |'));
  });
}
