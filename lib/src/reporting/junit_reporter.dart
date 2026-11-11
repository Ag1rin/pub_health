import '../models/dependency_report.dart';
import '../models/severity.dart';
import 'report_utils.dart';
import 'reporter.dart';

/// JUnit XML reporter for CI systems that render test reports
/// (GitLab, Jenkins, Azure DevOps, CircleCI, …).
///
/// Findings at or above [failOn] become `<failure>`s; lower-severity findings
/// are emitted as passing test cases with their details in `<system-out>`.
class JunitReporter implements Reporter {
  /// Creates a JUnit reporter.
  const JunitReporter({this.failOn = Severity.high});

  /// Minimum severity reported as a failure.
  final Severity failOn;

  @override
  String report(DependencyReport report) {
    final findings = report.findings;
    final failures =
        findings.where((f) => f.severity.meetsOrExceeds(failOn)).length;

    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<testsuites name="pub_health">')
      ..writeln(
        '  <testsuite name="pub_health" tests="${findings.length}" '
        'failures="$failures" errors="0" skipped="0" '
        'timestamp="${report.generatedAt.toUtc().toIso8601String()}">',
      )
      ..writeln('    <properties>')
      ..writeln(
        '      <property name="healthScore" '
        'value="${report.healthScore.score}"/>',
      )
      ..writeln(
        '      <property name="riskLevel" '
        'value="${ReportUtils.xml(report.healthScore.riskLevel)}"/>',
      )
      ..writeln('    </properties>');

    for (final f in findings) {
      final project = ReportUtils.projectOf(f);
      final name = project == null ? f.package : '${f.package} ($project)';
      final body = '${f.detail}\nRecommendation: ${f.recommendation}';
      buffer.writeln(
        '    <testcase classname="${ReportUtils.xml(f.ruleId)}" '
        'name="${ReportUtils.xml(name)}">',
      );
      if (f.severity.meetsOrExceeds(failOn)) {
        buffer.writeln(
          '      <failure message="${ReportUtils.xml(f.title)}" '
          'type="${f.severity.name}">${ReportUtils.xml(body)}</failure>',
        );
      } else {
        buffer.writeln(
          '      <system-out>[${f.severity.name}] '
          '${ReportUtils.xml(body)}</system-out>',
        );
      }
      buffer.writeln('    </testcase>');
    }

    buffer
      ..writeln('  </testsuite>')
      ..writeln('</testsuites>');
    return buffer.toString();
  }
}
