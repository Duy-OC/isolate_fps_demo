import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isolate_fps_demo/workers/json_parser.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('parser_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  File write(String name, String content) {
    final f = File('${tmp.path}${Platform.pathSeparator}$name');
    f.writeAsStringSync(content);
    return f;
  }

  test('root array: hand-counted nodes and depth', () {
    // [1, {"a": 2}, [3, 4]] -> walker counts VALUES only (not map keys):
    // root, 1, {"a":2}, 2, [3,4], 3, 4 = 7 nodes; deepest leaf at depth 3.
    final f = write('arr.json', '[1, {"a": 2}, [3, 4]]');
    final r = parseJsonFile(f.path);
    expect(r.stats.topLevel, 'array');
    expect(r.stats.nodes, 7);
    expect(r.stats.maxDepth, 3);
    expect(r.fileBytes, f.lengthSync());
  });

  test('root object: hand-counted nodes and depth', () {
    // {"x": {"y": 1}} -> root, {"y":1}, 1 = 3 nodes (keys not counted); depth 3.
    final f = write('obj.json', '{"x": {"y": 1}}');
    final r = parseJsonFile(f.path);
    expect(r.stats.topLevel, 'object');
    expect(r.stats.nodes, 3);
    expect(r.stats.maxDepth, 3);
  });

  test('root scalar', () {
    final f = write('scalar.json', '42');
    final r = parseJsonFile(f.path);
    expect(r.stats.topLevel, 'scalar');
    expect(r.stats.nodes, 1);
    expect(r.stats.maxDepth, 1);
  });

  test('empty array', () {
    final f = write('empty.json', '[]');
    final r = parseJsonFile(f.path);
    expect(r.stats.nodes, 1);
    expect(r.stats.maxDepth, 1);
  });

  test('deep nesting ~1000 levels does not overflow the stack', () {
    final depth = 1000;
    final open = List.filled(depth, '[').join();
    final close = List.filled(depth, ']').join();
    final content = '${open}1$close';
    final f = write('deep.json', content);
    final r = parseJsonFile(f.path);
    expect(r.stats.maxDepth, depth + 1); // root is depth 1
  });

  test('UTF-8 BOM is stripped', () {
    final f = write('bom.json', '﻿[1, 2]');
    final r = parseJsonFile(f.path);
    expect(r.stats.topLevel, 'array');
    expect(r.stats.nodes, 3); // root, 1, 2
  });

  test('invalid JSON throws FormatException', () {
    final f = write('bad.json', '{not json');
    expect(() => parseJsonFile(f.path), throwsFormatException);
  });

  test('progress stages: read, decode, walk; ends at 1.0', () {
    final f = write('prog.json', '{"a": [1, 2]}');
    final stages = <String>[];
    var last = 0.0;
    final r = parseJsonFileWithProgress(f.path, (v, s) {
      stages.add(s);
      last = v;
    });
    expect(stages, containsAllInOrder(['read', 'decode', 'walk']));
    expect(last, 1.0);
    // {"a": [1, 2]} -> root, list, 1, 2 = 4 nodes (map keys not counted).
    expect(r.stats.nodes, 4);
    expect(r.stats.maxDepth, 3);
  });
}
