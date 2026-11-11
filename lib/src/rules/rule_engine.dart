import '../models/health_finding.dart';
import '../models/severity.dart';
import 'dependency_override_rule.dart';
import 'discontinued_rule.dart';
import 'git_dependency_rule.dart';
import 'license_rule.dart';
import 'low_score_rule.dart';
import 'misplaced_dependency_rule.dart';
import 'outdated_rule.dart';
import 'platform_support_rule.dart';
import 'retracted_version_rule.dart';
import 'rule.dart';
import 'sdk_constraint_rule.dart';
import 'stale_package_rule.dart';
import 'unconstrained_dependency_rule.dart';
import 'unused_dependency_rule.dart';
import 'unverified_publisher_rule.dart';

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
              DependencyOverrideRule(),
              GitDependencyRule(),
              UnconstrainedDependencyRule(),
              MisplacedDependencyRule(),
              LicenseRule(),
              PlatformSupportRule(),
              UnverifiedPublisherRule(),
            ];

  /// Rules available for evaluation.
  final List<Rule> rules;

  /// IDs of every rule in the default rule set.
  static List<String> get defaultRuleIds =>
      RuleEngine().rules.map((r) => r.id).toList();

  /// Evaluates all enabled rules for [context].
  List<HealthFinding> evaluate(RuleContext context) {
    final disabled = context.options.disabledRules;
    final overrides = context.options.severityOverrides;
    final findings = <HealthFinding>[];
    final seen = <String>{};

    for (final rule in rules) {
      if (disabled.contains(rule.id)) continue;
      for (var finding in rule.evaluate(context)) {
        final override = overrides[finding.ruleId];
        if (override != null && override != finding.severity) {
          finding = finding.copyWith(severity: override);
        }
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
