import '../models/health_finding.dart';
import '../models/severity.dart';
import 'rule.dart';

/// Detects packages marked discontinued on pub.dev.
class DiscontinuedRule extends Rule {
  /// Creates a discontinued-package rule.
  const DiscontinuedRule();

  @override
  String get id => 'discontinued_package';

  @override
  String get name => 'Discontinued package';

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    for (final dep in context.hostedDependencies) {
      final info = context.infoFor(dep.name);
      if (info == null || info.notFound) continue;
      if (!info.discontinued) continue;

      final replacement = info.replacedBy;
      findings.add(
        HealthFinding(
          ruleId: id,
          package: dep.name,
          severity: Severity.critical,
          title: 'Package is discontinued',
          detail: 'The package is marked as discontinued on pub.dev.',
          recommendation: replacement == null
              ? 'Find an actively maintained alternative.'
              : 'Consider migrating to `$replacement`.',
          metadata: {
            'lockedVersion': dep.lockedVersion,
            'latestVersion': info.latestVersion,
            if (replacement != null) 'replacedBy': replacement,
          },
        ),
      );
    }
    return findings;
  }
}
