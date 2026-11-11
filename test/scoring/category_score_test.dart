import 'package:pub_health/src/models/health_finding.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/reporting/sarif_reporter.dart';
import 'package:pub_health/src/rules/rule_engine.dart';
import 'package:pub_health/src/scoring/health_scorer.dart';
import 'package:test/test.dart';

HealthFinding f(String rule, Severity s) => HealthFinding(
      ruleId: rule,
      package: 'p',
      severity: s,
      title: 't',
      detail: 'd',
      recommendation: 'r',
    );

void main() {
  const scorer = HealthScorer();

  test('categories only list those with findings', () {
    final score = scorer.score([
      f('stale_package', Severity.medium),
      f('git_dependency', Severity.low),
    ]);
    expect(score.score, 94);
    expect(score.categories, {'maintenance': 95, 'hygiene': 99});
  });

  test('category scores clamp at 0 and unknown rules go to "other"', () {
    final score = scorer.score([
      for (var i = 0; i < 6; i++) f('discontinued_package', Severity.critical),
      f('custom_rule', Severity.low),
    ]);
    expect(score.categories['maintenance'], 0);
    expect(score.categories['other'], 99);
    expect(score.score, 0);
  });

  test('every built-in rule has a category and a SARIF description', () {
    for (final rule in RuleEngine.defaultRuleIds) {
      expect(HealthScorer.categoryOf(rule), isNot('other'), reason: rule);
      expect(SarifReporter.ruleDescriptions, contains(rule));
    }
  });
}
