import '../models/dependency.dart';
import '../models/health_finding.dart';
import '../models/pub_dev_package_info.dart';
import '../models/pub_health_options.dart';

/// Shared context passed to every rule.
class RuleContext {
  /// Creates a rule evaluation context.
  const RuleContext({ // ignore: prefer_const_constructors_in_immutables

    required this.projectPath,
    required this.dependencies,
    required this.packageInfo,
    required this.unusedPackages,
    required this.options,
    this.projectSdkConstraint,
  });

  /// Absolute project path.
  final String projectPath;

  /// All dependencies under consideration.
  final List<Dependency> dependencies;

  /// pub.dev metadata keyed by package name.
  final Map<String, PubDevPackageInfo> packageInfo;

  /// Direct dependencies detected as unused.
  final Set<String> unusedPackages;

  /// Analysis options.
  final PubHealthOptions options;

  /// Project Dart SDK constraint from pubspec.
  final String? projectSdkConstraint;

  /// Returns package info for [name], if fetched.
  PubDevPackageInfo? infoFor(String name) => packageInfo[name];

  /// Dependencies that should be evaluated by hosted-package rules.
  Iterable<Dependency> get hostedDependencies => dependencies.where(
        (d) =>
            !d.isSdk &&
            d.source == 'hosted' &&
            !options.exclude.contains(d.name),
      );
}

/// A single dependency health rule.
abstract class Rule {
  /// Creates a rule.
  const Rule();

  /// Stable rule identifier.
  String get id;

  /// Human-readable rule name.
  String get name;

  /// Evaluates the rule and returns zero or more findings.
  List<HealthFinding> evaluate(RuleContext context);
}
