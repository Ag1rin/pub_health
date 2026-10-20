import 'package:pub_health/src/models/health_finding.dart';
import 'package:pub_health/src/models/health_score.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/scoring/health_scorer.dart';
import 'package:test/test.dart';

void main() {
  const scorer = HealthScorer();

  test('starts at 100 with no findings', () {
    final score = scorer.score(const []);
    expect(score.score, 100);
    expect(score.riskLevel, 'excellent');
  });

  test('applies documented deductions', () {
    final score = scorer.score(const [
      HealthFinding(
        ruleId: 'discontinued_package',
        package: 'a',
        severity: Severity.critical,
        title: 't',
        detail: 'd',
        recommendation: 'r',
      ),
      HealthFinding(
        ruleId: 'outdated_dependency',
        package: 'b',
        severity: Severity.medium,
        title: 't',
        detail: 'd',
        recommendation: 'r',
      ),
      HealthFinding(
        ruleId: 'outdated_dependency',
        package: 'c',
        severity: Severity.medium,
        title: 't',
        detail: 'd',
        recommendation: 'r',
      ),
      HealthFinding(
        ruleId: 'stale_package',
        package: 'd',
        severity: Severity.medium,
        title: 't',
        detail: 'd',
        recommendation: 'r',
      ),
    ]);
    // -25 -5 -5 -5 = 60
    expect(score.score, 60);
    expect(score.riskLevel, 'medium');
  });

  test('never goes below zero', () {
    final findings = List.generate(
      10,
      (i) => HealthFinding(
        ruleId: 'discontinued_package',
        package: 'p$i',
        severity: Severity.critical,
        title: 't',
        detail: 'd',
        recommendation: 'r',
      ),
    );
    expect(scorer.score(findings).score, 0);
    expect(scorer.score(findings).riskLevel, 'critical');
  });

  test('maps score boundaries to risk levels', () {
    expect(HealthScore.riskLevelFor(100), 'excellent');
    expect(HealthScore.riskLevelFor(90), 'excellent');
    expect(HealthScore.riskLevelFor(89), 'good');
    expect(HealthScore.riskLevelFor(75), 'good');
    expect(HealthScore.riskLevelFor(74), 'medium');
    expect(HealthScore.riskLevelFor(60), 'medium');
    expect(HealthScore.riskLevelFor(59), 'poor');
    expect(HealthScore.riskLevelFor(40), 'poor');
    expect(HealthScore.riskLevelFor(39), 'critical');
    expect(HealthScore.riskLevelFor(0), 'critical');
  });

  test('applies high and low penalties', () {
    final score = scorer.score(const [
      HealthFinding(
        ruleId: 'retracted_version',
        package: 'a',
        severity: Severity.high,
        title: 't',
        detail: 'd',
        recommendation: 'r',
      ),
      HealthFinding(
        ruleId: 'low_package_score',
        package: 'b',
        severity: Severity.low,
        title: 't',
        detail: 'd',
        recommendation: 'r',
      ),
    ]);
    // 100 - 12 - 1 = 87 → good
    expect(score.score, 87);
    expect(score.riskLevel, 'good');
  });
}
