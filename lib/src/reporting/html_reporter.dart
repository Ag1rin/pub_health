import '../models/dependency_report.dart';
import '../models/health_finding.dart';
import '../models/severity.dart';
import '../utils/string_utils.dart';
import '../version.dart';
import 'report_utils.dart';
import 'reporter.dart';

/// Self-contained HTML report (no external scripts, fonts, or images).
///
/// Every dynamic value is HTML-escaped, so package names or pub.dev text can
/// never inject markup.
class HtmlReporter implements Reporter {
  /// Creates an HTML reporter.
  const HtmlReporter();

  static const String _css = '''
:root{--bg:#fff;--fg:#1b1f24;--muted:#59636e;--card:#f6f8fa;--line:#d1d9e0;
--critical:#cf222e;--high:#bc4c00;--medium:#9a6700;--low:#0969da;--ok:#1a7f37}
@media (prefers-color-scheme:dark){:root{--bg:#0d1117;--fg:#e6edf3;
--muted:#9198a1;--card:#161b22;--line:#30363d;--critical:#ff7b72;
--high:#ffa657;--medium:#d29922;--low:#58a6ff;--ok:#3fb950}}
*{box-sizing:border-box}
body{margin:0;padding:2rem 1rem;background:var(--bg);color:var(--fg);
font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:56rem;margin:0 auto}
h1{margin:0 0 .25rem;font-size:1.6rem}h2{margin:2rem 0 .75rem;font-size:1.15rem}
.muted{color:var(--muted)}
.score{display:flex;gap:1.5rem;align-items:center;flex-wrap:wrap;
background:var(--card);border:1px solid var(--line);border-radius:.75rem;
padding:1.25rem;margin:1.25rem 0}
.score .num{font-size:3rem;font-weight:700;line-height:1}
.good{color:var(--ok)}
.pill{display:inline-block;padding:.1rem .6rem;border-radius:2rem;
font-size:.8rem;font-weight:600;border:1px solid currentColor}
.cats{display:grid;gap:.5rem;flex:1;min-width:14rem}
.bar{height:.5rem;background:var(--line);border-radius:1rem;overflow:hidden}
.bar>span{display:block;height:100%}
.finding{background:var(--card);border:1px solid var(--line);
border-left-width:.3rem;border-radius:.5rem;padding:.75rem 1rem;margin:.6rem 0}
.finding h3{margin:0;font-size:1rem}
.finding p{margin:.35rem 0 0}
code{font:13px ui-monospace,SFMono-Regular,Menlo,monospace;
background:var(--bg);border:1px solid var(--line);border-radius:.3rem;
padding:.1rem .35rem;word-break:break-all}
.critical{border-left-color:var(--critical)}.high{border-left-color:var(--high)}
.medium{border-left-color:var(--medium)}.low{border-left-color:var(--low)}
.t-critical{color:var(--critical)}.t-high{color:var(--high)}
.t-medium{color:var(--medium)}.t-low{color:var(--low)}
ul.warn{padding-left:1.2rem}footer{margin-top:3rem;font-size:.85rem}
''';

  @override
  String report(DependencyReport report) {
    final score = report.healthScore;
    final b = StringBuffer()
      ..writeln('<!doctype html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln(
        '<meta name="viewport" content="width=device-width,initial-scale=1">',
      )
      ..writeln('<meta name="color-scheme" content="light dark">')
      ..writeln('<title>pub_health report</title>')
      ..writeln('<style>$_css</style>')
      ..writeln('</head>')
      ..writeln('<body><main>')
      ..writeln('<h1>pub_health report</h1>')
      ..writeln(
        '<div class="muted">Project: <code>'
        '${ReportUtils.html(report.projectPath)}</code> · Generated '
        '${ReportUtils.html(StringUtils.formatDateTime(report.generatedAt))} '
        'UTC</div>',
      )
      ..writeln('<section class="score">')
      ..writeln('<div><div class="num">${score.score}'
          '<span class="muted" style="font-size:1.2rem">/100</span></div>'
          '<span class="pill ${_scoreClass(score.score)}">'
          '${ReportUtils.html(score.displayRiskLevel)}</span></div>');

    if (score.categories.isNotEmpty) {
      b.writeln('<div class="cats">');
      final names = score.categories.keys.toList()..sort();
      for (final name in names) {
        final value = score.categories[name]!;
        b.writeln(
          '<div><div>${ReportUtils.html(name)} '
          '<span class="muted">$value/100</span></div>'
          '<div class="bar"><span style="width:$value%;'
          'background:var(--${_barVar(value)})"></span></div></div>',
        );
      }
      b.writeln('</div>');
    }
    b.writeln('</section>');

    final comparison = report.comparison;
    if (comparison != null) {
      final sign = comparison.delta > 0 ? '+' : '';
      b
        ..writeln('<h2>Compared to previous report</h2>')
        ..writeln(
          '<p>Score ${comparison.previousScore} → ${comparison.currentScore} '
          '(<strong>$sign${comparison.delta}</strong>). '
          '${comparison.newFindings.length} new, '
          '${comparison.resolvedFindings.length} resolved.</p>',
        );
      if (comparison.newFindings.isNotEmpty) {
        b.writeln('<ul>');
        for (final key in comparison.newFindings) {
          b.writeln('<li>New: <code>${ReportUtils.html(key)}</code></li>');
        }
        b.writeln('</ul>');
      }
    }

    for (final severity in Severity.values.reversed) {
      final findings =
          report.findings.where((f) => f.severity == severity).toList();
      if (findings.isEmpty) continue;
      b.writeln(
        '<h2 class="t-${severity.name}">'
        '${ReportUtils.html(StringUtils.capitalize(severity.name))} '
        '(${findings.length})</h2>',
      );
      for (final finding in findings) {
        _writeFinding(b, finding);
      }
    }

    if (report.findings.isEmpty) {
      b.writeln('<p>No dependency health findings. 🎉</p>');
    }

    if (report.suppressed.isNotEmpty) {
      b.writeln(
        '<p class="muted">${report.suppressed.length} finding(s) suppressed '
        'by ignore rules or the baseline.</p>',
      );
    }

    if (report.warnings.isNotEmpty) {
      b.writeln('<h2>Notes</h2><ul class="warn">');
      for (final w in report.warnings) {
        b.writeln('<li>${ReportUtils.html(w)}</li>');
      }
      b.writeln('</ul>');
    }

    b
      ..writeln(
        '<p class="muted">${report.directDependencyCount} direct · '
        '${report.transitiveDependencyCount} transitive dependencies</p>',
      )
      ..writeln(
        '<footer class="muted">Generated by pub_health '
        '${ReportUtils.html(pubHealthVersion)}</footer>',
      )
      ..writeln('</main></body></html>');
    return b.toString();
  }

  void _writeFinding(StringBuffer b, HealthFinding f) {
    final version = f.metadata['lockedVersion'];
    final project = ReportUtils.projectOf(f);
    final command = ReportUtils.commandOf(f);
    b
      ..writeln('<article class="finding ${f.severity.name}">')
      ..writeln(
        '<h3>${ReportUtils.html(f.package)}'
        '${version == null ? '' : ' <span class="muted">'
            '${ReportUtils.html(version)}</span>'}'
        '${project == null ? '' : ' <span class="muted">in '
            '${ReportUtils.html(project)}</span>'}</h3>',
      )
      ..writeln(
        '<p><code>${ReportUtils.html(f.ruleId)}</code> — '
        '${ReportUtils.html(f.detail)}</p>',
      )
      ..writeln(
        '<p class="muted">Recommendation: '
        '${ReportUtils.html(f.recommendation)}</p>',
      );
    if (command != null) {
      b.writeln('<p>Try: <code>${ReportUtils.html(command)}</code></p>');
    }
    b.writeln('</article>');
  }

  static String _scoreClass(int score) {
    if (score >= 75) return 'good';
    if (score >= 60) return 't-medium';
    return 't-critical';
  }

  static String _barVar(int value) {
    if (value >= 75) return 'ok';
    if (value >= 60) return 'medium';
    return 'critical';
  }
}
