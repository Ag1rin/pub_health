import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

String joinExample(String a, String b) => p.join(a, b);

bool listsEqual(List<int> a, List<int> b) =>
    const ListEquality<int>().equals(a, b);
