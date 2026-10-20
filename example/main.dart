// Minimal library example for pub.dev.
//
// Run from the package root:
// `dart run example/main.dart`
import 'package:pub_health/pub_health.dart';

Future<void> main() async {
  final report = await analyzeProject(
    '.',
    options: const PubHealthOptions(
      failOn: Severity.high,
      staleAfterMonths: 18,
    ),
  );

  // ignore: avoid_print
  print('Score: ${report.healthScore.score}/100');
  // ignore: avoid_print
  print('Risk: ${report.healthScore.riskLevel}');

  for (final finding in report.findings) {
    // ignore: avoid_print
    print(
      '${finding.severity.name}: '
      '${finding.package} (${finding.ruleId})',
    );
  }
}
