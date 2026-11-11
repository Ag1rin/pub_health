import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:args/args.dart';

import '../analyzers/project_analyzer.dart';
import '../clients/pub_dev_client.dart';
import '../config/pub_health_config.dart';
import 'init_template.dart';
import '../models/pub_health_options.dart';
import '../utils/file_utils.dart';
import '../utils/yaml_utils.dart';
import '../version.dart';
import 'cli_options.dart';
import 'exit_codes.dart';

/// Top-level CLI command runner for pub_health.
class PubHealthCommandRunner {
  /// Creates a command runner.
  PubHealthCommandRunner({
    IOSink? stdoutSink,
    IOSink? stderrSink,
    ProjectAnalyzer? Function(PubHealthOptions options)? analyzerFactory,
    bool Function()? stdinHasTerminal,
    Map<String, String>? environment,
  })  : _environment = environment ?? Platform.environment,
        _stdout = stdoutSink ?? stdout,
        _stderr = stderrSink ?? stderr,
        _analyzerFactory = analyzerFactory,
        _stdinHasTerminal = stdinHasTerminal ?? (() => stdin.hasTerminal);

  final Map<String, String> _environment;
  final IOSink _stdout;
  final IOSink _stderr;
  final ProjectAnalyzer? Function(PubHealthOptions options)? _analyzerFactory;
  final bool Function() _stdinHasTerminal;

  /// Runs the CLI with [arguments] and returns an exit code.
  Future<int> run(List<String> arguments) async {
    final parser = CliOptions.buildParser();

    late final ArgResults raw;
    try {
      raw = parser.parse(arguments);
    } on FormatException catch (e) {
      _stderr.writeln('Error: ${e.message}');
      _stderr.writeln();
      _stderr.writeln(_usage(parser));
      return ExitCodes.invalidUsage;
    }

    if (raw['help'] == true) {
      _stdout.writeln(_usage(parser));
      return ExitCodes.success;
    }

    if (raw['version'] == true) {
      _stdout.writeln('pub_health $pubHealthVersion');
      return ExitCodes.success;
    }

    if (raw.rest.isNotEmpty && raw.rest.first == 'init') {
      return _runInit(raw);
    }

    final CliOptions cli;
    try {
      cli = CliOptions.parse(arguments);
    } on CliArgumentException catch (e) {
      _stderr.writeln('Error: $e');
      _stderr.writeln();
      _stderr.writeln(_usage(parser));
      return ExitCodes.invalidUsage;
    }

    final projectPath = FileUtils.absolute(cli.projectPath);
    final cliParsed = <String>{
      if (raw.wasParsed('fail-on')) 'fail-on',
      if (raw.wasParsed('include-transitive')) 'include-transitive',
      if (raw.wasParsed('stale-after-months')) 'stale-after-months',
      if (raw.wasParsed('timeout')) 'timeout',
      if (raw.wasParsed('format')) 'format',
      if (raw.wasParsed('output')) 'output',
      if (raw.wasParsed('color')) 'color',
      if (raw.wasParsed('baseline')) 'baseline',
      if (raw.wasParsed('cache')) 'cache',
      if (raw.wasParsed('cache-dir')) 'cache-dir',
      if (raw.wasParsed('offline')) 'offline',
      if (raw.wasParsed('recursive')) 'recursive',
      if (raw.wasParsed('pub-url')) 'pub-url',
    };

    PubHealthConfig config;
    try {
      config = await PubHealthConfig.load(projectPath);
    } on YamlParseException catch (e) {
      _stderr.writeln('Error: Invalid pub_health.yaml: ${e.message}');
      return ExitCodes.invalidUsage;
    } catch (e) {
      _stderr.writeln('Error: Failed to load pub_health.yaml: $e');
      return ExitCodes.invalidUsage;
    }

    for (final key in config.unknownKeys) {
      _stderr.writeln(
        'Warning: unknown key "$key" in pub_health.yaml (ignored).',
      );
    }

    var options = config.mergeWithCli(cli.options, cliParsed: cliParsed);

    // Precedence for the pub server: --pub-url > pub_health.yaml >
    // $PUB_HOSTED_URL (the variable `dart pub` itself honours) > pub.dev.
    final envUrl = _environment['PUB_HOSTED_URL'];
    if (!cliParsed.contains('pub-url') &&
        config.pubUrl == null &&
        envUrl != null &&
        envUrl.isNotEmpty) {
      options = options.copyWith(pubDevBaseUrl: envUrl);
    }
    options = options.copyWith(
      pubDevBaseUrl: options.pubDevBaseUrl.replaceAll(RegExp(r'/+$'), ''),
    );

    // A baseline named in pub_health.yaml is relative to the project, while
    // one given on the command line is relative to the working directory.
    final baseline = options.baselinePath;
    if (!cliParsed.contains('baseline') &&
        baseline != null &&
        !p.isAbsolute(baseline)) {
      options = options.copyWith(baselinePath: p.join(projectPath, baseline));
    }

    // Auto-disable color when not a terminal unless explicitly set.
    if (!cliParsed.contains('color') && !_stdinHasTerminal()) {
      options = options.copyWith(color: false);
    }

    if (options.verbose) {
      _stderr.writeln('Analyzing project at $projectPath …');
    }

    try {
      final analyzer =
          _analyzerFactory?.call(options) ?? ProjectAnalyzer(options: options);
      final report = options.recursive
          ? await analyzer.analyzeRecursive(projectPath)
          : await analyzer.analyze(projectPath);
      final reporter = createReporter(
        options.format,
        color: options.color,
        failOn: options.failOn,
        baseDirectory: projectPath,
      );
      final output = reporter.report(report);

      if (options.outputPath != null) {
        await FileUtils.writeText(options.outputPath!, output);
        if (options.verbose) {
          _stderr.writeln('Wrote report to ${options.outputPath}');
        }
      } else {
        _stdout.writeln(output);
      }

      if (hasFailingFindings(report.findings, options.failOn)) {
        return ExitCodes.findingsAboveThreshold;
      }
      return ExitCodes.success;
    } on ProjectAnalysisException catch (e) {
      _stderr.writeln('Error: ${e.message}');
      return ExitCodes.invalidUsage;
    } on YamlParseException catch (e) {
      _stderr.writeln('Error: ${e.message}');
      return ExitCodes.invalidUsage;
    } on PubDevClientException catch (e) {
      _stderr.writeln('Error: ${e.message}');
      return ExitCodes.networkFailure;
    } catch (e, st) {
      _stderr.writeln('Unexpected error: $e');
      if (options.verbose) {
        _stderr.writeln(st);
      }
      return ExitCodes.internalError;
    }
  }

  Future<int> _runInit(ArgResults raw) async {
    if (raw.rest.length > 1) {
      _stderr.writeln('Error: Unexpected arguments: '
          '${raw.rest.skip(1).join(', ')}');
      return ExitCodes.invalidUsage;
    }
    final projectPath = FileUtils.absolute(raw['path'] as String? ?? '.');
    if (!FileUtils.directoryExists(projectPath)) {
      _stderr.writeln('Error: Project path does not exist: $projectPath');
      return ExitCodes.invalidUsage;
    }
    final target = FileUtils.join(projectPath, 'pub_health.yaml');
    if (FileUtils.fileExists(target) && raw['force'] != true) {
      _stderr.writeln(
        'Error: $target already exists. Use --force to overwrite it.',
      );
      return ExitCodes.invalidUsage;
    }
    await FileUtils.writeText(target, initConfigTemplate);
    _stdout.writeln('Created $target');
    return ExitCodes.success;
  }

  String _usage(ArgParser parser) {
    return '''
pub_health — audit Dart/Flutter dependency health

Usage:
  pub_health [options]       Analyze a project
  pub_health init [--force]  Create a starter pub_health.yaml

Options:
${parser.usage}

Exit codes:
  0  Success, no findings at or above fail threshold
  1  Findings at or above fail threshold
  2  Invalid project or arguments
  3  Network/API failure
  4  Internal error
''';
  }
}
