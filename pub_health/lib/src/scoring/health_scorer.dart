import '../models/health_finding.dart';
import '../models/health_score.dart';
import '../models/severity.dart';

/// Calculates an overall dependency health score from findings.
class HealthScorer {
  /// Creates a health scorer.
  const HealthScorer({
    this.criticalPenalty = 25,
    this.highPenalty = 12,
    this.mediumPenalty = 5,
    this.lowPenalty = 1,
  });

  /// Points deducted per critical finding.
  final int criticalPenalty;

  /// Points deducted per high finding.
  final int highPenalty;

  /// Points deducted per medium finding.
  final int mediumPenalty;

  /// Points deducted per low finding.
  final int lowPenalty;

  /// Computes a [HealthScore] for [findings].
  HealthScore score(List<HealthFinding> findings) {
    var total = 100;
    for (final finding in findings) {
      switch (finding.severity) {
        case Severity.critical:
          total -= criticalPenalty;
        case Severity.high:
          total -= highPenalty;
        case Severity.medium:
          total -= mediumPenalty;
        case Severity.low:
          total -= lowPenalty;
      }
    }
    if (total < 0) total = 0;
    if (total > 100) total = 100;
    return HealthScore(
      score: total,
      riskLevel: HealthScore.riskLevelFor(total),
    );
  }
}
