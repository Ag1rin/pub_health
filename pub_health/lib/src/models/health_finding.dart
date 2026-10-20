import 'severity.dart';

/// A single dependency health finding produced by a rule.
class HealthFinding {
  /// Creates a health finding.
  const HealthFinding({
    required this.ruleId,
    required this.package,
    required this.severity,
    required this.title,
    required this.detail,
    required this.recommendation,
    this.metadata = const {},
  });

  /// Stable rule identifier (e.g. `outdated_dependency`).
  final String ruleId;

  /// Affected package name.
  final String package;

  /// Finding severity.
  final Severity severity;

  /// Short human-readable title.
  final String title;

  /// Detailed explanation.
  final String detail;

  /// Suggested remediation.
  final String recommendation;

  /// Extra structured metadata for reporters / tooling.
  final Map<String, Object?> metadata;

  /// Serializes to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'ruleId': ruleId,
        'package': package,
        'severity': severity.name,
        'title': title,
        'detail': detail,
        'recommendation': recommendation,
        'metadata': metadata,
      };

  /// Creates a finding from a JSON map.
  factory HealthFinding.fromJson(Map<String, Object?> json) {
    return HealthFinding(
      ruleId: json['ruleId']! as String,
      package: json['package']! as String,
      severity: SeverityX.parse(json['severity']! as String),
      title: json['title']! as String,
      detail: json['detail']! as String,
      recommendation: json['recommendation']! as String,
      metadata: Map<String, Object?>.from(
        (json['metadata'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
    );
  }
}
