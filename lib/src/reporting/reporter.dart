import '../models/dependency_report.dart';

/// Formats a [DependencyReport] for output.
abstract class Reporter {
  /// Renders [report] as a string.
  String report(DependencyReport report);
}
