import '../clients/http_client_factory.dart';
import '../clients/pub_dev_cache.dart';
import '../clients/pub_dev_client.dart';
import '../models/dependency.dart';
import '../models/dependency_kind.dart';
import '../models/dependency_report.dart';
import '../models/health_finding.dart';
import '../models/pub_dev_package_info.dart';
import '../models/pub_health_options.dart';
import '../models/severity.dart';
import '../reporting/console_reporter.dart';
import '../reporting/json_reporter.dart';
import '../reporting/markdown_reporter.dart';
import '../reporting/reporter.dart';
import '../rules/rule.dart';
import '../rules/rule_engine.dart';
import '../scoring/health_scorer.dart';
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
  return analyzer.analyze(projectPath);
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

  /// Runs a full analysis for [projectPath].
  Future<DependencyReport> analyze(String projectPath) async {
    final absolutePath = FileUtils.absolute(projectPath);
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

    final unused = await _unusedAnalyzer.findUnused(
      projectPath: absolutePath,
      dependencies: dependencies,
    );

    final client = _client ??
        PubDevClient(
          cache: PubDevCache(),
          httpClient: HttpClientFactory.create(timeout: options.timeout),
          baseUrl: options.pubDevBaseUrl,
          timeout: options.timeout,
        );

    final ownsClient = _client == null;
    try {
      final packageInfo = await _fetchPackageInfo(client, dependencies);

      final context = RuleContext(
        projectPath: absolutePath,
        dependencies: dependencies,
        packageInfo: packageInfo,
        unusedPackages: unused,
        options: options,
        projectSdkConstraint:
            options.projectSdkConstraint ?? pubspec.sdkConstraint,
      );

      final findings = _ruleEngine.evaluate(context);
      final score = _healthScorer.score(findings);

      return DependencyReport(
        projectPath: absolutePath,
        generatedAt: options.now?.toUtc() ?? DateTime.now().toUtc(),
        dependencies: dependencies,
        findings: findings,
        healthScore: score,
      );
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  Future<Map<String, PubDevPackageInfo>> _fetchPackageInfo(
    PubDevClient client,
    List<Dependency> dependencies,
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
    final concurrency = options.concurrency.clamp(1, 16);

    for (var i = 0; i < targets.length; i += concurrency) {
      final chunk = targets.skip(i).take(concurrency);
      final futures = chunk.map((name) async {
        try {
          final info = await client.fetchPackage(name);
          return MapEntry(name, info);
        } on PubDevClientException catch (e) {
          if (e.isNotFound) {
            return MapEntry(
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
        results[entry.key] = entry.value;
      }
    }
    return results;
  }
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
Reporter createReporter(ReportFormat format, {bool color = true}) {
  switch (format) {
    case ReportFormat.console:
      return ConsoleReporter(color: color);
    case ReportFormat.json:
      return const JsonReporter();
    case ReportFormat.markdown:
      return const MarkdownReporter();
  }
}

/// Returns whether [findings] contain any at or above [threshold].
bool hasFailingFindings(
  List<HealthFinding> findings,
  Severity threshold,
) {
  return findings.any((f) => f.severity.meetsOrExceeds(threshold));
}
