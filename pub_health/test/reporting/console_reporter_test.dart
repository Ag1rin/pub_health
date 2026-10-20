import 'package:pub_health/src/models/dependency.dart';
import 'package:pub_health/src/models/dependency_kind.dart';
import 'package:pub_health/src/models/dependency_report.dart';
import 'package:pub_health/src/models/health_finding.dart';
import 'package:pub_health/src/models/health_score.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/reporting/console_reporter.dart';
import 'package:test/test.dart';

void main() {
  test('renders sections without color codes when disabled', () {
    final report = DependencyReport(
      projectPath: '/tmp/app',
      generatedAt: DateTime.utc(2026, 10, 20, 12),
      dependencies: const [
        Dependency(name: 'a', kind: DependencyKind.direct),
      ],
      findings: const [
        HealthFinding(
          ruleId: 'discontinued_package',
          package: 'firebase_messaging',
          severity: Severity.critical,
          title: 'Package is discontinued',
          detail: 'The package is marked as discontinued on pub.dev.',
          recommendation: 'Find an actively maintained alternative.',
          metadata: {'lockedVersion': '14.7.10'},
        ),
      ],
      healthScore: const HealthScore(score: 58, riskLevel: 'poor'),
    );

    final output = const ConsoleReporter(color: false).report(report);
    expect(output, contains('pub_health report'));
    expect(output, contains('CRITICAL'));
    expect(output, contains('firebase_messaging 14.7.10'));
    expect(output, contains('Overall dependency health: 58/100'));
    expect(output, contains('Risk level: Poor'));
    expect(output, isNot(contains('\x1B[')));
  });
}
