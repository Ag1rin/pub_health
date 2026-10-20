# pub_health

[![pub package](https://img.shields.io/pub/v/pub_health.svg)](https://pub.dev/packages/pub_health)
[![likes](https://img.shields.io/pub/likes/pub_health)](https://pub.dev/packages/pub_health/score)
[![pub points](https://img.shields.io/pub/points/pub_health)](https://pub.dev/packages/pub_health/score)
[![popularity](https://img.shields.io/pub/popularity/pub_health)](https://pub.dev/packages/pub_health/score)
[![CI](https://github.com/Ag1rin/pub_health/actions/workflows/ci.yml/badge.svg)](https://github.com/Ag1rin/pub_health/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Dependency health audits for Dart and Flutter projects.**

`pub_health` scans `pubspec.yaml` and `pubspec.lock`, checks packages against
pub.dev, and produces a prioritized, CI-friendly report — without changing your
project files.

> Complements `dart pub outdated` with discontinued, retracted, stale,
> unused, and SDK-risk findings plus an overall health score.

## Quick start

```bash
dart pub global activate pub_health
pub_health
```

Or as a dev dependency:

```bash
dart pub add --dev pub_health
dart run pub_health
```

## Why pub_health?

| Question | Tool |
|---|---|
| Are newer versions available? | `dart pub outdated` |
| Which deps are risky, stale, unused, or discontinued? | **`pub_health`** |
| What should CI fail on? | **`pub_health --fail-on high`** |

## Features

- Detect outdated, discontinued, retracted, and stale packages
- Flag Dart SDK compatibility risks and low pub scores
- Find unused direct dependencies
- Score overall dependency health (0–100)
- Report as console, JSON, or Markdown
- Fail CI with meaningful exit codes
- Read-only by default — never mutates your project

## Usage

```bash
# Current directory
pub_health

# Another project
pub_health --path ./my_flutter_app

# JSON for CI / tooling
pub_health --format json

# Markdown report file
pub_health --format markdown --output pub_health_report.md

# Fail only on high or critical findings
pub_health --fail-on high

# Skip noisy packages
pub_health --exclude build_runner --exclude flutter_lints
```

### CLI options

| Flag | Default | Description |
|---|---|---|
| `--path` | `.` | Project directory to analyze |
| `--format` | `console` | `console`, `json`, or `markdown` |
| `--output` | — | Write report to a file |
| `--fail-on` | `high` | Minimum severity for exit code `1` |
| `--include-transitive` | `true` | Include transitive dependencies |
| `--exclude` | — | Package names to skip (repeatable) |
| `--stale-after-months` | `18` | Stale package threshold |
| `--timeout` | `20` | Network timeout in seconds |
| `--no-color` | — | Disable ANSI colors |
| `--verbose` | `false` | Verbose diagnostics |
| `--version` | — | Print version |
| `--help` | — | Print usage |

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Success — nothing at or above the fail threshold |
| `1` | Findings at or above the fail threshold |
| `2` | Invalid project, malformed YAML, or bad arguments |
| `3` | Network/API failure after retries |
| `4` | Internal unexpected error |

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

Precedence: **CLI flags → `pub_health.yaml` → built-in defaults**

## Rules

| Rule | Severity | Description |
|---|---|---|
| `outdated_dependency` | medium | A newer compatible version is available |
| `discontinued_package` | critical | The package is discontinued on pub.dev |
| `retracted_version` | high | The locked version is retracted |
| `stale_package` | medium | No release within the configured threshold |
| `sdk_constraint_risk` | high | SDK constraint may be incompatible |
| `low_package_score` | low | Package has a low pub.dev quality score |
| `unused_dependency` | medium | Direct dependency has no detected import |

## Library API

```dart
import 'package:pub_health/pub_health.dart';

final report = await analyzeProject(
  '.',
  options: const PubHealthOptions(failOn: Severity.high),
);

print(report.healthScore.score);
```

More examples: [example/basic_usage.md](example/basic_usage.md)

## Publishing (maintainers)

Releases use [Trusted Publishing](https://dart.dev/tools/pub/automated-publishing)
(OIDC) — no long-lived pub.dev token.

1. Bump `version` in `pubspec.yaml` and update `CHANGELOG.md`
2. Merge to `main`
3. Tag and push: `git tag v0.2.0 && git push origin v0.2.0`

The tag must match `v` + the `pubspec.yaml` version. Details:
[doc/releasing.md](doc/releasing.md)

## Roadmap

- **v0.2.0** — More accurate unused dependency detection
- **v0.3.0** — Alternative package suggestions
- **v0.4.0** — Security advisory integration
- **v0.5.0** — Android Gradle/AGP/Kotlin version matrix checks
- **v1.0.0** — Stable public API and plugin support

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and feature ideas welcome
via [GitHub Issues](https://github.com/Ag1rin/pub_health/issues).

## License

[MIT](LICENSE)
