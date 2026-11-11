# pub_health

[![pub package](https://img.shields.io/pub/v/pub_health.svg)](https://pub.dev/packages/pub_health)
[![likes](https://img.shields.io/pub/likes/pub_health)](https://pub.dev/packages/pub_health/score)
[![pub points](https://img.shields.io/pub/points/pub_health)](https://pub.dev/packages/pub_health/score)
[![CI](https://github.com/Ag1rin/pub_health/actions/workflows/ci.yml/badge.svg)](https://github.com/Ag1rin/pub_health/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Dependency health audits for Dart and Flutter projects.**

`pub_health` scans `pubspec.yaml` and `pubspec.lock`, checks packages against
pub.dev, and produces a prioritized, CI-friendly report — without changing your
project files.

> Complements `dart pub outdated` with discontinued, retracted, stale,
> unused, and SDK-risk findings plus an overall health score.

![pub_health auditing a project, then adopting a baseline so CI only fails on new findings](doc/demo.gif)

<sub>Demo with sample data: the package names are fictional and pub.dev is
simulated, but the output is produced by the real CLI.</sub>

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
- Find unused direct dependencies and dependencies in the wrong section
- Catch risky declarations: `dependency_overrides`, git dependencies, `any`
  constraints
- Check licenses against your policy, and platform / WebAssembly support
- Score overall dependency health (0–100) with per-category scores
- Report as console, JSON, Markdown, **SARIF**, **HTML**, **JUnit** or a
  **badge**
- Adopt gradually with **baselines** and `ignore:` entries that carry a reason
  and an expiry date
- Suggest the exact `dart pub …` command to fix each finding
- Analyze monorepos and pub workspaces (`--recursive`)
- Cache pub.dev responses on disk; work offline or through a mirror
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

# SARIF for GitHub code scanning
pub_health --format sarif --output pub_health.sarif

# Self-contained HTML report
pub_health --format html --output pub_health.html

# Fail only on high or critical findings
pub_health --fail-on high

# Skip noisy packages
pub_health --exclude build_runner --exclude flutter_lints

# Create a documented pub_health.yaml
pub_health init

# Adopt on an existing project: only fail on NEW findings
pub_health --baseline pub_health_baseline.json --update-baseline
pub_health --baseline pub_health_baseline.json

# Monorepo / pub workspace
pub_health --recursive

# How did the score change since the last report?
pub_health --compare-to previous_report.json
```

### CLI options

| Flag | Default | Description |
|---|---|---|
| `--path` | `.` | Project directory to analyze |
| `--format` | `console` | `console`, `json`, `markdown`, `sarif`, `html`, `junit`, or `badge` |
| `--output` | — | Write report to a file |
| `--fail-on` | `high` | Minimum severity for exit code `1` |
| `--include-transitive` | `true` | Include transitive dependencies |
| `--exclude` | — | Package names to skip (repeatable) |
| `--disable-rule` | — | Rule IDs to skip (repeatable) |
| `--stale-after-months` | `18` | Stale package threshold |
| `--timeout` | `20` | Network timeout in seconds |
| `--baseline` | — | Baseline file; recorded findings are suppressed |
| `--update-baseline` | `false` | Write current findings to the `--baseline` file |
| `--compare-to` | — | Previous JSON report to compare against |
| `--recursive`, `-r` | `false` | Analyze every Dart project below `--path` |
| `--exclude-project` | — | Directory to skip in recursive mode (repeatable) |
| `--[no-]cache` | on | Use the on-disk pub.dev cache |
| `--cache-dir` | platform default | Cache directory (`PUB_HEALTH_CACHE_DIR` also works) |
| `--cache-ttl-hours` | `6` | How long cached responses stay fresh |
| `--offline` | `false` | Never use the network; rely on the cache |
| `--pub-url` | `$PUB_HOSTED_URL` or `https://pub.dev` | pub server / mirror base URL |
| `--no-color` | — | Disable ANSI colors |
| `--verbose` | `false` | Verbose diagnostics |
| `--version` | — | Print version |
| `--help` | — | Print usage |

Commands: `pub_health init [--force] [--path dir]` writes a starter
`pub_health.yaml`.

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
      - uses: Ag1rin/pub_health@v0.2.0
        with:
          fail-on: high
```

Or without the action:

```yaml
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate pub_health
      - run: pub_health --fail-on high
```

Recipes for **code scanning (SARIF)**, **PR comments**, **baselines**,
**caching**, **badges**, **GitLab**, **Azure Pipelines**, **Bitbucket**, and
monorepos are in [doc/ci.md](doc/ci.md).

## Configuration

Run `pub_health init` to generate a commented `pub_health.yaml`, or write one:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Ag1rin/pub_health/main/doc/pub_health.schema.json

fail-on: high
stale-after-months: 18
include-transitive: true

exclude:
  - build_runner
disable-rules:
  - unverified_publisher

# Change how serious a rule is
severity:
  stale_package: low
  dependency_override: high

# Suppress known findings — say why, and prefer an expiry date.
# Quote dates so every YAML tool reads them as strings.
ignore:
  - package: legacy_lib
    rule: stale_package        # omit to ignore every rule for the package
    reason: Vendored fork, tracked in ISSUE-123
    expires: "2027-06-30"

baseline: pub_health_baseline.json

licenses:
  allow: [mit, bsd-3-clause, apache-2.0]
  deny: [gpl-3.0, agpl-3.0]

platforms: [android, ios, web]
wasm: true

cache:
  enabled: true
  ttl-hours: 6

report:
  format: console
```

Precedence: **CLI flags → `pub_health.yaml` → built-in defaults**.
Unknown keys and unknown rule IDs produce a warning instead of being silently
ignored. A JSON Schema for editors lives in
[doc/pub_health.schema.json](doc/pub_health.schema.json).

### Ignores and baselines

- An **ignore** hides findings for a package (optionally for one rule). Expired
  ignores stop applying and are reported; ignores that match nothing are
  reported so you can delete them.
- A **baseline** is a snapshot of accepted findings. Create it with
  `--update-baseline`, commit it, and CI fails only on new problems. Entries
  that no longer apply are reported so you can prune them.
- Suppressed findings never affect the score or the exit code; they are counted
  in the report (`suppressedCount` in JSON).

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
| `dependency_override` | medium (low for `path`) | `dependency_overrides` bypasses version resolution |
| `git_dependency` | low | Dependency is fetched from git, not pub.dev |
| `unconstrained_dependency` | medium / low | `any` or missing constraint (medium), open upper bound (low) |
| `misplaced_dependency` | medium / low | Dev dependency used in `lib/`/`bin/` (medium); tooling package under `dependencies` (low) |
| `license_risk` | medium / high | Unknown license (medium); denied or not allowed by your policy (high) |
| `platform_support` | medium / low | Missing a configured platform (medium); not Wasm-ready (low) |
| `unverified_publisher` | low | Fewer than 100 likes and no verified publisher |

Rules that rely on pub.dev tags (`license_risk`, `platform_support`,
`unverified_publisher`) never judge a package whose tag data is missing.
`platform_support` does nothing unless `platforms:` or `wasm: true` is set.

Findings are grouped into four score categories: `maintenance`,
`compatibility`, `hygiene`, and `licensing`.

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

- **v0.2.0** — Baselines and ignores, new hygiene/license/platform rules,
  SARIF/HTML/JUnit/badge output, caching and offline mode, monorepo support
  (this release)
- **Next** — More accurate unused dependency detection
- **v0.3.0** — Alternative package suggestions
- **v0.4.0** — Security advisory integration
- **v0.5.0** — Android Gradle/AGP/Kotlin version matrix checks
- **v1.0.0** — Stable public API and plugin support

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and feature ideas welcome
via [GitHub Issues](https://github.com/Ag1rin/pub_health/issues).

## License

[MIT](LICENSE)
