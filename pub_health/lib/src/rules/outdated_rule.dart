import '../models/health_finding.dart';
import '../models/severity.dart';
import '../utils/version_utils.dart';
import 'rule.dart';

/// Detects dependencies whose locked version is behind latest.
class OutdatedRule extends Rule {
  /// Creates an outdated-dependency rule.
  const OutdatedRule();

  @override
  String get id => 'outdated_dependency';

  @override
  String get name => 'Outdated dependency';

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    for (final dep in context.hostedDependencies) {
      final info = context.infoFor(dep.name);
      if (info == null || info.notFound) continue;
      if (dep.lockedVersion == null || info.latestVersion.isEmpty) continue;
      if (!VersionUtils.isOutdated(dep.lockedVersion, info.latestVersion)) {
        continue;
      }

      final bump =
          VersionUtils.classifyBump(dep.lockedVersion, info.latestVersion);
      findings.add(
        HealthFinding(
          ruleId: id,
          package: dep.name,
          severity: Severity.medium,
          title: 'Dependency is outdated',
          detail: 'Locked version ${dep.lockedVersion} is older than latest '
              '${info.latestVersion} (${bump.name} upgrade).',
          recommendation:
              'Review the changelog and update the version constraint.',
          metadata: {
            'lockedVersion': dep.lockedVersion,
            'latestVersion': info.latestVersion,
            'upgradeType': bump.name,
          },
        ),
      );
    }
    return findings;
  }
}
