import 'package:args/args.dart';

import '../models/pub_health_options.dart';
import '../models/severity.dart';

/// Parses and holds CLI arguments for pub_health.
class CliOptions {
  /// Creates CLI options.
  const CliOptions({
    required this.projectPath,
    required this.options,
    required this.showHelp,
    required this.showVersion,
  });

  /// Project path to analyze.
  final String projectPath;

  /// Resolved analysis options (CLI only; config merged later).
  final PubHealthOptions options;

  /// Whether `--help` was requested.
  final bool showHelp;

  /// Whether `--version` was requested.
  final bool showVersion;

  /// Builds the shared [ArgParser].
  static ArgParser buildParser() {
    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addFlag(
        'version',
        negatable: false,
        help: 'Show the pub_health version.',
      )
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: '.',
        help: 'Path to the Dart/Flutter project.',
      )
      ..addOption(
        'format',
        abbr: 'f',
        allowed: ['console', 'json', 'markdown'],
        help: 'Output format.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Write the report to a file.',
      )
      ..addOption(
        'fail-on',
        allowed: ['low', 'medium', 'high', 'critical'],
        help: 'Minimum severity that causes a non-zero exit code.',
      )
      ..addFlag(
        'include-transitive',
        defaultsTo: null,
        help: 'Include transitive dependencies in analysis.',
      )
      ..addMultiOption(
        'exclude',
        help: 'Package names to exclude from analysis.',
      )
      ..addOption(
        'stale-after-months',
        help: 'Months without a release before a package is stale.',
      )
      ..addOption(
        'timeout',
        help: 'Network timeout in seconds.',
      )
      ..addFlag(
        'color',
        defaultsTo: null,
        help: 'Enable ANSI colors in console output.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Enable verbose logging.',
      )
      ..addMultiOption(
        'disable-rule',
        help: 'Rule IDs to disable.',
      );
  }

  /// Parses [arguments] into [CliOptions].
  static CliOptions parse(List<String> arguments) {
    final parser = buildParser();
    final ArgResults results;
    try {
      results = parser.parse(arguments);
    } on FormatException catch (e) {
      throw CliArgumentException(e.message);
    }

    if (results.rest.isNotEmpty) {
      throw CliArgumentException(
        'Unexpected arguments: ${results.rest.join(', ')}',
      );
    }

    final exclude = (results['exclude'] as List<String>).toSet();
    final disabled =
        (results['disable-rule'] as List<String>? ?? const []).toSet();

    ReportFormat? format;
    if (results.wasParsed('format')) {
      format = ReportFormatX.parse(results['format'] as String);
    }

    Severity? failOn;
    if (results.wasParsed('fail-on')) {
      failOn = SeverityX.parse(results['fail-on'] as String);
    }

    int? staleAfterMonths;
    if (results.wasParsed('stale-after-months')) {
      staleAfterMonths = int.tryParse(results['stale-after-months'] as String);
      if (staleAfterMonths == null || staleAfterMonths <= 0) {
        throw CliArgumentException(
          'Invalid --stale-after-months value.',
        );
      }
    }

    Duration? timeout;
    if (results.wasParsed('timeout')) {
      final seconds = int.tryParse(results['timeout'] as String);
      if (seconds == null || seconds <= 0) {
        throw CliArgumentException('Invalid --timeout value.');
      }
      timeout = Duration(seconds: seconds);
    }

    bool? includeTransitive;
    if (results.wasParsed('include-transitive')) {
      includeTransitive = results['include-transitive'] as bool;
    }

    bool? color;
    if (results.wasParsed('color')) {
      color = results['color'] as bool;
    }

    final options = PubHealthOptions(
      failOn: failOn ?? Severity.high,
      includeTransitive: includeTransitive ?? true,
      exclude: exclude,
      staleAfterMonths: staleAfterMonths ?? 18,
      timeout: timeout ?? const Duration(seconds: 20),
      color: color ?? true,
      verbose: results['verbose'] as bool? ?? false,
      format: format ?? ReportFormat.console,
      outputPath: results['output'] as String?,
      disabledRules: disabled,
    );

    return CliOptions(
      projectPath: results['path'] as String? ?? '.',
      options: options,
      showHelp: results['help'] as bool? ?? false,
      showVersion: results['version'] as bool? ?? false,
    );
  }
}

/// Thrown when CLI arguments are invalid.
class CliArgumentException implements Exception {
  /// Creates an argument exception.
  CliArgumentException(this.message);

  /// Error message.
  final String message;

  @override
  String toString() => message;
}
