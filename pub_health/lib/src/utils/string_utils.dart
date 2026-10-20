/// Small string helpers.
class StringUtils {
  /// Capitalizes the first character of [value].
  static String capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  /// Formats [date] as `yyyy-MM-dd HH:mm:ss` in UTC.
  static String formatDateTime(DateTime date) {
    final utc = date.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
  }

  /// Pluralizes [word] based on [count].
  static String pluralize(int count, String word, [String? plural]) {
    if (count == 1) return word;
    return plural ?? '${word}s';
  }
}
