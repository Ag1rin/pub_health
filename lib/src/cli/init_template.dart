/// Starter `pub_health.yaml` written by `pub_health init`.
const String initConfigTemplate = r'''
# yaml-language-server: $schema=https://raw.githubusercontent.com/Ag1rin/pub_health/main/doc/pub_health.schema.json
#
# pub_health configuration. CLI flags override these values.
# Full reference: https://github.com/Ag1rin/pub_health#configuration

# Minimum severity that makes the command exit with code 1.
fail-on: high

# Months without a release before a package is reported as stale.
stale-after-months: 18

# Analyze transitive dependencies from pubspec.lock too.
include-transitive: true

# Packages that are never reported.
# exclude:
#   - build_runner

# Rules to turn off entirely.
# disable-rules:
#   - unverified_publisher

# Change the severity of a rule.
# severity:
#   stale_package: low
#   dependency_override: high

# Suppress known findings. Always say why, and prefer an expiry date.
# ignore:
#   - package: legacy_lib
#     rule: stale_package
#     reason: Vendored fork tracked in ISSUE-123
#     expires: "2027-06-30"   # quote dates so every YAML tool reads a string

# Record today's findings and only fail on new ones:
#   pub_health --baseline pub_health_baseline.json --update-baseline
# baseline: pub_health_baseline.json

# License policy (lowercase SPDX ids, as shown on pub.dev).
# licenses:
#   allow: [mit, bsd-3-clause, apache-2.0]
#   deny: [gpl-3.0, agpl-3.0]

# Platforms direct dependencies must support, and optional Wasm readiness.
# platforms: [android, ios, web]
# wasm: true

# On-disk pub.dev cache.
# cache:
#   enabled: true
#   ttl-hours: 6

# Analyze every Dart project below the path (monorepo / pub workspace).
# recursive: false
# exclude-projects:
#   - examples/legacy
''';
