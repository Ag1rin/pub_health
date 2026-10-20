import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_health/src/analyzers/project_analyzer.dart';
import 'package:pub_health/src/cli/command_runner.dart';
import 'package:pub_health/src/cli/exit_codes.dart';
import 'package:pub_health/src/models/pub_health_options.dart';
import 'package:test/test.dart';

import '../support/fixture_projects.dart';
import '../support/mock_pub_dev_client.dart';

class _MemorySink implements IOSink {
  final StringBuffer buffer = StringBuffer();

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) => buffer.write(utf8.decode(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  void write(Object? object) => buffer.write(object);

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      buffer.writeAll(objects, separator);

  @override
  void writeln([Object? object = '']) => buffer.writeln(object);

  @override
  void writeCharCode(int charCode) => buffer.writeCharCode(charCode);

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future flush() async {}

  @override
  Future close() async {}

  @override
  Future get done => Future.value();
}

void main() {
  late _MemorySink out;
  late _MemorySink err;

  setUp(() {
    out = _MemorySink();
    err = _MemorySink();
  });

  PubHealthCommandRunner runnerFor(PubHealthOptions options) {
    return PubHealthCommandRunner(
      stdoutSink: out,
      stderrSink: err,
      stdinHasTerminal: () => false,
      analyzerFactory: (opts) => ProjectAnalyzer(
        options: opts.copyWith(
          now: DateTime.utc(2026, 10, 20),
          pubDevBaseUrl: opts.pubDevBaseUrl,
        ),
        client: riskyFixtureClient(now: DateTime.utc(2026, 10, 20)),
      ),
    );
  }

  test('--help prints usage and exits 0', () async {
    final runner = PubHealthCommandRunner(
      stdoutSink: out,
      stderrSink: err,
      stdinHasTerminal: () => false,
    );
    final code = await runner.run(['--help']);
    expect(code, ExitCodes.success);
    expect(out.buffer.toString(), contains('pub_health'));
  });

  test('--version prints version', () async {
    final runner = PubHealthCommandRunner(
      stdoutSink: out,
      stderrSink: err,
      stdinHasTerminal: () => false,
    );
    final code = await runner.run(['--version']);
    expect(code, ExitCodes.success);
    expect(out.buffer.toString(), contains('0.1.0'));
  });

  test('invalid args return exit code 2', () async {
    final runner = PubHealthCommandRunner(
      stdoutSink: out,
      stderrSink: err,
      stdinHasTerminal: () => false,
    );
    final code = await runner.run(['--format', 'xml']);
    expect(code, ExitCodes.invalidUsage);
  });

  test('analyzes risky fixture and fails on high findings', () async {
    const fixture = 'test/fixtures/risky_project';
    await materializeRiskySources(fixture);
    addTearDown(() => cleanupRiskySources(fixture));

    final runner = runnerFor(const PubHealthOptions());
    final code = await runner.run([
      '--path',
      fixture,
      '--format',
      'json',
      '--fail-on',
      'high',
      '--no-color',
    ]);
    expect(code, ExitCodes.findingsAboveThreshold);
    final json = jsonDecode(out.buffer.toString()) as Map<String, dynamic>;
    expect(json['score'], lessThan(100));
    expect((json['findings'] as List).isNotEmpty, isTrue);
  });

  test('missing pubspec returns exit code 2', () async {
    final temp = await Directory.systemTemp.createTemp('pub_health_empty_');
    addTearDown(() => temp.delete(recursive: true));
    final runner = PubHealthCommandRunner(
      stdoutSink: out,
      stderrSink: err,
      stdinHasTerminal: () => false,
    );
    final code = await runner.run(['--path', temp.path]);
    expect(code, ExitCodes.invalidUsage);
    expect(err.buffer.toString(), contains('pubspec.yaml'));
  });

  test('writes report to output file', () async {
    const fixture = 'test/fixtures/risky_project';
    await materializeRiskySources(fixture);
    addTearDown(() => cleanupRiskySources(fixture));

    final temp = await Directory.systemTemp.createTemp('pub_health_out_');
    addTearDown(() => temp.delete(recursive: true));
    final output = p.join(temp.path, 'report.md');
    final runner = runnerFor(const PubHealthOptions());
    final code = await runner.run([
      '--path',
      fixture,
      '--format',
      'markdown',
      '--output',
      output,
      '--fail-on',
      'critical',
    ]);
    expect(code, anyOf(ExitCodes.success, ExitCodes.findingsAboveThreshold));
    expect(File(output).existsSync(), isTrue);
    expect(await File(output).readAsString(), contains('# pub_health report'));
  });

  test('healthy fixture with mocks scores highly', () async {
    final runner = PubHealthCommandRunner(
      stdoutSink: out,
      stderrSink: err,
      stdinHasTerminal: () => false,
      analyzerFactory: (opts) => ProjectAnalyzer(
        options: opts.copyWith(now: DateTime.utc(2026, 10, 20)),
        client: healthyFixtureClient(),
      ),
    );
    final code = await runner.run([
      '--path',
      'test/fixtures/healthy_project',
      '--format',
      'json',
      '--fail-on',
      'high',
    ]);
    expect(code, ExitCodes.success);
    final json = jsonDecode(out.buffer.toString()) as Map<String, dynamic>;
    expect(json['score'], greaterThanOrEqualTo(90));
  });
}
