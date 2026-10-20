import 'severity.dart';

/// Options controlling analysis, rules, and reporting.
class PubHealthOptions {
  /// Creates analysis options.
  const PubHealthOptions({
    this.failOn = Severity.high,
    this.includeTransitive = true,
    this.exclude = const {},
    this.staleAfterMonths = 18,
    this.timeout = const Duration(seconds: 20),
    this.color = true,
    this.verbose = false,
    this.format = ReportFormat.console,
    this.outputPath,
    this.pubDevBaseUrl = 'https://pub.dev',
    this.disabledRules = const {},
    this.concurrency = 6,
    this.projectSdkConstraint,
    this.now,
  });

  /// Minimum severity that causes a non-zero exit code.
  final Severity failOn;

  /// Whether to include transitive dependencies in analysis.
  final bool includeTransitive;

  /// Package names to exclude from rules.
  final Set<String> exclude;

  /// Months without a release before a package is considered stale.
  final int staleAfterMonths;

  /// HTTP timeout for pub.dev requests.
  final Duration timeout;

  /// Whether to use ANSI colors in console output.
  final bool color;

  /// Whether to emit verbose diagnostic logs.
  final bool verbose;

  /// Report output format.
  final ReportFormat format;

  /// Optional file path to write the report to.
  final String? outputPath;

  /// Base URL for the pub.dev API (overridable for tests).
  final String pubDevBaseUrl;

  /// Rule IDs that should not run.
  final Set<String> disabledRules;

  /// Max concurrent pub.dev requests.
  final int concurrency;

  /// Override for the project's Dart SDK constraint (tests).
  final String? projectSdkConstraint;

  /// Clock override for deterministic stale checks (tests).
  final DateTime? now;

  /// Creates a copy with selected fields replaced.
  PubHealthOptions copyWith({
    Severity? failOn,
    bool? includeTransitive,
    Set<String>? exclude,
    int? staleAfterMonths,
    Duration? timeout,
    bool? color,
    bool? verbose,
    ReportFormat? format,
    String? outputPath,
    String? pubDevBaseUrl,
    Set<String>? disabledRules,
    int? concurrency,
    String? projectSdkConstraint,
    DateTime? now,
  }) {
    return PubHealthOptions(
      failOn: failOn ?? this.failOn,
      includeTransitive: includeTransitive ?? this.includeTransitive,
      exclude: exclude ?? this.exclude,
      staleAfterMonths: staleAfterMonths ?? this.staleAfterMonths,
      timeout: timeout ?? this.timeout,
      color: color ?? this.color,
      verbose: verbose ?? this.verbose,
      format: format ?? this.format,
      outputPath: outputPath ?? this.outputPath,
      pubDevBaseUrl: pubDevBaseUrl ?? this.pubDevBaseUrl,
      disabledRules: disabledRules ?? this.disabledRules,
      concurrency: concurrency ?? this.concurrency,
      projectSdkConstraint: projectSdkConstraint ?? this.projectSdkConstraint,
      now: now ?? this.now,
    );
  }
}

/// Supported report formats.
enum ReportFormat {
  /// Colored terminal report.
  console,

  /// Machine-readable JSON.
  json,

  /// Markdown tables.
  markdown,
}

/// Helpers for [ReportFormat].
extension ReportFormatX on ReportFormat {
  /// Parses a format from a CLI/config string.
  static ReportFormat parse(String value) {
    switch (value.toLowerCase()) {
      case 'console':
        return ReportFormat.console;
      case 'json':
        return ReportFormat.json;
      case 'markdown':
        return ReportFormat.markdown;
      default:
        throw FormatException('Unknown report format: $value');
    }
  }
}
