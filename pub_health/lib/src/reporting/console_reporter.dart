import '../models/dependency_kind.dart';
import '../models/dependency_report.dart';
import '../models/health_finding.dart';
import '../models/severity.dart';
import '../utils/string_utils.dart';
import 'reporter.dart';

/// Colored (optional) terminal reporter.
class ConsoleReporter implements Reporter {
  /// Creates a console reporter.
  const ConsoleReporter({this.color = true});

  /// Whether to emit ANSI color codes.
  final bool color;

  static const _reset = '\x1B[0m';
  static const _bold = '\x1B[1m';
  static const _red = '\x1B[31m';
  static const _yellow = '\x1B[33m';
  static const _cyan = '\x1B[36m';
  static const _dim = '\x1B[2m';

  @override
  String report(DependencyReport report) {
    final buffer = StringBuffer();
    buffer.writeln(_paint('pub_health report', _bold));
    buffer.writeln();
    buffer.writeln('Project: ${report.projectPath}');
    buffer.writeln(
      'Generated: ${StringUtils.formatDateTime(report.generatedAt)} UTC',
    );
    buffer.writeln();

    final bySeverity = <Severity, List<HealthFinding>>{
      Severity.critical: [],
      Severity.high: [],
      Severity.medium: [],
      Severity.low: [],
    };
    for (final finding in report.findings) {
      bySeverity[finding.severity]!.add(finding);
    }

    _writeSection(
        buffer, 'CRITICAL', bySeverity[Severity.critical]!, _red, '✖');
    _writeSection(buffer, 'HIGH', bySeverity[Severity.high]!, _yellow, '⚠');
    _writeSection(buffer, 'MEDIUM', bySeverity[Severity.medium]!, _yellow, '⚠');
    _writeSection(buffer, 'LOW', bySeverity[Severity.low]!, _cyan, '•');

    if (report.findings.isEmpty) {
      buffer.writeln(_paint('No dependency health findings.', _cyan));
      buffer.writeln();
    }

    final direct = report.dependencies
        .where((d) => d.kind == DependencyKind.direct)
        .length;
    final transitive = report.dependencies
        .where((d) => d.kind == DependencyKind.transitive)
        .length;

    buffer.writeln('Direct dependencies: $direct');
    buffer.writeln('Transitive dependencies: $transitive');
    buffer.writeln();
    buffer.writeln(
      'Overall dependency health: '
      '${report.healthScore.score}/100',
    );
    buffer.writeln(
      'Risk level: ${report.healthScore.displayRiskLevel}',
    );
    return buffer.toString();
  }

  void _writeSection(
    StringBuffer buffer,
    String title,
    List<HealthFinding> findings,
    String colorCode,
    String bullet,
  ) {
    if (findings.isEmpty) return;
    buffer.writeln(_paint(title, '$colorCode$_bold'));
    for (final finding in findings) {
      final version = finding.metadata['lockedVersion'];
      final versionSuffix = version == null ? '' : ' $version';
      buffer.writeln(
        _paint('$bullet ${finding.package}$versionSuffix', colorCode),
      );
      buffer.writeln('  Rule: ${finding.ruleId}');
      buffer.writeln('  ${finding.detail}');
      buffer.writeln(
        _paint('  Recommendation: ${finding.recommendation}', _dim),
      );
      buffer.writeln();
    }
  }

  String _paint(String text, String code) {
    if (!color) return text;
    return '$code$text$_reset';
  }
}
