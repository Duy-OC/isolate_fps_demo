import 'dart:convert';
import 'dart:io';

import '../data/models/parse_result.dart';

typedef ProgressCallback = void Function(double value, String stage);

/// Top-level so it can be passed to compute()/Isolate.spawn.
/// Fully synchronous on purpose: identical work in all 3 modes.
ParseResult parseJsonFile(String path) => parseJsonFileWithProgress(path, null);

ParseResult parseJsonFileWithProgress(
  String path,
  ProgressCallback? onProgress,
) {
  final sw = Stopwatch()..start();
  onProgress?.call(0.0, 'read');
  final file = File(path);
  var text = file.readAsStringSync(); // sync on purpose (same in all modes)
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1); // strip UTF-8 BOM
  }
  final readMs = sw.elapsedMilliseconds;

  sw.reset();
  onProgress?.call(0.3, 'decode');
  final root = jsonDecode(text); // throws FormatException if invalid
  final decodeMs = sw.elapsedMilliseconds;

  sw.reset();
  onProgress?.call(0.8, 'walk');
  final stats = _walk(root);
  final walkMs = sw.elapsedMilliseconds;

  onProgress?.call(1.0, 'walk');
  return ParseResult(
    fileBytes: file.lengthSync(),
    readMs: readMs,
    decodeMs: decodeMs,
    walkMs: walkMs,
    stats: stats,
  );
}

/// Iterative walk (explicit stack): deeply nested JSON cannot overflow the
/// Dart call stack the way a recursive walk would.
JsonStats _walk(Object? root) {
  var nodes = 0;
  var maxDepth = 0;
  final stack = <(Object?, int)>[(root, 1)];
  while (stack.isNotEmpty) {
    final (v, d) = stack.removeLast();
    nodes++;
    if (d > maxDepth) maxDepth = d;
    if (v is Map) {
      for (final c in v.values) {
        stack.add((c, d + 1));
      }
    } else if (v is List) {
      for (final c in v) {
        stack.add((c, d + 1));
      }
    }
  }
  return JsonStats(
    topLevel: switch (root) {
      Map() => 'object',
      List() => 'array',
      _ => 'scalar',
    },
    nodes: nodes,
    maxDepth: maxDepth,
  );
}
