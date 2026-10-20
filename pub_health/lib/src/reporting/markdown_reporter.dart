import '../models/dependency_report.dart';
import '../models/severity.dart';
import '../utils/string_utils.dart';
import 'reporter.dart';

/// Markdown reporter with severity tables.
class MarkdownReporter implements Reporter {
  /// Creates a Markdown reporter.
  const MarkdownReporter();

  @override
  String report(DependencyReport report) {
    final buffer = StringBuffer();
    buffer.writeln('# pub_health report');
    buffer.writeln();
    buffer.writeln('**Project:** `${report.projectPath}`');
    buffer.writeln(
      '**Generated:** ${StringUtils.formatDateTime(report.generatedAt)} UTC',
    );
    buffer.writeln(
      '**Overall dependency health:** ${report.healthScore.score}/100',
    );
    buffer.writeln(
      '**Risk level:** ${report.healthScore.displayRiskLevel}',
    );
    buffer.writeln();

    for (final severity in Severity.values.reversed) {
      final findings =
          report.findings.where((f) => f.severity == severity).toList();
      if (findings.isEmpty) continue;
      buffer.writeln('## ${StringUtils.capitalize(severity.name)}');
      buffer.writeln();
      buffer.writeln('| Package | Rule | Detail | Recommendation |');
      buffer.writeln('|---|---|---|---|');
      for (final finding in findings) {
        buffer.writeln(
          '| ${_escape(finding.package)} | ${_escape(finding.ruleId)} | '
          '${_escape(_short(finding.detail))} | '
          '${_escape(_short(finding.recommendation))} |',
        );
      }
      buffer.writeln();
    }

    if (report.findings.isEmpty) {
      buffer.writeln('_No dependency health findings._');
      buffer.writeln();
    }

    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.writeln('- Direct dependencies: ${report.directDependencyCount}');
    buffer.writeln(
      '- Transitive dependencies: ${report.transitiveDependencyCount}',
    );
    buffer.writeln('- Critical: ${report.countBySeverity(Severity.critical)}');
    buffer.writeln('- High: ${report.countBySeverity(Severity.high)}');
    buffer.writeln('- Medium: ${report.countBySeverity(Severity.medium)}');
    buffer.writeln('- Low: ${report.countBySeverity(Severity.low)}');
    return buffer.toString();
  }

  String _escape(String value) =>
      value.replaceAll('|', '\\|').replaceAll('\n', ' ');

  String _short(String value) {
    if (value.length <= 120) return value;
    return '${value.substring(0, 117)}...';
  }
}
