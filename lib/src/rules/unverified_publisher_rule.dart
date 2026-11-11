import '../models/dependency_kind.dart';
import '../models/health_finding.dart';
import '../models/severity.dart';
import 'rule.dart';

/// Flags little-used direct dependencies that have no verified publisher.
///
/// A verified publisher (`publisher:<domain>` tag on pub.dev) is a weak but
/// useful trust signal. To avoid noise, only packages with fewer than
/// [likeThreshold] likes are reported.
class UnverifiedPublisherRule extends Rule {
  /// Creates an unverified-publisher rule.
  const UnverifiedPublisherRule();

  @override
  String get id => 'unverified_publisher';

  @override
  String get name => 'Unverified publisher';

  /// Packages with at least this many likes are never flagged.
  static const int likeThreshold = 100;

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    for (final dep in context.hostedDependencies) {
      if (dep.kind != DependencyKind.direct) continue;
      final score = context.infoFor(dep.name)?.score;
      if (score == null || score.tags.isEmpty) continue;
      if (score.likeCount >= likeThreshold) continue;
      if (score.tags.any((t) => t.startsWith('publisher:'))) continue;

      findings.add(
        HealthFinding(
          ruleId: id,
          package: dep.name,
          severity: Severity.low,
          title: 'No verified publisher',
          detail: '${dep.name} is published by an individual account (no '
              'verified publisher) and has only ${score.likeCount} likes.',
          recommendation:
              'Review the maintainer and repository before relying on it, '
              'especially for security-sensitive code.',
          metadata: {
            'lockedVersion': dep.lockedVersion,
            'likeCount': score.likeCount,
            'line': dep.declaredLine,
          },
        ),
      );
    }
    return findings;
  }
}
