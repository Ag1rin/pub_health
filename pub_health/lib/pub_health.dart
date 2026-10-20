/// Audit the dependency health of Dart and Flutter projects.
///
/// Scan `pubspec.yaml` and `pubspec.lock`, query pub.dev metadata, detect
/// dependency risks, calculate a health score, and produce reports.
library;

export 'src/models/dependency.dart';
export 'src/models/dependency_kind.dart';
export 'src/models/dependency_report.dart';
export 'src/models/health_finding.dart';
export 'src/models/health_score.dart';
export 'src/models/pub_dev_package_info.dart';
export 'src/models/pub_health_options.dart';
export 'src/models/severity.dart';
export 'src/analyzers/project_analyzer.dart' show analyzeProject;
