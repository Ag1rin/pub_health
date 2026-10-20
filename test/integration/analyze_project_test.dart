import 'package:pub_health/pub_health.dart';
import 'package:test/test.dart';

import '../support/mock_pub_dev_client.dart';

void main() {
  test('analyzeProject returns a full report for risky fixture', () async {
    final report = await analyzeProject(
      'test/fixtures/risky_project',
      options: PubHealthOptions(
        now: DateTime.utc(2026, 10, 20),
        color: false,
      ),
      client: riskyFixtureClient(now: DateTime.utc(2026, 10, 20)),
    );

    expect(report.findings, isNotEmpty);
    expect(
      report.findings.map((f) => f.ruleId),
      containsAll([
        'outdated_dependency',
        'discontinued_package',
        'retracted_version',
        'stale_package',
        'unused_dependency',
        'low_package_score',
        'sdk_constraint_risk',
      ]),
    );
    expect(report.healthScore.score, lessThan(100));
    expect(report.toJson()['summary'], isA<Map>());
  });

  test('analyzeProject throws on malformed pubspec', () async {
    expect(
      () => analyzeProject('test/fixtures/malformed_project'),
      throwsA(isA<Exception>()),
    );
  });
}
