import 'dart:convert';

import '../models/health_finding.dart';
import '../models/ignore_rule.dart';
import '../utils/file_utils.dart';

/// Result of applying ignores and a baseline to a list of findings.
class SuppressionResult {
  /// Creates a suppression result.
  const SuppressionResult({
    required this.active,
    required this.suppressed,
    required this.warnings,
  });

  /// Findings that still count (score, exit code, report).
  final List<HealthFinding> active;

  /// Findings hidden by an ignore entry or the baseline.
  final List<HealthFinding> suppressed;

  /// Diagnostics such as expired or unused ignore entries.
  final List<String> warnings;
}

/// A stored snapshot of accepted findings.
///
/// A baseline lets a team adopt pub_health on an existing project: record
/// today's findings once, then fail CI only on *new* ones.
class Baseline {
  /// Creates a baseline from finding keys.
  const Baseline(this.keys);

  /// Current on-disk format version.
  static const int formatVersion = 1;

  /// Accepted finding keys (see [Suppressor.keyOf]).
  final Set<String> keys;

  /// Parses baseline JSON; throws [FormatException] when it is malformed.
  factory Baseline.parse(String content) {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException catch (e) {
      throw FormatException('Baseline is not valid JSON: ${e.message}');
    }
    if (decoded is! Map || decoded['findings'] is! List) {
      throw const FormatException('Baseline must contain a "findings" list.');
    }
    final version = decoded['version'];
    if (version is int && version > formatVersion) {
      throw FormatException(
        'Baseline format version $version is newer than this pub_health '
        'supports ($formatVersion). Upgrade pub_health.',
      );
    }
    final keys = <String>{};
    for (final entry in decoded['findings'] as List) {
      if (entry is! Map) continue;
      final rule = entry['ruleId']?.toString();
      final package = entry['package']?.toString();
      if (rule == null || package == null) continue;
      final project = entry['project']?.toString();
      keys.add(Suppressor.compose(rule, package, project));
    }
    return Baseline(keys);
  }

  /// Loads a baseline file, or null when it does not exist.
  static Future<Baseline?> load(String path) async {
    final content = await FileUtils.readText(path);
    if (content == null) return null;
    return Baseline.parse(content);
  }

  /// Serializes [findings] into baseline JSON (stable ordering).
  static String encode(List<HealthFinding> findings, {DateTime? now}) {
    final entries = findings
        .map(
          (f) => {
            'ruleId': f.ruleId,
            'package': f.package,
            if (f.metadata['project'] != null) 'project': f.metadata['project'],
          },
        )
        .toList()
      ..sort((a, b) {
        final byRule = (a['ruleId']! as String).compareTo(
          b['ruleId']! as String,
        );
        if (byRule != 0) return byRule;
        return (a['package']! as String).compareTo(b['package']! as String);
      });
    return const JsonEncoder.withIndent('  ').convert({
      'version': formatVersion,
      'generatedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'findings': entries,
    });
  }
}

/// Applies `ignore:` entries and a [Baseline] to findings.
class Suppressor {
  /// Creates a suppressor.
  const Suppressor();

  /// Builds a stable key from its parts.
  static String compose(String ruleId, String package, String? project) =>
      project == null ? '$ruleId|$package' : '$ruleId|$package|$project';

  /// Stable key for [finding].
  static String keyOf(HealthFinding finding) => compose(
        finding.ruleId,
        finding.package,
        finding.metadata['project'] as String?,
      );

  /// Splits [findings] into active and suppressed sets.
  SuppressionResult apply(
    List<HealthFinding> findings, {
    required List<IgnoreRule> ignores,
    required DateTime now,
    Baseline? baseline,
  }) {
    final warnings = <String>[];
    final active = <HealthFinding>[];
    final suppressed = <HealthFinding>[];

    final liveIgnores = <IgnoreRule>[];
    for (final ignore in ignores) {
      if (ignore.isExpired(now)) {
        final day = ignore.expires!.toIso8601String().substring(0, 10);
        warnings.add(
          'Ignore for ${ignore.label} expired on $day and no longer applies'
          '${ignore.reason == null ? '' : ' (reason was: ${ignore.reason})'}.',
        );
      } else {
        liveIgnores.add(ignore);
      }
    }

    final usedIgnores = <IgnoreRule>{};
    final matchedBaseline = <String>{};

    for (final finding in findings) {
      final ignore = _firstMatch(liveIgnores, finding);
      if (ignore != null) {
        usedIgnores.add(ignore);
        suppressed.add(finding);
        continue;
      }
      final key = keyOf(finding);
      if (baseline != null && baseline.keys.contains(key)) {
        matchedBaseline.add(key);
        suppressed.add(finding);
        continue;
      }
      active.add(finding);
    }

    for (final ignore in liveIgnores) {
      if (!usedIgnores.contains(ignore)) {
        warnings.add(
          'Ignore for ${ignore.label} matches no current finding; '
          'consider removing it.',
        );
      }
    }
    if (baseline != null) {
      final stale = baseline.keys.difference(matchedBaseline).length;
      if (stale > 0) {
        warnings.add(
          '$stale baseline ${stale == 1 ? 'entry no longer applies' : 'entries no longer apply'}; '
          'run with --update-baseline to prune.',
        );
      }
    }

    return SuppressionResult(
      active: active,
      suppressed: suppressed,
      warnings: warnings,
    );
  }

  IgnoreRule? _firstMatch(List<IgnoreRule> ignores, HealthFinding finding) {
    for (final ignore in ignores) {
      if (ignore.matches(finding)) return ignore;
    }
    return null;
  }
}
