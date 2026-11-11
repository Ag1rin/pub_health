# CI integration

`pub_health` exits with `0` when nothing reaches `--fail-on`, `1` when findings
do, and `2`–`4` for real errors (see the README). Every example below relies on
that, so a failing dependency audit fails the job.

## GitHub Actions

### The composite action

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

Inputs: `path`, `format`, `output`, `fail-on`, `fail-on-findings`,
`recursive`, `baseline`, `summary`, `version`, `dart-sdk`, `args`.
Outputs: `score`, `risk-level`, `exit-code`, `report-path`.

The action writes a Markdown report to the job summary and passes every input
through environment variables (never straight into the shell script).

### Code scanning (SARIF)

Findings show up as annotations on `pubspec.yaml` and in the repository's
**Security → Code scanning** tab.

```yaml
permissions:
  contents: read
  security-events: write

jobs:
  pub-health:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: Ag1rin/pub_health@v0.2.0
        with:
          format: sarif
          output: pub_health.sarif
          fail-on-findings: "false" # let the upload step run first
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: pub_health.sarif
```

SARIF paths are relative to the directory you run `pub_health` from, so run it
at the repository root.

### Adopt on an existing project: baseline

Record today's findings once, commit the file, and fail only on *new* ones:

```bash
pub_health --baseline pub_health_baseline.json --update-baseline
git add pub_health_baseline.json
```

```yaml
      - uses: Ag1rin/pub_health@v0.2.0
        with:
          baseline: pub_health_baseline.json
```

When a baselined finding is fixed, pub_health tells you the entry no longer
applies; re-run with `--update-baseline` to prune it.

### Comment the report on pull requests

```yaml
permissions:
  contents: read
  pull-requests: write

jobs:
  pub-health:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: Ag1rin/pub_health@v0.2.0
        id: audit
        with:
          format: markdown
          output: pub_health.md
          fail-on-findings: "false"
      - if: github.event_name == 'pull_request'
        env:
          GH_TOKEN: ${{ github.token }}
        run: gh pr comment ${{ github.event.pull_request.number }} --body-file pub_health.md
      - if: steps.audit.outputs.exit-code != '0'
        run: exit 1
```

### Cache pub.dev responses

pub_health keeps a six-hour on-disk cache. Persist it between runs to make
audits faster and independent of pub.dev outages:

```yaml
      - uses: actions/cache@v4
        with:
          path: ~/.cache/pub_health
          key: pub-health-${{ github.run_id }}
          restore-keys: pub-health-
```

### Score badge

`--format badge` writes a [shields.io endpoint](https://shields.io/badges/endpoint-badge)
document. Publish it (GitHub Pages, a gist, an artifact branch) and reference it:

```markdown
![dependency health](https://img.shields.io/endpoint?url=https://example.github.io/my_app/pub_health_badge.json)
```

### Compare with the default branch

Save the JSON report from `main` and compare a PR against it:

```bash
pub_health --format json --output main_report.json            # on main
pub_health --compare-to main_report.json --fail-on critical   # on the PR
```

The report then includes the score delta plus new and resolved findings.

## Without the action

```yaml
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate pub_health
      - run: pub_health --fail-on high
```

## GitLab CI

JUnit output appears in the merge-request test report.

```yaml
pub_health:
  image: dart:stable
  script:
    - dart pub global activate pub_health
    - export PATH="$PATH:$HOME/.pub-cache/bin"
    - pub_health --format junit --output pub_health.xml --fail-on high
  artifacts:
    when: always
    reports:
      junit: pub_health.xml
```

## Azure Pipelines

```yaml
steps:
  - script: |
      dart pub global activate pub_health
      export PATH="$PATH:$HOME/.pub-cache/bin"
      pub_health --format junit --output $(Build.ArtifactStagingDirectory)/pub_health.xml
    displayName: Audit dependencies
    continueOnError: true
  - task: PublishTestResults@2
    condition: always()
    inputs:
      testResultsFormat: JUnit
      testResultsFiles: $(Build.ArtifactStagingDirectory)/pub_health.xml
```

## Bitbucket Pipelines

```yaml
pipelines:
  default:
    - step:
        image: dart:stable
        script:
          - dart pub global activate pub_health
          - export PATH="$PATH:$HOME/.pub-cache/bin"
          - pub_health --fail-on high
```

## Monorepos and pub workspaces

```bash
pub_health --recursive
```

Every `pubspec.yaml` below the path is analyzed (hidden directories, `build/`
and `--exclude-project` paths are skipped). Workspace members that have no
`pubspec.lock` of their own use the workspace root's lockfile. The overall score
is the *lowest* project score; findings carry a `[project]` label, and issues
that come from a shared lockfile are reported once.

## Private mirrors and offline runs

```bash
pub_health --pub-url https://pub.flutter-io.cn   # or set PUB_HOSTED_URL
pub_health --offline                             # only use the on-disk cache
```

Precedence: `--pub-url` → `pub-url:` in `pub_health.yaml` → `PUB_HOSTED_URL` →
`https://pub.dev`. Offline mode never touches the network; packages missing from
the cache are skipped with a note, and rules that need no network data
(overrides, git dependencies, constraints, misplaced dependencies) still run.
