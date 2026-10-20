import '../models/health_finding.dart';
import '../models/severity.dart';
import 'rule.dart';

/// Detects locked versions that have been retracted on pub.dev.
class RetractedVersionRule extends Rule {
  /// Creates a retracted-version rule.
  const RetractedVersionRule();

  @override
  String get id => 'retracted_version';

  @override
  String get name => 'Retracted version';

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    for (final dep in context.hostedDependencies) {
      final locked = dep.lockedVersion;
      if (locked == null) continue;
      final info = context.infoFor(dep.name);
      if (info == null || info.notFound) continue;
      if (!info.isRetracted(locked)) continue;

      findings.add(
        HealthFinding(
          ruleId: id,
          package: dep.name,
          severity: Severity.high,
          title: 'Locked version is retracted',
          detail: 'Version $locked of ${dep.name} is retracted on pub.dev.',
          recommendation:
              'Upgrade or downgrade to a non-retracted stable version.',
          metadata: {
            'lockedVersion': locked,
            'latestVersion': info.latestVersion,
          },
        ),
      );
    }
    return findings;
  }
}
