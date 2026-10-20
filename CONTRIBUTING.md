# Contributing to pub_health

Thanks for your interest in contributing.

## Development setup

```bash
dart pub get
dart format .
dart analyze
dart test
```

## Guidelines

1. Fork the repository and create a feature branch.
2. Keep changes focused and add tests for new behavior.
3. Do not automatically modify a user's `pubspec.yaml`.
4. Prefer deterministic, mocked pub.dev responses in tests.
5. Run format, analyze, and tests before opening a pull request.

## Reporting issues

Use the GitHub issue templates when possible. Include:

- Dart/Flutter SDK version
- `pub_health` version
- Minimal reproduction steps
- Whether the issue is a false positive
