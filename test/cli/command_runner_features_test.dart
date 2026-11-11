import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_health/src/analyzers/project_analyzer.dart';
import 'package:pub_health/src/cli/cli_options.dart';
import 'package:pub_health/src/cli/command_runner.dart';
import 'package:pub_health/src/cli/exit_codes.dart';
import 'package:pub_health/src/config/pub_health_config.dart';
import 'package:test/test.dart';

import '../support/memory_sink.dart';
import '../support/mock_pub_dev_client.dart';
import '../support/temp_project.dart';

void main() {
  late Directory tmp;
  late MemorySink out;
  late MemorySink err;
  late Directory project;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pub_health_cli_');
    out = MemorySink();
    err = MemorySink();
    project = await createTempProject(
      parent: tmp,
      subdir: 'proj',
      pubspec: '''
name: demo
environment:
  sdk: ^3.5.0
dependencies:
  alpha: any
''',
      lock: lockFile([lockEntry('alpha', '1.0.0')]),
      files: {'lib/main.dart': "import 'package:alpha/alpha.dart';\n"},
    );
  });
  tearDown(() => tmp.delete(recursive: true));

  PubHealthCommandRunner runner() => PubHealthCommandRunner(
        stdoutSink: out,
        stderrSink: err,
        stdinHasTerminal: () => false,
        analyzerFactory: (opts) => ProjectAnalyzer(
          options: opts.copyWith(now: DateTime.utc(2026, 11, 10)),
          client: mockPubDevClient(
            packages: {
              'alpha': packageJson(
                name: 'alpha',
                latestVersion: '1.0.0',
                sdkConstraint: '>=3.0.0 <4.0.0',
              ),
            },
          ),
        ),
      );

  Future<int> run(List<String> args) =>
      runner().run(['--path', project.path, ...args]);

  group('init', () {
    test('creates a parseable starter config', () async {
      final code = await runner().run(['init', '--path', project.path]);
      expect(code, ExitCodes.success);
      final file = File(p.join(project.path, 'pub_health.yaml'));
      expect(file.existsSync(), isTrue);
      final config = PubHealthConfig.parse(file.readAsStringSync());
      expect(config.failOn, isNotNull);
      expect(config.staleAfterMonths, 18);
    });

    test('refuses to overwrite without --force', () async {
      final file = File(p.join(project.path, 'pub_health.yaml'))
        ..writeAsStringSync('fail-on: low\n');
      expect(
        await runner().run(['init', '--path', project.path]),
        ExitCodes.invalidUsage,
      );
      expect(err.buffer.toString(), contains('--force'));
      expect(file.readAsStringSync(), 'fail-on: low\n');

      expect(
        await runner().run(['init', '--path', project.path, '--force']),
        ExitCodes.success,
      );
      expect(file.readAsStringSync(), contains('fail-on: high'));
    });

    test('rejects extra arguments and missing directories', () async {
      expect(
        await runner().run(['init', 'extra']),
        ExitCodes.invalidUsage,
      );
      expect(
        await runner().run(['init', '--path', p.join(tmp.path, 'nope')]),
        ExitCodes.invalidUsage,
      );
    });
  });

  group('formats', () {
    for (final format in ['sarif', 'html', 'junit', 'badge']) {
      test('--format $format works end-to-end', () async {
        final code = await run(['--format', format, '--no-color']);
        expect(
            code, anyOf(ExitCodes.success, ExitCodes.findingsAboveThreshold));
        final text = out.buffer.toString();
        expect(text, isNotEmpty);
        switch (format) {
          case 'sarif':
            expect(jsonDecode(text)['version'], '2.1.0');
          case 'badge':
            expect(jsonDecode(text)['label'], 'dependency health');
          case 'html':
            expect(text, contains('<!doctype html>'));
          case 'junit':
            expect(text, contains('<testsuites'));
        }
      });
    }

    test('config can pick a new format and --output writes a file', () async {
      File(p.join(project.path, 'pub_health.yaml'))
          .writeAsStringSync('report:\n  format: junit\n');
      final target = p.join(tmp.path, 'out', 'r.xml');
      await run(['--output', target]);
      expect(File(target).readAsStringSync(), contains('<testsuite '));
    });

    test('junit failure threshold follows --fail-on', () async {
      await run(['--format', 'junit', '--fail-on', 'medium']);
      expect(out.buffer.toString(), contains('failures="1"'));
    });
  });

  group('baseline via CLI', () {
    test('update then reuse: exit 0 and findings hidden', () async {
      final base = p.join(tmp.path, 'base.json');
      expect(
        await run(
            ['--baseline', base, '--update-baseline', '--fail-on', 'low']),
        ExitCodes.success,
      );
      expect(File(base).existsSync(), isTrue);

      out = MemorySink();
      expect(
        await run(['--baseline', base, '--fail-on', 'low', '--no-color']),
        ExitCodes.success,
      );
      expect(out.buffer.toString(), contains('Suppressed findings'));
    });

    test('without a baseline the same project fails at --fail-on low',
        () async {
      expect(
        await run(['--fail-on', 'low']),
        ExitCodes.findingsAboveThreshold,
      );
    });

    test('baseline named in config is resolved relative to the project',
        () async {
      File(p.join(project.path, 'pub_health.yaml'))
          .writeAsStringSync('baseline: bl.json\nfail-on: low\n');
      expect(
        await runner().run(['--path', project.path]),
        ExitCodes.invalidUsage,
      );
      expect(err.buffer.toString(), contains('bl.json'));
      expect(err.buffer.toString(), contains(project.path));
    });

    test('--update-baseline requires --baseline', () async {
      expect(await run(['--update-baseline']), ExitCodes.invalidUsage);
      expect(err.buffer.toString(), contains('--baseline'));
    });

    test('ignore entries from pub_health.yaml suppress findings', () async {
      File(p.join(project.path, 'pub_health.yaml')).writeAsStringSync('''
fail-on: low
ignore:
  - package: alpha
    reason: pinned by vendor
''');
      expect(await run(['--no-color']), ExitCodes.success);
    });

    test('invalid ignore config exits with usage error', () async {
      File(p.join(project.path, 'pub_health.yaml'))
          .writeAsStringSync('ignore:\n  - rule: x\n');
      expect(await run([]), ExitCodes.invalidUsage);
      expect(err.buffer.toString(), contains('pub_health.yaml'));
    });
  });

  group('pub server url', () {
    Future<String> urlFor(
      List<String> args, {
      Map<String, String> env = const {},
      String? config,
    }) async {
      if (config != null) {
        File(p.join(project.path, 'pub_health.yaml')).writeAsStringSync(config);
      }
      String? seen;
      final r = PubHealthCommandRunner(
        stdoutSink: out,
        stderrSink: err,
        stdinHasTerminal: () => false,
        environment: env,
        analyzerFactory: (opts) {
          seen = opts.pubDevBaseUrl;
          return ProjectAnalyzer(
            options: opts,
            client: mockPubDevClient(packages: const {}),
          );
        },
      );
      await r.run(['--path', project.path, '--no-color', ...args]);
      return seen!;
    }

    test('defaults to pub.dev', () async {
      expect(await urlFor(const []), 'https://pub.dev');
    });

    test('PUB_HOSTED_URL is honoured and trailing slashes trimmed', () async {
      expect(
        await urlFor(const [],
            env: {'PUB_HOSTED_URL': 'https://mirror.example/'}),
        'https://mirror.example',
      );
    });

    test('precedence: CLI > config > environment', () async {
      const env = {'PUB_HOSTED_URL': 'https://env.example'};
      expect(
        await urlFor(const [],
            env: env, config: 'pub-url: https://cfg.example\n'),
        'https://cfg.example',
      );
      expect(
        await urlFor(
          const ['--pub-url', 'https://cli.example'],
          env: env,
          config: 'pub-url: https://cfg.example\n',
        ),
        'https://cli.example',
      );
    });
  });

  group('flag parsing', () {
    test('new flags are parsed into options', () {
      final cli = CliOptions.parse([
        '--baseline',
        'b.json',
        '--update-baseline',
        '--compare-to',
        'prev.json',
        '--no-cache',
        '--cache-dir',
        '/c',
        '--cache-ttl-hours',
        '2',
        '--offline',
        '--recursive',
        '--exclude-project',
        'x',
      ]);
      final o = cli.options;
      expect(o.baselinePath, 'b.json');
      expect(o.updateBaseline, isTrue);
      expect(o.compareTo, 'prev.json');
      expect(o.useCache, isFalse);
      expect(o.cacheDir, '/c');
      expect(o.cacheTtl, const Duration(hours: 2));
      expect(o.offline, isTrue);
      expect(o.recursive, isTrue);
      expect(o.excludeProjects, {'x'});
    });

    test('defaults are conservative', () {
      final o = CliOptions.parse(const []).options;
      expect(o.useCache, isTrue);
      expect(o.offline, isFalse);
      expect(o.recursive, isFalse);
      expect(o.updateBaseline, isFalse);
      expect(o.cacheTtl, const Duration(hours: 6));
    });

    test('invalid values are rejected', () {
      expect(
        () => CliOptions.parse(['--cache-ttl-hours', '0']),
        throwsA(isA<CliArgumentException>()),
      );
      expect(
        () => CliOptions.parse(['--cache-ttl-hours', 'x']),
        throwsA(isA<CliArgumentException>()),
      );
    });

    test('--compare-to prints the delta', () async {
      await run(
          ['--format', 'json', '--output', p.join(tmp.path, 'prev.json')]);
      out = MemorySink();
      await run([
        '--compare-to',
        p.join(tmp.path, 'prev.json'),
        '--no-color',
      ]);
      expect(out.buffer.toString(), contains('Compared to previous report'));
    });

    test('--compare-to with a missing file is a usage error', () async {
      expect(
        await run(['--compare-to', p.join(tmp.path, 'none.json')]),
        ExitCodes.invalidUsage,
      );
    });

    test('--recursive runs through the CLI', () async {
      final code = await runner().run([
        '--path',
        tmp.path,
        '--recursive',
        '--no-color',
        '--fail-on',
        'low',
      ]);
      expect(code, ExitCodes.findingsAboveThreshold);
      expect(out.buffer.toString(), contains('Projects analyzed: 1'));
      expect(out.buffer.toString(), contains('[proj]'));
    });

    test('help lists init and new options', () async {
      await runner().run(['--help']);
      final text = out.buffer.toString();
      for (final needle in [
        'pub_health init',
        '--baseline',
        '--update-baseline',
        '--offline',
        'recursive',
        '--compare-to',
        'sarif',
      ]) {
        expect(text, contains(needle));
      }
    });
  });
}
