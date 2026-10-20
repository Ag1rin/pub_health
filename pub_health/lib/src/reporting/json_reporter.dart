import 'dart:convert';

import '../models/dependency_report.dart';
import 'reporter.dart';

/// JSON reporter for CI and tooling integration.
class JsonReporter implements Reporter {
  /// Creates a JSON reporter.
  const JsonReporter({this.pretty = true});

  /// Whether to pretty-print JSON.
  final bool pretty;

  @override
  String report(DependencyReport report) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(report.toJson());
  }
}
