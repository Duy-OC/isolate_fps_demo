import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart' show Color, Colors;

import '../data/models/parse_result.dart';
import 'json_parser.dart';

enum RunMode { main, compute, isolate }

extension RunModeX on RunMode {
  String get label => switch (this) {
        RunMode.main => 'Main thread',
        RunMode.compute => 'compute()',
        RunMode.isolate => 'Isolate (SendPort)',
      };

  /// Line colors chosen for the dark chart background.
  Color get color => switch (this) {
        RunMode.main => Colors.redAccent,
        RunMode.compute => Colors.white,
        RunMode.isolate => Colors.greenAccent,
      };
}

/// Runs on the UI isolate itself -> intentionally blocks the UI.
Future<ParseResult> runOnMain(String path) async => parseJsonFile(path);

/// One-shot background execution via compute(). No live progress.
Future<ParseResult> runWithCompute(String path) =>
    compute<String, ParseResult>(parseJsonFile, path);
