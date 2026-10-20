import 'package:path/path.dart' as p;

/// Fixture entrypoint used by unused-dependency tests.
String joinExample(String a, String b) => p.join(a, b);
