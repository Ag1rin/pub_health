import 'dart:convert';

import '../clients/http_client_factory.dart';
import '../clients/pub_dev_cache.dart';
import '../clients/pub_dev_client.dart';
import '../clients/pub_dev_disk_cache.dart';
import '../models/dependency.dart';
import '../models/dependency_kind.dart';
import '../models/dependency_report.dart';
import '../models/health_finding.dart';
import '../models/health_score.dart';
import '../models/pub_dev_package_info.dart';
import '../models/pub_health_options.dart';
import '../models/severity.dart';
import '../reporting/badge_reporter.dart';
import '../reporting/console_reporter.dart';
import '../reporting/html_reporter.dart';
import '../reporting/json_reporter.dart';
import '../reporting/junit_reporter.dart';
import '../reporting/markdown_reporter.dart';
import '../reporting/reporter.dart';
import '../reporting/sarif_reporter.dart';
import '../rules/rule.dart';
import '../rules/rule_engine.dart';
import '../scoring/health_scorer.dart';
import '../suppression/suppressor.dart';
import '../utils/file_utils.dart';
import '../utils/yaml_utils.dart';
import 'lockfile_analyzer.dart';
import 'pubspec_analyzer.dart';
import 'unused_dependency_analyzer.dart';

/// Analyzes a Dart/Flutter project and returns a [DependencyReport].
///
/// This is the primary library entry point for embedding pub_health.
Future<DependencyReport> analyzeProject(
  String projectPath, {
  PubHealthOptions options = const PubHealthOptions(),
  PubDevClient? client,
}) async {
  final analyzer = ProjectAnalyzer(
    options: options,
    client: client,
  );
  return options.recursive
      ? analyzer.analyzeRecursive(projectPath)
      : analyzer.analyze(projectPath);
}

/// Orchestrates pubspec/lockfile parsing, pub.dev lookups, rules, and scoring.
class ProjectAnalyzer {
  /// Creates a project analyzer.
  ProjectAnalyzer({
    this.options = const PubHealthOptions(),
    PubDevClient? client,
    PubspecAnalyzer? pubspecAnalyzer,
    LockfileAnalyzer? lockfileAnalyzer,
    UnusedDependencyAnalyzer? unusedAnalyzer,
    RuleEngine? ruleEngine,
    HealthScorer? healthScorer,
  })  : _client = client,
        _pubspecAnalyzer = pubspecAnalyzer ?? PubspecAnalyzer(),
        _lockfileAnalyzer = lockfileAnalyzer ?? LockfileAnalyzer(),
        _unusedAnalyzer = unusedAnalyzer ?? UnusedDependencyAnalyzer(),
        _ruleEngine = ruleEngine ?? RuleEngine(),
        _healthScorer = healthScorer ?? const HealthScorer();

  /// Analysis options.
  final PubHealthOptions options;

  final PubDevClient? _client;
  final PubspecAnalyzer _pubspecAnalyzer;
  final LockfileAnalyzer _lockfileAnalyzer;
  final UnusedDependencyAnalyzer _unusedAnalyzer;
  final RuleEngine _ruleEngine;
  final HealthScorer _healthScorer;

  /// Runs a full analysis for a single project at [projectPath].
  Future<DependencyReport> analyze(String projectPath) async {
    final absolutePath = FileUtils.absolute(projectPath);
    _validateProject(absolutePath);

    final client = _obtainClient();
    try {
      final result = await _analyzeOne(absolutePath, client, label: null);
      return await _finish(
        rootPath: absolutePath,
        results: [result],
        client: client,
        projects: const [],
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Analyzes every Dart project found below [rootPath] and merges the
  /// results into one report (workspace / monorepo mode).
  ///
  /// The overall score is the *lowest* project score: a repository is only
  /// as healthy as its weakest package.
  Future<DependencyReport> analyzeRecursive(String rootPath) async {
    final absoluteRoot = FileUtils.absolute(rootPath);
    if (!FileUtils.directoryExists(absoluteRoot)) {
      throw ProjectAnalysisException(
        'Project path does not exist: $absoluteRoot',
      );
    }
    final dirs = FileUtils.findProjects(
      absoluteRoot,
      excludePrefixes: options.excludeProjects,
    );
    if (dirs.isEmpty) {
      throw ProjectAnalysisException(
        'No pubspec.yaml found under $absoluteRoot',
      );
    }

    final client = _obtainClient();
    try {
      final results = <_ProjectResult>[];
      for (final dir in dirs) {
        final label = FileUtils.relative(dir, from: absoluteRoot);
        results.add(await _analyzeOne(dir, client, label: label));
      }
      return await _finish(
        rootPath: absoluteRoot,
        results: results,
        client: client,
        projects: [for (final r in results) r.label ?? '.'],
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  void _validateProject(String absolutePath) {
    if (!FileUtils.directoryExists(absolutePath)) {
      throw ProjectAnalysisException(
        'Project path does not exist: $absolutePath',
      );
    }
    if (!FileUtils.fileExists(FileUtils.join(absolutePath, 'pubspec.yaml'))) {
      throw ProjectAnalysisException(
        'Missing pubspec.yaml in $absolutePath',
      );
    }
  }

  PubDevClient _obtainClient() {
    final injected = _client;
    if (injected != null) return injected;
    final disk = options.useCache
        ? PubDevDiskCache(
            directory: options.cacheDir ?? PubDevDiskCache.defaultDirectory(),
            baseUrl: options.pubDevBaseUrl,
            ttl: options.cacheTtl,
          )
        : null;
    return PubDevClient(
      cache: PubDevCache(),
      httpClient: HttpClientFactory.create(timeout: options.timeout),
      baseUrl: options.pubDevBaseUrl,
      timeout: options.timeout,
      diskCache: disk,
      offline: options.offline,
    );
  }

  Future<_ProjectResult> _analyzeOne(
    String absolutePath,
    PubDevClient client, {
    required String? label,
  }) async {
    _validateProject(absolutePath);

    PubspecData pubspec;
    try {
      pubspec = await _pubspecAnalyzer.analyze(absolutePath);
    } on YamlParseException catch (e) {
      throw ProjectAnalysisException('Malformed pubspec.yaml: ${e.message}');
    } on PubspecAnalysisException catch (e) {
      throw ProjectAnalysisException(e.message);
    }

    LockfileData lockfile;
    try {
      lockfile = await _lockfileAnalyzer.analyze(absolutePath);
    } on YamlParseException catch (e) {
      throw ProjectAnalysisException('Malformed pubspec.lock: ${e.message}');
    }

    var dependencies = _lockfileAnalyzer.mergeWithPubspec(pubspec, lockfile);
    if (!options.includeTransitive) {
      dependencies = dependencies
          .where((d) => d.kind != DependencyKind.transitive)
          .toList();
    }

    final usage = await _unusedAnalyzer.collectUsage(absolutePath);
    final unused = _unusedAnalyzer.unusedFrom(usage, dependencies);

    final warnings = <String>[];
    final prefix = label == null || label == '.' ? '' : '[$label] ';
    if (lockfile.missing) {
      warnings.add(
        '${prefix}No pubspec.lock found; locked versions are unknown. '
        'Run `pub get` first for accurate outdated/retracted checks.',
      );
    }

    final packageInfo = await _fetchPackageInfo(client, dependencies, warnings);

    final context = RuleContext(
      projectPath: absolutePath,
      dependencies: dependencies,
      packageInfo: packageInfo,
      unusedPackages: unused,
      options: options,
      projectSdkConstraint:
          options.projectSdkConstraint ?? pubspec.sdkConstraint,
      overrides: pubspec.overrides,
      productionImports: usage.production,
      isFlutter: pubspec.isFlutter,
    );

    final byName = {for (final d in dependencies) d.name: d};
    final findings = [
      for (final f in _ruleEngine.evaluate(context))
        _tag(_locate(f, byName), label),
    ];

    return _ProjectResult(
      label: label,
      dependencies: dependencies,
      findings: findings,
      warnings: warnings,
    );
  }

  /// Records which file/line a finding points at (used by SARIF).
  HealthFinding _locate(HealthFinding f, Map<String, Dependency> byName) {
    if (f.metadata['file'] != null) return f;
    final dep = byName[f.package];
    final meta = {...f.metadata};
    if (dep?.declaredLine != null) {
      meta['file'] = 'pubspec.yaml';
      meta['line'] ??= dep!.declaredLine;
    } else if (meta['line'] != null) {
      meta['file'] = 'pubspec.yaml';
    } else {
      meta['file'] = 'pubspec.lock';
    }
    return f.copyWith(metadata: meta);
  }

  HealthFinding _tag(HealthFinding f, String? label) {
    if (label == null) return f;
    return f.copyWith(metadata: {...f.metadata, 'project': label});
  }

  Future<DependencyReport> _finish({
    required String rootPath,
    required List<_ProjectResult> results,
    required PubDevClient client,
    required List<String> projects,
  }) async {
    final warnings = <String>[
      ..._configWarnings(),
      for (final r in results) ...r.warnings,
    ];

    final merged = _mergeFindings(results);
    final now = options.now?.toUtc() ?? DateTime.now().toUtc();
    const suppressor = Suppressor();

    List<HealthFinding> active;
    List<HealthFinding> suppressed;

    if (options.updateBaseline) {
      final path = options.baselinePath;
      if (path == null) {
        throw ProjectAnalysisException(
          '--update-baseline requires --baseline <file>.',
        );
      }
      final pass = suppressor.apply(
        merged,
        ignores: options.ignores,
        now: now,
      );
      await FileUtils.writeText(
        path,
        '${Baseline.encode(pass.active, now: now)}\n',
      );
      warnings
        ..addAll(pass.warnings)
        ..add(
            'Baseline written to $path with ${pass.active.length} finding(s).');
      active = const [];
      suppressed = [...pass.suppressed, ...pass.active];
    } else {
      Baseline? baseline;
      final path = options.baselinePath;
      if (path != null) {
        try {
          baseline = await Baseline.load(path);
        } on FormatException catch (e) {
          throw ProjectAnalysisException(
              'Invalid baseline $path: ${e.message}');
        }
        if (baseline == null) {
          throw ProjectAnalysisException(
            'Baseline file not found: $path. '
            'Create it with --baseline $path --update-baseline.',
          );
        }
      }
      final pass = suppressor.apply(
        merged,
        ignores: options.ignores,
        now: now,
        baseline: baseline,
      );
      active = pass.active;
      suppressed = pass.suppressed;
      warnings.addAll(pass.warnings);
    }

    warnings.addAll(client.diagnostics);
    client.diagnostics.clear();

    final dependencies = _mergeDependencies(results);
    final score = _score(active, results);

    ReportComparison? comparison;
    final comparePath = options.compareTo;
    if (comparePath != null) {
      comparison = await _compare(comparePath, active, score.score);
    }

    return DependencyReport(
      projectPath: rootPath,
      generatedAt: now,
      dependencies: dependencies,
      findings: active,
      healthScore: score,
      suppressed: suppressed,
      warnings: warnings,
      comparison: comparison,
      projects: projects,
    );
  }

  /// Merges per-project findings. Findings that come from the shared
  /// lockfile (not declared in a project's own pubspec) are reported once,
  /// because workspace members all resolve against the same lockfile.
  List<HealthFinding> _mergeFindings(List<_ProjectResult> results) {
    if (results.length == 1) return results.single.findings;
    final seenLockFindings = <String>{};
    final merged = <HealthFinding>[];
    for (final result in results) {
      for (final f in result.findings) {
        if (f.metadata['file'] == 'pubspec.lock') {
          final key = '${f.ruleId}|${f.package}|${f.metadata['lockedVersion']}';
          if (!seenLockFindings.add(key)) continue;
        }
        merged.add(f);
      }
    }
    return merged;
  }

  List<Dependency> _mergeDependencies(List<_ProjectResult> results) {
    if (results.length == 1) return results.single.dependencies;
    final byKey = <String, Dependency>{};
    for (final result in results) {
      for (final d in result.dependencies) {
        byKey.putIfAbsent('${d.name}@${d.lockedVersion}', () => d);
      }
    }
    return byKey.values.toList();
  }

  HealthScore _score(List<HealthFinding> active, List<_ProjectResult> results) {
    if (results.length == 1) return _healthScorer.score(active);

    // Multi-project: score each project separately and keep the lowest.
    HealthScore? worst;
    final categoryMin = <String, int>{};
    for (final result in results) {
      final label = result.label ?? '.';
      final mine = active.where((f) => f.metadata['project'] == label).toList();
      final s = _healthScorer.score(mine);
      if (worst == null || s.score < worst.score) worst = s;
      s.categories.forEach((name, value) {
        final current = categoryMin[name];
        if (current == null || value < current) categoryMin[name] = value;
      });
    }
    final base = worst ?? _healthScorer.score(const []);
    return HealthScore(
      score: base.score,
      riskLevel: base.riskLevel,
      categories: categoryMin,
    );
  }

  Future<ReportComparison> _compare(
    String path,
    List<HealthFinding> active,
    int currentScore,
  ) async {
    final content = await FileUtils.readText(path);
    if (content == null) {
      throw ProjectAnalysisException('Comparison report not found: $path');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      throw ProjectAnalysisException(
        '$path is not a valid pub_health JSON report.',
      );
    }
    if (decoded is! Map || decoded['findings'] is! List) {
      throw ProjectAnalysisException(
        '$path is not a pub_health JSON report (use --format json).',
      );
    }
    final previous = <String>{};
    for (final entry in decoded['findings'] as List) {
      if (entry is! Map) continue;
      final rule = entry['ruleId']?.toString();
      final package = entry['package']?.toString();
      if (rule == null || package == null) continue;
      final meta = entry['metadata'];
      final project = meta is Map ? meta['project']?.toString() : null;
      previous.add(Suppressor.compose(rule, package, project));
    }
    final current = active.map(Suppressor.keyOf).toSet();
    return ReportComparison(
      previousScore: (decoded['score'] as num?)?.toInt() ?? 0,
      currentScore: currentScore,
      newFindings: (current.difference(previous).toList())..sort(),
      resolvedFindings: (previous.difference(current).toList())..sort(),
    );
  }

  /// Warns about rule IDs in config that do not exist (usually typos).
  List<String> _configWarnings() {
    final known = RuleEngine.defaultRuleIds.toSet();
    final warnings = <String>[];
    void check(String id, String where) {
      if (!known.contains(id)) {
        warnings.add(
          'Unknown rule "$id" in $where. Known rules: ${known.join(', ')}.',
        );
      }
    }

    for (final id in options.disabledRules) {
      check(id, 'disable-rules');
    }
    for (final id in options.severityOverrides.keys) {
      check(id, 'severity');
    }
    for (final ignore in options.ignores) {
      if (ignore.rule != null) check(ignore.rule!, 'ignore');
    }
    return warnings;
  }

  Future<Map<String, PubDevPackageInfo>> _fetchPackageInfo(
    PubDevClient client,
    List<Dependency> dependencies,
    List<String> warnings,
  ) async {
    final targets = dependencies
        .where((d) => !d.isSdk)
        .where((d) => d.source == 'hosted')
        .where((d) => !options.exclude.contains(d.name))
        .map((d) => d.name)
        .toSet()
        .toList()
      ..sort();

    final results = <String, PubDevPackageInfo>{};
    final offlineMisses = <String>[];
    final concurrency = options.concurrency.clamp(1, 16);

    for (var i = 0; i < targets.length; i += concurrency) {
      final chunk = targets.skip(i).take(concurrency);
      final futures = chunk.map((name) async {
        try {
          final info = await client.fetchPackage(name);
          return MapEntry<String, PubDevPackageInfo?>(name, info);
        } on PubDevOfflineException {
          offlineMisses.add(name);
          return MapEntry<String, PubDevPackageInfo?>(name, null);
        } on PubDevClientException catch (e) {
          if (e.isNotFound) {
            return MapEntry<String, PubDevPackageInfo?>(
              name,
              PubDevPackageInfo(
                name: name,
                latestVersion: '',
                notFound: true,
              ),
            );
          }
          rethrow;
        }
      });
      final entries = await Future.wait(futures);
      for (final entry in entries) {
        final value = entry.value;
        if (value != null) results[entry.key] = value;
      }
    }

    if (offlineMisses.isNotEmpty) {
      offlineMisses.sort();
      warnings.add(
        'Offline mode: ${offlineMisses.length} package(s) have no cached '
        'pub.dev data and were skipped: ${offlineMisses.join(', ')}.',
      );
    }
    return results;
  }
}

class _ProjectResult {
  const _ProjectResult({
    required this.label,
    required this.dependencies,
    required this.findings,
    required this.warnings,
  });

  final String? label;
  final List<Dependency> dependencies;
  final List<HealthFinding> findings;
  final List<String> warnings;
}

/// Thrown when a project cannot be analyzed.
class ProjectAnalysisException implements Exception {
  /// Creates an exception.
  ProjectAnalysisException(this.message);

  /// Error message.
  final String message;

  @override
  String toString() => 'ProjectAnalysisException: $message';
}

/// Builds a [Reporter] for the given [format].
///
/// [failOn] sets the JUnit failure threshold; [baseDirectory] is the root
/// SARIF artifact paths are made relative to.
Reporter createReporter(
  ReportFormat format, {
  bool color = true,
  Severity failOn = Severity.high,
  String? baseDirectory,
}) {
  switch (format) {
    case ReportFormat.console:
      return ConsoleReporter(color: color);
    case ReportFormat.json:
      return const JsonReporter();
    case ReportFormat.markdown:
      return const MarkdownReporter();
    case ReportFormat.sarif:
      return SarifReporter(baseDirectory: baseDirectory);
    case ReportFormat.html:
      return const HtmlReporter();
    case ReportFormat.junit:
      return JunitReporter(failOn: failOn);
    case ReportFormat.badge:
      return const BadgeReporter();
  }
}

/// Returns whether [findings] contain any at or above [threshold].
bool hasFailingFindings(
  List<HealthFinding> findings,
  Severity threshold,
) {
  return findings.any((f) => f.severity.meetsOrExceeds(threshold));
}
