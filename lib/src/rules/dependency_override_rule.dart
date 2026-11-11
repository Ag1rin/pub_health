import '../models/health_finding.dart';
import '../models/severity.dart';
import 'rule.dart';

/// Flags `dependency_overrides:` entries, which hide version conflicts.
class DependencyOverrideRule extends Rule {
  /// Creates a dependency-override rule.
  const DependencyOverrideRule();

  @override
  String get id => 'dependency_override';

  @override
  String get name => 'Dependency override';

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    for (final override in context.overrides) {
      if (context.options.exclude.contains(override.name)) continue;

      // Local path overrides are the normal way to wire up a monorepo, so
      // they are reported at the lowest severity.
      final severity =
          override.source == 'path' ? Severity.low : Severity.medium;
      final target = switch (override.source) {
        'git' => 'a git source (${override.sourceUrl ?? 'unknown URL'})',
        'path' => 'a local path (${override.sourceUrl ?? 'unknown path'})',
        _ => 'version ${override.constraint ?? 'any'}',
      };

      findings.add(
        HealthFinding(
          ruleId: id,
          package: override.name,
          severity: severity,
          title: 'Dependency is overridden',
          detail: '`dependency_overrides` forces ${override.name} to $target, '
              'bypassing version resolution.',
          recommendation:
              'Remove the override once the upstream conflict is resolved, '
              'or document why it must stay (use an ignore entry with a '
              'reason and expiry date).',
          metadata: {
            'source': override.source,
            'constraint': override.constraint,
            'sourceUrl': override.sourceUrl,
            'line': override.declaredLine,
          },
        ),
      );
    }
    return findings;
  }
}
