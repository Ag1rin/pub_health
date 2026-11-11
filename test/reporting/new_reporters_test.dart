import 'dart:convert';

import 'package:pub_health/src/models/dependency_report.dart';
import 'package:pub_health/src/models/severity.dart';
import 'package:pub_health/src/reporting/badge_reporter.dart';
import 'package:pub_health/src/reporting/console_reporter.dart';
import 'package:pub_health/src/reporting/html_reporter.dart';
import 'package:pub_health/src/reporting/junit_reporter.dart';
import 'package:pub_health/src/reporting/markdown_reporter.dart';
import 'package:pub_health/src/reporting/report_utils.dart';
import 'package:pub_health/src/reporting/sarif_reporter.dart';
import 'package:pub_health/src/version.dart';
import 'package:test/test.dart';

import '../support/sample_report.dart';

void main() {
  group('SARIF', () {
    late Map<String, dynamic> sarif;
    setUp(() {
      sarif = jsonDecode(
        SarifReporter(baseDirectory: '/repo').report(sampleReport()),
      ) as Map<String, dynamic>;
    });

    test('has the required SARIF 2.1.0 envelope', () {
      expect(sarif['version'], '2.1.0');
      expect(sarif[r'$schema'], contains('sarif-2.1.0'));
      final run = (sarif['runs'] as List).single as Map<String, dynamic>;
      final driver = run['tool']['driver'] as Map<String, dynamic>;
      expect(driver['name'], 'pub_health');
      expect(driver['version'], pubHealthVersion);
    });

    test('maps severities to SARIF levels', () {
      final results = (sarif['runs'][0]['results'] as List).cast<Map>();
      final levels = {for (final r in results) r['ruleId']: r['level']};
      expect(levels['discontinued_package'], 'error');
      expect(levels['outdated_dependency'], 'warning');
      expect(levels['git_dependency'], 'note');
    });

    test('locations are repo-relative with line numbers', () {
      final results = (sarif['runs'][0]['results'] as List).cast<Map>();
      final disc =
          results.firstWhere((r) => r['ruleId'] == 'discontinued_package');
      final loc = disc['locations'][0]['physicalLocation'] as Map;
      expect(loc['artifactLocation']['uri'], 'app/pubspec.yaml');
      expect(loc['region']['startLine'], 17);

      final outdated =
          results.firstWhere((r) => r['ruleId'] == 'outdated_dependency');
      final lockLoc = outdated['locations'][0]['physicalLocation'] as Map;
      expect(lockLoc['artifactLocation']['uri'], 'app/pubspec.lock');
      expect(lockLoc['region']['startLine'], 1);
    });

    test('every result references a defined rule by matching index', () {
      final run = sarif['runs'][0] as Map<String, dynamic>;
      final rules = (run['tool']['driver']['rules'] as List).cast<Map>();
      for (final r in (run['results'] as List).cast<Map>()) {
        expect(rules[r['ruleIndex'] as int]['id'], r['ruleId']);
        expect(
          (r['partialFingerprints'] as Map)['pubHealth/v1'],
          isNotEmpty,
        );
      }
    });

    test('project outside the base directory never yields ../ paths', () {
      final out = SarifReporter(baseDirectory: '/somewhere/else')
          .report(sampleReport());
      expect(out, contains('"uri": "pubspec.yaml"'));
      expect(out, isNot(contains('..')));
    });

    test('project-relative path when running at the repo root', () {
      final out =
          SarifReporter(baseDirectory: '/repo/app').report(sampleReport());
      expect(out, contains('"uri": "pubspec.yaml"'));
    });
  });

  group('JUnit', () {
    test('failures honour the failOn threshold', () {
      final high = const JunitReporter().report(sampleReport());
      expect(high, contains('tests="3" failures="1"'));
      final low =
          const JunitReporter(failOn: Severity.low).report(sampleReport());
      expect(low, contains('failures="3"'));
    });

    test('escapes XML and strips invalid control characters', () {
      final out = const JunitReporter().report(
        sampleReport(package: 'a<b>&"c\'', detail: 'bad\u0001char'),
      );
      expect(out, contains('a&lt;b&gt;&amp;&quot;c&apos;'));
      expect(out, isNot(contains('\u0001')));
      expect(out, startsWith('<?xml'));
    });

    test('ReportUtils.xml keeps valid unicode', () {
      expect(ReportUtils.xml('héllo 🎉'), 'héllo 🎉');
    });
  });

  group('HTML', () {
    test('is self-contained and has no external resources', () {
      final out = const HtmlReporter().report(sampleReport());
      expect(out, startsWith('<!doctype html>'));
      expect(out, contains('69'));
      expect(out, contains('maintenance'));
      expect(out, isNot(contains('http://')));
      expect(out, isNot(contains('<script')));
      expect(out, isNot(contains('<link')));
      expect(out, contains('1 finding(s) suppressed'));
    });

    test('escapes hostile content instead of injecting markup', () {
      final out = const HtmlReporter().report(
        sampleReport(
          package: '<script>alert(1)</script>',
          detail: '"><img src=x onerror=alert(1)>',
          warnings: const ['<b>warn</b>'],
        ),
      );
      expect(out, isNot(contains('<script>alert')));
      expect(out, isNot(contains('<img src=x')));
      expect(out, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
      expect(out, contains('&lt;b&gt;warn&lt;/b&gt;'));
    });

    test('renders a comparison section', () {
      final out = const HtmlReporter().report(
        sampleReport(
          comparison: const ReportComparison(
            previousScore: 60,
            currentScore: 69,
            newFindings: ['git_dependency|g'],
            resolvedFindings: [],
          ),
        ),
      );
      expect(out, contains('60 → 69'));
      expect(out, contains('+9'));
    });
  });

  group('badge', () {
    test('emits shields endpoint JSON', () {
      final json = jsonDecode(const BadgeReporter().report(sampleReport()))
          as Map<String, dynamic>;
      expect(json['schemaVersion'], 1);
      expect(json['message'], '69/100');
      expect(json['color'], 'yellow');
    });

    test('color thresholds', () {
      expect(BadgeReporter.colorFor(95), 'brightgreen');
      expect(BadgeReporter.colorFor(80), 'green');
      expect(BadgeReporter.colorFor(60), 'yellow');
      expect(BadgeReporter.colorFor(40), 'orange');
      expect(BadgeReporter.colorFor(10), 'red');
    });
  });

  group('console & markdown extras', () {
    final report = sampleReport(warnings: const ['careful now']);

    test('console shows fix command, categories, suppressed and notes', () {
      final out = const ConsoleReporter(color: false).report(report);
      expect(out, contains('Try: dart pub remove x && dart pub add y'));
      expect(out, contains('By category: hygiene 99, maintenance 70'));
      expect(out, contains('Suppressed findings: 1'));
      expect(out, contains('careful now'));
    });

    test('markdown lists suggested commands and notes', () {
      final out = const MarkdownReporter().report(report);
      expect(out, contains('## Suggested commands'));
      expect(out, contains('dart pub remove x && dart pub add y'));
      expect(out, contains('## Notes'));
      expect(out, contains('hygiene 99/100'));
    });

    test('JSON includes categories, warnings and suppressed count', () {
      final json = report.toJson();
      expect(json['categories'], {'maintenance': 70, 'hygiene': 99});
      expect(json['suppressedCount'], 1);
      expect(json['warnings'], ['careful now']);
    });
  });
}
