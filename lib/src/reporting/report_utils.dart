import '../models/health_finding.dart';

/// Small helpers shared by reporters.
class ReportUtils {
  /// Relative project path for a finding (recursive mode), or null.
  static String? projectOf(HealthFinding finding) =>
      finding.metadata['project'] as String?;

  /// Suggested remediation command for a finding, or null.
  static String? commandOf(HealthFinding finding) =>
      finding.metadata['suggestedCommand'] as String?;

  /// Escapes text for use in HTML content and attribute values.
  static String html(Object? value) => '$value'
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  /// Escapes text for XML, dropping characters XML 1.0 cannot represent.
  static String xml(Object? value) {
    final buffer = StringBuffer();
    for (final rune in '$value'.runes) {
      final valid = rune == 0x9 ||
          rune == 0xA ||
          rune == 0xD ||
          (rune >= 0x20 && rune <= 0xD7FF) ||
          (rune >= 0xE000 && rune <= 0xFFFD) ||
          (rune >= 0x10000 && rune <= 0x10FFFF);
      if (!valid) continue;
      switch (rune) {
        case 0x26:
          buffer.write('&amp;');
        case 0x3C:
          buffer.write('&lt;');
        case 0x3E:
          buffer.write('&gt;');
        case 0x22:
          buffer.write('&quot;');
        case 0x27:
          buffer.write('&apos;');
        default:
          buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
