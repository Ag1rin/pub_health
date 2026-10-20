/// Severity level for a health finding.
enum Severity {
  /// Informational / low-impact issues.
  low,

  /// Moderate risk that should be reviewed.
  medium,

  /// Significant risk that may break builds or security posture.
  high,

  /// Severe risk requiring immediate attention.
  critical,
}

/// Extensions for [Severity].
extension SeverityX on Severity {
  /// Parses a severity from a CLI/config string.
  static Severity parse(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return Severity.low;
      case 'medium':
        return Severity.medium;
      case 'high':
        return Severity.high;
      case 'critical':
        return Severity.critical;
      default:
        throw FormatException('Unknown severity: $value');
    }
  }

  /// Numeric rank used for threshold comparisons (higher = worse).
  int get rank {
    switch (this) {
      case Severity.low:
        return 1;
      case Severity.medium:
        return 2;
      case Severity.high:
        return 3;
      case Severity.critical:
        return 4;
    }
  }

  /// Whether this severity meets or exceeds [threshold].
  bool meetsOrExceeds(Severity threshold) => rank >= threshold.rank;

  /// Wire / display name.
  String get label => name;
}
