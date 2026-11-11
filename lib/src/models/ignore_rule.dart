import 'health_finding.dart';

/// A configured suppression from the `ignore:` section of `pub_health.yaml`.
///
/// ```yaml
/// ignore:
///   - package: legacy_lib
///     rule: stale_package        # optional: omit to ignore every rule
///     reason: Vendored fork, tracked in ISSUE-123
///     expires: 2027-03-01        # optional: ignore stops applying after this
/// ```
class IgnoreRule {
  /// Creates an ignore rule.
  const IgnoreRule({
    required this.package,
    this.rule,
    this.reason,
    this.expires,
  });

  /// Package the ignore applies to. `*` matches every package.
  final String package;

  /// Rule ID to ignore, or null for all rules.
  final String? rule;

  /// Human-readable justification (strongly recommended).
  final String? reason;

  /// Last day (inclusive, UTC) on which the ignore applies.
  final DateTime? expires;

  /// Whether this ignore has expired at [now].
  bool isExpired(DateTime now) {
    final end = expires;
    if (end == null) return false;
    final lastMoment = DateTime.utc(end.year, end.month, end.day, 23, 59, 59);
    return now.toUtc().isAfter(lastMoment);
  }

  /// Whether this ignore targets [finding].
  bool matches(HealthFinding finding) {
    if (package != '*' && package != finding.package) return false;
    if (rule != null && rule != finding.ruleId) return false;
    return true;
  }

  /// Short description used in warnings.
  String get label => '${rule ?? 'all rules'} for $package';
}
