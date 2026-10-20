import '../models/health_finding.dart';
import '../models/severity.dart';
import 'discontinued_rule.dart';
import 'low_score_rule.dart';
import 'outdated_rule.dart';
import 'retracted_version_rule.dart';
import 'rule.dart';
import 'sdk_constraint_rule.dart';
import 'stale_package_rule.dart';
import 'unused_dependency_rule.dart';

/// Runs enabled rules and deduplicates findings.
class RuleEngine {
  /// Creates a rule engine.
  RuleEngine({List<Rule>? rules})
      : rules = rules ??
            const [
              OutdatedRule(),
              DiscontinuedRule(),
              RetractedVersionRule(),
              StalePackageRule(),
              SdkConstraintRule(),
              LowScoreRule(),
              UnusedDependencyRule(),
            ];

  /// Rules available for evaluation.
  final List<Rule> rules;

  /// Evaluates all enabled rules for [context].
  List<HealthFinding> evaluate(RuleContext context) {
    final disabled = context.options.disabledRules;
    final findings = <HealthFinding>[];
    final seen = <String>{};

    for (final rule in rules) {
      if (disabled.contains(rule.id)) continue;
      for (final finding in rule.evaluate(context)) {
        final key =
            '${finding.ruleId}|${finding.package}|${finding.severity.name}';
        if (seen.add(key)) {
          findings.add(finding);
        }
      }
    }

    findings.sort((a, b) {
      final severityCmp = b.severity.rank.compareTo(a.severity.rank);
      if (severityCmp != 0) return severityCmp;
      final packageCmp = a.package.compareTo(b.package);
      if (packageCmp != 0) return packageCmp;
      return a.ruleId.compareTo(b.ruleId);
    });

    return findings;
  }
}
