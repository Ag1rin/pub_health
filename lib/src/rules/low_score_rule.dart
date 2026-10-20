import '../models/health_finding.dart';
import '../models/severity.dart';
import 'rule.dart';

/// Detects packages with unusually low pub.dev scores.
class LowScoreRule extends Rule {
  /// Creates a low-score rule.
  const LowScoreRule({
    this.minGrantedPoints = 50,
    this.minRatio = 0.4,
  });

  /// Absolute minimum granted points before flagging.
  final int minGrantedPoints;

  /// Minimum granted/max ratio before flagging.
  final double minRatio;

  @override
  String get id => 'low_package_score';

  @override
  String get name => 'Low package score';

  @override
  List<HealthFinding> evaluate(RuleContext context) {
    final findings = <HealthFinding>[];
    for (final dep in context.hostedDependencies) {
      final info = context.infoFor(dep.name);
      if (info == null || info.notFound) continue;
      final score = info.score;
      if (score == null || score.maxPoints == 0) continue;

      final lowPoints = score.grantedPoints < minGrantedPoints;
      final lowRatio = score.ratio < minRatio;
      if (!lowPoints && !lowRatio) continue;

      findings.add(
        HealthFinding(
          ruleId: id,
          package: dep.name,
          severity: Severity.low,
          title: 'Package has a low pub.dev score',
          detail: 'Package has a low pub.dev score '
              '(${score.grantedPoints}/${score.maxPoints} points).',
          recommendation: 'Review package quality before relying on it.',
          metadata: {
            'lockedVersion': dep.lockedVersion,
            'latestVersion': info.latestVersion,
            'grantedPoints': score.grantedPoints,
            'maxPoints': score.maxPoints,
            'likeCount': score.likeCount,
          },
        ),
      );
    }
    return findings;
  }
}
