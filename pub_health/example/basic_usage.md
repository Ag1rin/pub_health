# Basic usage

## Analyze the current project

```bash
dart run pub_health
```

## Produce JSON for CI

```bash
dart run pub_health --format json --fail-on high
```

## Save a Markdown report

```bash
dart run pub_health --format markdown --output pub_health_report.md
```

## Library usage

```dart
import 'package:pub_health/pub_health.dart';

Future<void> main() async {
  final report = await analyzeProject(
    '.',
    options: const PubHealthOptions(
      failOn: Severity.high,
      staleAfterMonths: 18,
    ),
  );

  print('Score: ${report.healthScore.score}/100');
  for (final finding in report.findings) {
    print('${finding.severity.name}: ${finding.package} (${finding.ruleId})');
  }
}
```

## Sample pub_health.yaml

```yaml
fail-on: high
stale-after-months: 18
include-transitive: true
exclude:
  - build_runner
  - flutter_lints
```
