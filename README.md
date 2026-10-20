# pub_health

[![pub package](https://img.shields.io/pub/v/pub_health.svg)](https://pub.dev/packages/pub_health)
[![Dart SDK](https://img.shields.io/badge/Dart-3.5%2B-blue.svg)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/Ag1rin/pub_health/actions/workflows/ci.yml/badge.svg)](https://github.com/Ag1rin/pub_health/actions)

`pub_health` audits the dependency health of Dart and Flutter projects.

It scans your `pubspec.yaml` and `pubspec.lock`, checks dependencies
against pub.dev metadata, and reports outdated, discontinued, retracted,
stale, low-quality, and unused packages.

Unlike `dart pub outdated`, `pub_health` gives you a prioritized,
CI-friendly dependency health report.

## Features

- Detect outdated dependencies.
- Detect discontinued packages.
- Detect retracted package versions.
- Detect stale packages.
- Detect Dart SDK compatibility risks.
- Detect unused direct dependencies.
- Calculate an overall dependency health score.
- Generate console, JSON, and Markdown reports.
- Work in CI with meaningful exit codes.
- Read-only by default: it never changes your project automatically.

## Installation

Activate globally:

```bash
dart pub global activate pub_health
```

Then run:

```bash
pub_health
```

You can also add it as a dev dependency:

```bash
dart pub add --dev pub_health
```

Then run:

```bash
dart run pub_health
```

## Usage

Run in the current project:

```bash
pub_health
```

Specify a project path:

```bash
pub_health --path ./my_flutter_app
```

Generate JSON:

```bash
pub_health --format json
```

Save a Markdown report:

```bash
pub_health --format markdown --output pub_health_report.md
```

Fail CI only for high or critical findings:

```bash
pub_health --fail-on high
```

Exclude packages:

```bash
pub_health --exclude build_runner --exclude flutter_lints
```

### CLI options

| Flag | Default | Description |
|---|---|---|
| `--path` | `.` | Project directory to analyze |
| `--format` | `console` | `console`, `json`, or `markdown` |
| `--output` | — | Write report to a file |
| `--fail-on` | `high` | Minimum severity for exit code 1 |
| `--include-transitive` | `true` | Include transitive dependencies |
| `--exclude` | — | Package names to skip |
| `--stale-after-months` | `18` | Stale package threshold |
| `--timeout` | `20` | Network timeout in seconds |
| `--no-color` | — | Disable ANSI colors |
| `--verbose` | `false` | Verbose diagnostics |
| `--version` | — | Print version |
| `--help` | — | Print usage |

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success, no findings at or above fail threshold |
| 1 | Findings at or above fail threshold |
| 2 | Invalid project, malformed YAML, or bad arguments |
| 3 | Network/API failure after retries |
| 4 | Internal unexpected error |

## Example output

```text
pub_health report

Project: /Users/dev/my_flutter_app
Generated: 2026-10-20 12:00:00 UTC

CRITICAL
✖ firebase_messaging 14.7.10
  Rule: discontinued_package
  The package is marked as discontinued on pub.dev.
  Recommendation: Find an actively maintained alternative.

HIGH
⚠ http 0.13.6
  Rule: sdk_constraint_risk
  Current SDK constraint may not support the project's Dart SDK.
  Recommendation: Update the dependency or review SDK constraints.

MEDIUM
⚠ cached_network_image 3.3.1
  Rule: stale_package
  Last release: 19 months ago.

Overall dependency health: 58/100
Risk level: Poor
```

## CI integration

Create `.github/workflows/pub-health.yml`:

```yaml
name: Dependency health

on:
  push:
    branches: [main]
  pull_request:

jobs:
  pub-health:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      - run: dart pub global activate pub_health
      - run: pub_health --format json --fail-on high
```

## Configuration

Create `pub_health.yaml` in the project root:

```yaml
fail-on: high
stale-after-months: 18
include-transitive: true
exclude:
  - build_runner
  - flutter_lints
  - test
report:
  format: console
  output: null
```

Precedence:

1. CLI flags
2. `pub_health.yaml`
3. Built-in defaults

## Rules

| Rule | Severity | Description |
|---|---|---|
| outdated_dependency | medium | A newer compatible version is available |
| discontinued_package | critical | The package is discontinued on pub.dev |
| retracted_version | high | The locked version is retracted |
| stale_package | medium | No release for the configured threshold |
| sdk_constraint_risk | high | SDK constraint may be incompatible |
| low_package_score | low | Package has a low pub.dev quality score |
| unused_dependency | medium | Direct dependency has no detected import |

## Library API

```dart
import 'package:pub_health/pub_health.dart';

final report = await analyzeProject(
  '.',
  options: const PubHealthOptions(failOn: Severity.high),
);

print(report.healthScore.score);
```

## Why pub_health?

`dart pub outdated` is excellent for checking available updates.
`pub_health` complements it by answering broader questions:

- Which dependencies are risky?
- Which packages are discontinued or retracted?
- Which packages have not been maintained recently?
- Which direct dependencies are unused?
- What is the overall dependency health of this project?
- What should CI fail on?

## Roadmap

- v0.2.0: More accurate unused dependency detection.
- v0.3.0: Alternative package suggestions.
- v0.4.0: Security advisory integration.
- v0.5.0: Android Gradle/AGP/Kotlin version matrix checks.
- v1.0.0: Stable public API and plugin support.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
