import 'dart:convert';
import 'dart:io';

/// In-memory [IOSink] for capturing CLI output in tests.
class MemorySink implements IOSink {
  final StringBuffer buffer = StringBuffer();

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) => buffer.write(utf8.decode(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  void write(Object? object) => buffer.write(object);

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      buffer.writeAll(objects, separator);

  @override
  void writeln([Object? object = '']) => buffer.writeln(object);

  @override
  void writeCharCode(int charCode) => buffer.writeCharCode(charCode);

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future flush() async {}

  @override
  Future close() async {}

  @override
  Future get done => Future.value();
}
