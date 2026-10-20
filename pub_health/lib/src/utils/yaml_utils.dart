import 'package:yaml/yaml.dart';

/// Helpers for working with YAML documents.
class YamlUtils {
  /// Parses [content] into a [YamlMap], or throws [YamlParseException].
  static YamlMap parseMap(String content) {
    try {
      final doc = loadYaml(content);
      if (doc == null) {
        throw YamlParseException('YAML document is empty.');
      }
      if (doc is! YamlMap) {
        throw YamlParseException('Expected a YAML map at the document root.');
      }
      return doc;
    } on YamlParseException {
      rethrow;
    } on YamlException catch (e) {
      throw YamlParseException(e.message, spanMessage: e.span?.toString());
    } catch (e) {
      throw YamlParseException('Failed to parse YAML: $e');
    }
  }

  /// Reads a string value from [map] at [key].
  static String? readString(YamlMap map, String key) {
    final value = map[key];
    if (value == null) return null;
    return value.toString();
  }

  /// Reads a nested map at [key], or null.
  static YamlMap? readMap(YamlMap map, String key) {
    final value = map[key];
    if (value is YamlMap) return value;
    return null;
  }

  /// Converts a [YamlNode]/JSON-like structure to Dart maps/lists.
  static Object? toDart(Object? value) {
    if (value is YamlMap) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): toDart(entry.value),
      };
    }
    if (value is YamlList) {
      return value.map(toDart).toList();
    }
    return value;
  }
}

/// Thrown when YAML cannot be parsed into the expected shape.
class YamlParseException implements Exception {
  /// Creates a parse exception.
  YamlParseException(this.message, {this.spanMessage});

  /// Error message.
  final String message;

  /// Optional source span description.
  final String? spanMessage;

  @override
  String toString() {
    if (spanMessage == null) return 'YamlParseException: $message';
    return 'YamlParseException: $message ($spanMessage)';
  }
}
