import 'dart:convert';
import 'dart:io';

import '../models/dependency_report.dart';
import '../models/health_finding.dart';
import '../models/severity.dart';
import '../scoring/health_scorer.dart';
import '../utils/file_utils.dart';
import '../version.dart';
import 'reporter.dart';

/// SARIF 2.1.0 reporter, understood by GitHub code scanning, VS Code's SARIF
/// viewer, Azure DevOps and most other static-analysis dashboards.
class SarifReporter implements Reporter {
  /// Creates a SARIF reporter.
  ///
  /// [baseDirectory] is the repository root that artifact URIs are made
  /// relative to (defaults to the current working directory).
  SarifReporter({String? baseDirectory})
      : _baseDirectory = baseDirectory ?? Directory.current.path;

  final String _baseDirectory;

  static const String _schema = 'https://json.schemastore.org/sarif-2.1.0.json';

  /// Rule descriptions shown in SARIF viewers.
  static const Map<String, String> ruleDescriptions = {
    'outdated_dependency': 'A newer version of the dependency is available.',
    'discontinued_package': 'The package is discontinued on pub.dev.',
    'retracted_version': 'The locked version was retracted by its publisher.',
    'stale_package': 'The package has not been released for a long time.',
    'sdk_constraint_risk':
        'The package SDK constraint may not support the project SDK.',
    'low_package_score': 'The package has a low pub.dev quality score.',
    'unused_dependency': 'A direct dependency has no detected import.',
    'dependency_override': 'dependency_overrides bypasses version resolution.',
    'git_dependency': 'The dependency is fetched from git, not pub.dev.',
    'unconstrained_dependency':
        'The version constraint is missing or too open.',
    'misplaced_dependency': 'The dependency is in the wrong pubspec section.',
    'license_risk': 'The package license is unknown or violates policy.',
    'platform_support':
        'The package does not support a platform the project targets.',
    'unverified_publisher':
        'The package has no verified publisher and little adoption.',
  };

  static String _level(Severity severity) {
    switch (severity) {
      case Severity.critical:
      case Severity.high:
        return 'error';
      case Severity.medium:
        return 'warning';
      case Severity.low:
        return 'note';
    }
  }

  // GitHub maps this CVSS-like score onto its own severity buckets.
  static String _securitySeverity(Severity severity) {
    switch (severity) {
      case Severity.critical:
        return '9.5';
      case Severity.high:
        return '8.0';
      case Severity.medium:
        return '5.0';
      case Severity.low:
        return '2.0';
    }
  }

  @override
  String report(DependencyReport report) {
    final ruleIds = <String>{
      ...ruleDescriptions.keys,
      ...report.findings.map((f) => f.ruleId),
    }.toList()
      ..sort();
    final ruleIndex = {
      for (var i = 0; i < ruleIds.length; i++) ruleIds[i]: i,
    };

    final rules = [
      for (final id in ruleIds)
        {
          'id': id,
          'name': id,
          'shortDescription': {
            'text': ruleDescriptions[id] ?? id,
          },
          'helpUri': 'https://github.com/Ag1rin/pub_health#rules',
          'properties': {
            'tags': ['dependencies', HealthScorer.categoryOf(id)],
          },
        },
    ];

    final results = [
      for (final finding in report.findings)
        _result(report, finding, ruleIndex[finding.ruleId]!),
    ];

    final sarif = {
      r'$schema': _schema,
      'version': '2.1.0',
      'runs': [
        {
          'tool': {
            'driver': {
              'name': 'pub_health',
              'version': pubHealthVersion,
              'informationUri': 'https://github.com/Ag1rin/pub_health',
              'rules': rules,
            },
          },
          'results': results,
          'properties': {
            'healthScore': report.healthScore.score,
            'riskLevel': report.healthScore.riskLevel,
          },
        },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(sarif);
  }

  Map<String, Object?> _result(
    DependencyReport report,
    HealthFinding finding,
    int ruleIndex,
  ) {
    final project = finding.metadata['project'] as String?;
    final file = (finding.metadata['file'] as String?) ?? 'pubspec.yaml';
    final line = finding.metadata['line'];

    final projectDir = project == null
        ? FileUtils.relative(report.projectPath, from: _baseDirectory)
        : FileUtils.relative(
            FileUtils.join(report.projectPath, project),
            from: _baseDirectory,
          );
    // A project outside the repository root cannot be addressed relative to
    // it (`../..` paths are meaningless to code-scanning UIs), so fall back
    // to a path relative to the project itself.
    final outside = projectDir == '..' || projectDir.startsWith('../');
    final uri = (projectDir.isEmpty || projectDir == '.' || outside)
        ? file
        : '$projectDir/$file';

    return {
      'ruleId': finding.ruleId,
      'ruleIndex': ruleIndex,
      'level': _level(finding.severity),
      'message': {
        'text': '${finding.package}: ${finding.detail} '
            'Recommendation: ${finding.recommendation}',
      },
      'locations': [
        {
          'physicalLocation': {
            'artifactLocation': {'uri': uri},
            'region': {'startLine': line is int && line > 0 ? line : 1},
          },
        },
      ],
      // Lets code-scanning track the same issue across runs even when the
      // line number moves.
      'partialFingerprints': {
        'pubHealth/v1': '${project ?? ''}|${finding.key}',
      },
      'properties': {
        'package': finding.package,
        'severity': finding.severity.name,
        'security-severity': _securitySeverity(finding.severity),
      },
    };
  }
}
