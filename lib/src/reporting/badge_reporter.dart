import 'dart:convert';

import '../models/dependency_report.dart';
import 'reporter.dart';

/// Emits a [shields.io endpoint](https://shields.io/badges/endpoint-badge)
/// JSON document for a "dependency health" badge.
///
/// Host the file anywhere (e.g. a GitHub Pages branch or a gist) and point
/// `https://img.shields.io/endpoint?url=...` at it.
class BadgeReporter implements Reporter {
  /// Creates a badge reporter.
  const BadgeReporter();

  /// Badge colour for [score].
  static String colorFor(int score) {
    if (score >= 90) return 'brightgreen';
    if (score >= 75) return 'green';
    if (score >= 60) return 'yellow';
    if (score >= 40) return 'orange';
    return 'red';
  }

  @override
  String report(DependencyReport report) {
    final score = report.healthScore.score;
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'label': 'dependency health',
      'message': '$score/100',
      'color': colorFor(score),
    });
  }
}
