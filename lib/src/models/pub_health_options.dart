import 'ignore_rule.dart';
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
    this.ignores = const [],
    this.severityOverrides = const {},
    this.baselinePath,
    this.updateBaseline = false,
    this.allowedLicenses = const {},
    this.deniedLicenses = const {},
    this.platforms = const {},
    this.requireWasm = false,
    this.useCache = true,
    this.cacheDir,
    this.cacheTtl = const Duration(hours: 6),
    this.offline = false,
    this.compareTo,
    this.recursive = false,
    this.excludeProjects = const {},
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

  /// Configured suppressions from `pub_health.yaml`.
  final List<IgnoreRule> ignores;

  /// Per-rule severity overrides (rule ID → severity).
  final Map<String, Severity> severityOverrides;

  /// Path to a baseline file; findings recorded in it are suppressed.
  final String? baselinePath;

  /// When true, the current findings are written to [baselinePath].
  final bool updateBaseline;

  /// If non-empty, any license (lowercase SPDX id) outside this set is flagged.
  final Set<String> allowedLicenses;

  /// Licenses (lowercase SPDX ids) that are always flagged.
  final Set<String> deniedLicenses;

  /// Target platforms (`android`, `ios`, `web`, `linux`, `macos`, `windows`)
  /// that direct dependencies must support. Empty disables the check.
  final Set<String> platforms;

  /// Whether direct dependencies must be WebAssembly-ready.
  final bool requireWasm;

  /// Whether the on-disk pub.dev cache is used.
  final bool useCache;

  /// Directory for the on-disk cache (null = platform default).
  final String? cacheDir;

  /// How long cached pub.dev responses stay fresh.
  final Duration cacheTtl;

  /// When true, never touch the network; rely on the on-disk cache only.
  final bool offline;

  /// Path to a previous JSON report to compare against.
  final String? compareTo;

  /// Whether to analyze every Dart project found below the target path.
  final bool recursive;

  /// Project directories (relative to the root, `/`-separated) skipped in
  /// recursive mode.
  final Set<String> excludeProjects;

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
    List<IgnoreRule>? ignores,
    Map<String, Severity>? severityOverrides,
    String? baselinePath,
    bool? updateBaseline,
    Set<String>? allowedLicenses,
    Set<String>? deniedLicenses,
    Set<String>? platforms,
    bool? requireWasm,
    bool? useCache,
    String? cacheDir,
    Duration? cacheTtl,
    bool? offline,
    String? compareTo,
    bool? recursive,
    Set<String>? excludeProjects,
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
      ignores: ignores ?? this.ignores,
      severityOverrides: severityOverrides ?? this.severityOverrides,
      baselinePath: baselinePath ?? this.baselinePath,
      updateBaseline: updateBaseline ?? this.updateBaseline,
      allowedLicenses: allowedLicenses ?? this.allowedLicenses,
      deniedLicenses: deniedLicenses ?? this.deniedLicenses,
      platforms: platforms ?? this.platforms,
      requireWasm: requireWasm ?? this.requireWasm,
      useCache: useCache ?? this.useCache,
      cacheDir: cacheDir ?? this.cacheDir,
      cacheTtl: cacheTtl ?? this.cacheTtl,
      offline: offline ?? this.offline,
      compareTo: compareTo ?? this.compareTo,
      recursive: recursive ?? this.recursive,
      excludeProjects: excludeProjects ?? this.excludeProjects,
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

  /// SARIF 2.1.0 for GitHub code scanning and other SAST viewers.
  sarif,

  /// Self-contained HTML page.
  html,

  /// JUnit XML for CI test-report viewers.
  junit,

  /// shields.io endpoint JSON for a dependency-health badge.
  badge,
}

/// Helpers for [ReportFormat].
extension ReportFormatX on ReportFormat {
  /// Parses a format from a CLI/config string.
  static ReportFormat parse(String value) {
    final lower = value.toLowerCase();
    for (final format in ReportFormat.values) {
      if (format.name == lower) return format;
    }
    throw FormatException('Unknown report format: $value');
  }

  /// Names accepted by `--format`.
  static List<String> get names =>
      ReportFormat.values.map((f) => f.name).toList();
}
