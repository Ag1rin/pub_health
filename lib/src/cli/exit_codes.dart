/// Process exit codes used by the pub_health CLI.
class ExitCodes {
  /// Success — no findings at or above the fail threshold.
  static const int success = 0;

  /// Findings at or above the fail threshold.
  static const int findingsAboveThreshold = 1;

  /// Invalid project, malformed YAML, or invalid CLI arguments.
  static const int invalidUsage = 2;

  /// Network / API failure after retries.
  static const int networkFailure = 3;

  /// Unexpected internal error.
  static const int internalError = 4;
}
