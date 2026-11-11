/// Overall dependency health score and risk classification.
class HealthScore {
  /// Creates a health score.
  const HealthScore({
    required this.score,
    required this.riskLevel,
    this.categories = const {},
  });

  /// Score from 0 to 100.
  final int score;

  /// Human-readable risk level (`excellent`, `good`, `medium`, `poor`,
  /// `critical`).
  final String riskLevel;

  /// Per-category scores (0–100), keyed by category name
  /// (e.g. `maintenance`, `compatibility`, `hygiene`, `licensing`).
  ///
  /// Only categories that contain at least one finding are listed; a missing
  /// category means "no findings" (an implicit 100).
  final Map<String, int> categories;

  /// Serializes to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'score': score,
        'riskLevel': riskLevel,
        'categories': categories,
      };

  /// Derives the risk level label for a numeric [score].
  static String riskLevelFor(int score) {
    if (score >= 90) return 'excellent';
    if (score >= 75) return 'good';
    if (score >= 60) return 'medium';
    if (score >= 40) return 'poor';
    return 'critical';
  }

  /// Display label with capitalized first letter.
  String get displayRiskLevel {
    if (riskLevel.isEmpty) return riskLevel;
    return '${riskLevel[0].toUpperCase()}${riskLevel.substring(1)}';
  }
}
