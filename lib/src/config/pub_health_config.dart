import '../models/pub_health_options.dart';
import '../models/severity.dart';
import '../utils/file_utils.dart';
import '../utils/yaml_utils.dart';

/// Loads optional `pub_health.yaml` configuration.
class PubHealthConfig {
  /// Creates a config snapshot.
  const PubHealthConfig({
    this.failOn,
    this.staleAfterMonths,
    this.includeTransitive,
    this.exclude = const {},
    this.format,
    this.outputPath,
    this.disabledRules = const {},
    this.timeoutSeconds,
  });

  /// Fail-on severity from config.
  final Severity? failOn;

  /// Stale threshold in months.
  final int? staleAfterMonths;

  /// Whether to include transitive deps.
  final bool? includeTransitive;

  /// Excluded package names.
  final Set<String> exclude;

  /// Report format.
  final ReportFormat? format;

  /// Output path.
  final String? outputPath;

  /// Disabled rule IDs.
  final Set<String> disabledRules;

  /// Network timeout in seconds.
  final int? timeoutSeconds;

  /// Loads config from [projectPath]/pub_health.yaml if present.
  static Future<PubHealthConfig> load(String projectPath) async {
    final path = FileUtils.join(projectPath, 'pub_health.yaml');
    final content = await FileUtils.readText(path);
    if (content == null) return const PubHealthConfig();
    return parse(content);
  }

  /// Parses a config YAML document.
  static PubHealthConfig parse(String content) {
    final map = YamlUtils.parseMap(content);

    Severity? failOn;
    final failOnRaw = YamlUtils.readString(map, 'fail-on');
    if (failOnRaw != null) {
      failOn = SeverityX.parse(failOnRaw);
    }

    int? staleAfterMonths;
    final staleRaw = map['stale-after-months'];
    if (staleRaw != null) {
      staleAfterMonths = int.tryParse(staleRaw.toString());
    }

    bool? includeTransitive;
    final includeRaw = map['include-transitive'];
    if (includeRaw is bool) {
      includeTransitive = includeRaw;
    }

    final exclude = <String>{};
    final excludeNode = map['exclude'];
    if (excludeNode is Iterable) {
      for (final item in excludeNode) {
        exclude.add(item.toString());
      }
    }

    final disabledRules = <String>{};
    final disabledNode = map['disable-rules'] ?? map['disabled-rules'];
    if (disabledNode is Iterable) {
      for (final item in disabledNode) {
        disabledRules.add(item.toString());
      }
    }

    ReportFormat? format;
    String? outputPath;
    final report = YamlUtils.readMap(map, 'report');
    if (report != null) {
      final formatRaw = YamlUtils.readString(report, 'format');
      if (formatRaw != null) {
        format = ReportFormatX.parse(formatRaw);
      }
      outputPath = YamlUtils.readString(report, 'output');
    }

    int? timeoutSeconds;
    final timeoutRaw = map['timeout'];
    if (timeoutRaw != null) {
      timeoutSeconds = int.tryParse(timeoutRaw.toString());
    }

    return PubHealthConfig(
      failOn: failOn,
      staleAfterMonths: staleAfterMonths,
      includeTransitive: includeTransitive,
      exclude: exclude,
      format: format,
      outputPath: outputPath,
      disabledRules: disabledRules,
      timeoutSeconds: timeoutSeconds,
    );
  }

  /// Merges config under CLI [cliOptions].
  ///
  /// Precedence: CLI flags > config file > built-in defaults.
  ///
  /// [cliParsed] indicates which CLI flags were explicitly provided.
  PubHealthOptions mergeWithCli(
    PubHealthOptions cliOptions, {
    required Set<String> cliParsed,
  }) {
    return PubHealthOptions(
      failOn: cliParsed.contains('fail-on')
          ? cliOptions.failOn
          : (failOn ?? cliOptions.failOn),
      includeTransitive: cliParsed.contains('include-transitive')
          ? cliOptions.includeTransitive
          : (includeTransitive ?? cliOptions.includeTransitive),
      exclude: {
        ...exclude,
        ...cliOptions.exclude,
      },
      staleAfterMonths: cliParsed.contains('stale-after-months')
          ? cliOptions.staleAfterMonths
          : (staleAfterMonths ?? cliOptions.staleAfterMonths),
      timeout: cliParsed.contains('timeout')
          ? cliOptions.timeout
          : (timeoutSeconds != null
              ? Duration(seconds: timeoutSeconds!)
              : cliOptions.timeout),
      color: cliOptions.color,
      verbose: cliOptions.verbose,
      format: cliParsed.contains('format')
          ? cliOptions.format
          : (format ?? cliOptions.format),
      outputPath: cliParsed.contains('output')
          ? cliOptions.outputPath
          : (cliOptions.outputPath ?? outputPath),
      pubDevBaseUrl: cliOptions.pubDevBaseUrl,
      disabledRules: {
        ...disabledRules,
        ...cliOptions.disabledRules,
      },
      concurrency: cliOptions.concurrency,
      projectSdkConstraint: cliOptions.projectSdkConstraint,
      now: cliOptions.now,
    );
  }
}
