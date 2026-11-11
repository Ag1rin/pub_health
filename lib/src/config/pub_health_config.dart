import '../models/ignore_rule.dart';
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
    this.ignores = const [],
    this.severityOverrides = const {},
    this.baselinePath,
    this.allowedLicenses = const {},
    this.deniedLicenses = const {},
    this.platforms = const {},
    this.requireWasm,
    this.cacheEnabled,
    this.cacheDir,
    this.cacheTtlHours,
    this.offline,
    this.recursive,
    this.excludeProjects = const {},
    this.unknownKeys = const [],
    this.pubUrl,
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

  /// Configured suppressions (`ignore:` section).
  final List<IgnoreRule> ignores;

  /// Per-rule severity overrides (`severity:` section).
  final Map<String, Severity> severityOverrides;

  /// Baseline file path (`baseline:`).
  final String? baselinePath;

  /// Allowed licenses (`licenses.allow`), lowercase SPDX ids.
  final Set<String> allowedLicenses;

  /// Denied licenses (`licenses.deny`), lowercase SPDX ids.
  final Set<String> deniedLicenses;

  /// Required target platforms (`platforms:`).
  final Set<String> platforms;

  /// Whether WebAssembly readiness is required (`wasm:`).
  final bool? requireWasm;

  /// Whether the on-disk cache is enabled (`cache.enabled`).
  final bool? cacheEnabled;

  /// On-disk cache directory (`cache.dir`).
  final String? cacheDir;

  /// Cache freshness in hours (`cache.ttl-hours`).
  final int? cacheTtlHours;

  /// Offline mode (`offline:`).
  final bool? offline;

  /// Recursive / workspace mode (`recursive:`).
  final bool? recursive;

  /// Project directories skipped in recursive mode (`exclude-projects:`).
  final Set<String> excludeProjects;

  /// pub server base URL (`pub-url:`).
  final String? pubUrl;

  /// Top-level keys that pub_health does not recognise (likely typos).
  final List<String> unknownKeys;

  /// Every top-level key understood by [parse].
  ///
  /// Kept in sync with `doc/pub_health.schema.json` by a test.
  static const Set<String> knownKeys = {
    'fail-on',
    'stale-after-months',
    'include-transitive',
    'exclude',
    'disable-rules',
    'disabled-rules',
    'report',
    'timeout',
    'ignore',
    'severity',
    'baseline',
    'licenses',
    'platforms',
    'wasm',
    'cache',
    'offline',
    'recursive',
    'exclude-projects',
    'pub-url',
  };

  /// Platforms accepted by the `platforms:` setting.
  static const Set<String> knownPlatforms = {
    'android',
    'ios',
    'web',
    'linux',
    'macos',
    'windows',
  };

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

    final exclude = _stringSet(map['exclude']);
    final disabledRules =
        _stringSet(map['disable-rules'] ?? map['disabled-rules']);

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

    final licenses = YamlUtils.readMap(map, 'licenses');
    final cache = YamlUtils.readMap(map, 'cache');
    final platforms = _stringSet(map['platforms'], lowercase: true);
    final unknownPlatforms = platforms.difference(knownPlatforms);
    if (unknownPlatforms.isNotEmpty) {
      throw YamlParseException(
        'Unknown platform(s) in "platforms": ${unknownPlatforms.join(', ')}. '
        'Expected: ${knownPlatforms.toList()..sort()}.',
      );
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
      ignores: _parseIgnores(map['ignore']),
      severityOverrides: _parseSeverityOverrides(map['severity']),
      baselinePath: YamlUtils.readString(map, 'baseline'),
      allowedLicenses: _stringSet(licenses?['allow'], lowercase: true),
      deniedLicenses: _stringSet(licenses?['deny'], lowercase: true),
      platforms: platforms,
      requireWasm: map['wasm'] is bool ? map['wasm'] as bool : null,
      cacheEnabled:
          cache?['enabled'] is bool ? cache!['enabled'] as bool : null,
      cacheDir: cache == null ? null : YamlUtils.readString(cache, 'dir'),
      cacheTtlHours: cache == null
          ? null
          : int.tryParse(cache['ttl-hours']?.toString() ?? ''),
      offline: map['offline'] is bool ? map['offline'] as bool : null,
      recursive: map['recursive'] is bool ? map['recursive'] as bool : null,
      excludeProjects: _stringSet(map['exclude-projects']),
      pubUrl: YamlUtils.readString(map, 'pub-url'),
      unknownKeys: [
        for (final key in map.keys)
          if (!knownKeys.contains(key.toString())) key.toString(),
      ],
    );
  }

  static Set<String> _stringSet(Object? node, {bool lowercase = false}) {
    final result = <String>{};
    if (node is Iterable) {
      for (final item in node) {
        final text = item.toString();
        result.add(lowercase ? text.toLowerCase() : text);
      }
    }
    return result;
  }

  static List<IgnoreRule> _parseIgnores(Object? node) {
    if (node == null) return const [];
    if (node is! Iterable) {
      throw YamlParseException('"ignore" must be a list of entries.');
    }
    final rules = <IgnoreRule>[];
    for (final item in node) {
      if (item is String) {
        // Shorthand: `- some_package` ignores every rule for that package.
        rules.add(IgnoreRule(package: item));
        continue;
      }
      if (item is! Map) {
        throw YamlParseException(
          'Each "ignore" entry must be a package name or a map.',
        );
      }
      final package = item['package']?.toString();
      if (package == null || package.isEmpty) {
        throw YamlParseException('Each "ignore" entry needs a "package".');
      }
      DateTime? expires;
      final expiresRaw = item['expires']?.toString();
      if (expiresRaw != null) {
        final parsed = DateTime.tryParse(expiresRaw);
        if (parsed == null) {
          throw YamlParseException(
            'Invalid "expires" date "$expiresRaw" for "$package" '
            '(expected YYYY-MM-DD).',
          );
        }
        // Compare calendar days only, always in UTC.
        expires = DateTime.utc(parsed.year, parsed.month, parsed.day);
      }
      rules.add(
        IgnoreRule(
          package: package,
          rule: item['rule']?.toString(),
          reason: item['reason']?.toString(),
          expires: expires,
        ),
      );
    }
    return rules;
  }

  static Map<String, Severity> _parseSeverityOverrides(Object? node) {
    if (node == null) return const {};
    if (node is! Map) {
      throw YamlParseException('"severity" must map rule IDs to severities.');
    }
    return {
      for (final entry in node.entries)
        entry.key.toString(): SeverityX.parse(entry.value.toString()),
    };
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
    final ttlHours = cacheTtlHours;
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
      pubDevBaseUrl: cliParsed.contains('pub-url')
          ? cliOptions.pubDevBaseUrl
          : (pubUrl ?? cliOptions.pubDevBaseUrl),
      disabledRules: {
        ...disabledRules,
        ...cliOptions.disabledRules,
      },
      concurrency: cliOptions.concurrency,
      projectSdkConstraint: cliOptions.projectSdkConstraint,
      now: cliOptions.now,
      ignores: [...ignores, ...cliOptions.ignores],
      severityOverrides: {
        ...severityOverrides,
        ...cliOptions.severityOverrides,
      },
      baselinePath: cliParsed.contains('baseline')
          ? cliOptions.baselinePath
          : (cliOptions.baselinePath ?? baselinePath),
      updateBaseline: cliOptions.updateBaseline,
      allowedLicenses: {...allowedLicenses, ...cliOptions.allowedLicenses},
      deniedLicenses: {...deniedLicenses, ...cliOptions.deniedLicenses},
      platforms: {...platforms, ...cliOptions.platforms},
      requireWasm: requireWasm ?? cliOptions.requireWasm,
      useCache: cliParsed.contains('cache')
          ? cliOptions.useCache
          : (cacheEnabled ?? cliOptions.useCache),
      cacheDir: cliParsed.contains('cache-dir')
          ? cliOptions.cacheDir
          : (cliOptions.cacheDir ?? cacheDir),
      cacheTtl: ttlHours != null && ttlHours > 0
          ? Duration(hours: ttlHours)
          : cliOptions.cacheTtl,
      offline: cliParsed.contains('offline')
          ? cliOptions.offline
          : (offline ?? cliOptions.offline),
      compareTo: cliOptions.compareTo,
      recursive: cliParsed.contains('recursive')
          ? cliOptions.recursive
          : (recursive ?? cliOptions.recursive),
      excludeProjects: {...excludeProjects, ...cliOptions.excludeProjects},
    );
  }
}
