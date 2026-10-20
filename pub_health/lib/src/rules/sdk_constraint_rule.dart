import '../models/health_finding.dart';
import '../models/severity.dart';
import '../utils/version_utils.dart';
import 'rule.dart';

/// Detects packages whose SDK constraint may not support the project SDK.
class SdkConstraintRule extends Rule {
  /// Creates an SDK constraint rule.
  const SdkConstraintRule();

  @override
  String get id => 'sdk_constraint_risk';

  @override
  String get name => 'SDK constraint risk';

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    final projectConstraint = context.projectSdkConstraint;
    if (projectConstraint == null || projectConstraint.isEmpty) {
      return findings;
    }

    // Use the project's minimum SDK as the version packages must allow.
    final projectMin = VersionUtils.minimumSdkFromConstraint(projectConstraint);
    if (projectMin == null) return findings;

    for (final dep in context.hostedDependencies) {
      final info = context.infoFor(dep.name);
      if (info == null || info.notFound) continue;
      final packageSdk = info.sdkConstraint;
      if (packageSdk == null || packageSdk.isEmpty) continue;

      if (VersionUtils.allowsSdk(packageSdk, projectMin)) continue;

      findings.add(
        HealthFinding(
          ruleId: id,
          package: dep.name,
          severity: Severity.high,
          title: 'SDK constraint risk',
          detail:
              'Current SDK constraint may not support the project\'s Dart SDK.',
          recommendation:
              'Update the dependency or review SDK constraints carefully.',
          metadata: {
            'lockedVersion': dep.lockedVersion,
            'latestVersion': info.latestVersion,
            'packageSdkConstraint': packageSdk,
            'projectSdkConstraint': projectConstraint,
            'projectMinSdk': projectMin,
          },
        ),
      );
    }
    return findings;
  }
}
