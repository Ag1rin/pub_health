# Examples

## CLI

```bash
dart pub global activate pub_health
pub_health
pub_health --format json --fail-on high
```

## Library

See [`main.dart`](main.dart):

```dart
import 'package:pub_health/pub_health.dart';

Future<void> main() async {
  final report = await analyzeProject(
    '.',
    options: const PubHealthOptions(failOn: Severity.high),
  );
  print(report.healthScore.score);
}
```

More notes: [basic_usage.md](basic_usage.md)
