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

  /// Maps each built-in rule to a reporting category.
  ///
  /// Unknown rule IDs fall back to [defaultCategory].
  static const Map<String, String> ruleCategories = {
    'discontinued_package': 'maintenance',
    'stale_package': 'maintenance',
    'outdated_dependency': 'maintenance',
    'retracted_version': 'maintenance',
    'low_package_score': 'maintenance',
    'sdk_constraint_risk': 'compatibility',
    'platform_support': 'compatibility',
    'unused_dependency': 'hygiene',
    'misplaced_dependency': 'hygiene',
    'dependency_override': 'hygiene',
    'git_dependency': 'hygiene',
    'unconstrained_dependency': 'hygiene',
    'unverified_publisher': 'hygiene',
    'license_risk': 'licensing',
  };

  /// Category used for rules that are not in [ruleCategories].
  static const String defaultCategory = 'other';

  /// Category name for [ruleId].
  static String categoryOf(String ruleId) =>
      ruleCategories[ruleId] ?? defaultCategory;

  int _penaltyFor(Severity severity) {
    switch (severity) {
      case Severity.critical:
        return criticalPenalty;
      case Severity.high:
        return highPenalty;
      case Severity.medium:
        return mediumPenalty;
      case Severity.low:
        return lowPenalty;
    }
  }

  /// Computes a [HealthScore] for [findings].
  HealthScore score(List<HealthFinding> findings) {
    var total = 100;
    final categoryTotals = <String, int>{};
    for (final finding in findings) {
      final penalty = _penaltyFor(finding.severity);
      total -= penalty;
      final category = categoryOf(finding.ruleId);
      categoryTotals[category] = (categoryTotals[category] ?? 100) - penalty;
    }
    return HealthScore(
      score: total.clamp(0, 100),
      riskLevel: HealthScore.riskLevelFor(total.clamp(0, 100)),
      categories: {
        for (final entry in categoryTotals.entries)
          entry.key: entry.value.clamp(0, 100),
      },
    );
  }
}
