import 'dart:convert';

import 'package:pub_health/src/models/dependency_report.dart';
import 'package:pub_health/src/models/health_finding.dart';
import 'package:pub_health/src/models/health_score.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/reporting/json_reporter.dart';
import 'package:test/test.dart';

void main() {
  test('emits valid JSON with expected fields', () {
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
          detail: 'The package is marked as discontinued on pub.dev.',
          recommendation: 'Find an actively maintained alternative.',
          metadata: {
            'lockedVersion': '14.7.10',
            'latestVersion': '15.0.0',
          },
        ),
      ],
      healthScore: const HealthScore(score: 58, riskLevel: 'poor'),
    );

    final decoded =
        jsonDecode(const JsonReporter().report(report)) as Map<String, dynamic>;
    expect(decoded['score'], 58);
    expect(decoded['riskLevel'], 'poor');
    expect(decoded['generatedAt'], '2026-10-20T12:00:00.000Z');
    expect(decoded['summary']['critical'], 1);
    expect(decoded['findings'], hasLength(1));
  });
}
