import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/fps_monitor.dart';
import '../../core/json_source.dart';
import '../../data/models/benchmark_result.dart';
import '../../data/models/parse_result.dart';
import '../../workers/isolate_runner.dart';
import '../../workers/runners.dart';

enum BenchState { idle, generating, ready, settling, running, summarizing }

/// Orchestrates the benchmark flow. No heavy logic here, only coordination.
class BenchmarkController extends ChangeNotifier {
  final FpsMonitor monitor = FpsMonitor();

  BenchState state = BenchState.idle;
  RunMode mode = RunMode.isolate;
  double progress = 0;
  String stage = '';
  String? error;
  JsonSource? source;
  final List<BenchmarkResult> results = [];

  /// Newest result per mode -> the combined chart.
  final Map<RunMode, BenchmarkResult> latest = {};

  bool _disposed = false;

  bool get busy =>
      state == BenchState.generating ||
      state == BenchState.settling ||
      state == BenchState.running;

  void setMode(RunMode m) {
    if (busy) return;
    mode = m;
    _notify();
  }

  void setSource(JsonSource s) {
    source = s;
    error = null;
    _notify();
  }

  Future<void> generate(int mb) async {
    if (busy) return;
    state = BenchState.generating;
    error = null;
    _notify();
    try {
      source = await generateSource(mb);
      state = BenchState.ready;
    } catch (e) {
      error = 'Sinh file thất bại: $e';
      state = BenchState.idle;
    }
    _notify();
  }

  Future<BenchmarkResult> runOnce(RunMode m) async {
    final src = source;
    if (src == null) throw StateError('Chưa có tệp JSON');
    final path = src.path;

    state = BenchState.settling;
    progress = 0;
    stage = '';
    error = null;
    _notify();

    // 1) Let the UI paint the "running" state BEFORE blocking
    //    (essential for Main mode).
    for (var i = 0; i < AppConstants.settleFrames; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }

    // Warm the OS page cache asynchronously so the first mode measured is
    // not penalised by a cold file read.
    await File(path).openRead().drain<void>();

    // 2) Start monitor and record baseline FPS with the animation running.
    monitor.start();
    await Future<void>.delayed(
      const Duration(milliseconds: AppConstants.baselineMs),
    );

    // 3) Run the heavy task.
    state = BenchState.running;
    _notify();
    final startMs = monitor.nowMs;
    final sw = Stopwatch()..start();
    try {
      final ParseResult result = await switch (m) {
        RunMode.main => runOnMain(path),
        RunMode.compute => runWithCompute(path),
        RunMode.isolate => runWithIsolate(path, onProgress: (v, s) {
            progress = v;
            stage = s;
            _notify();
          }),
      };
      sw.stop();
      final endMs = monitor.nowMs;

      // 4) Wait so the giant frozen frame (Main mode) is recorded, then stop.
      state = BenchState.summarizing;
      _notify();
      await Future<void>.delayed(
        const Duration(milliseconds: AppConstants.tailMs),
      );
      monitor.stop();

      // 5) Summarize ONLY the task window; snapshot the FPS series too.
      final summary = monitor.summarize(startMs, endMs);
      final r = BenchmarkResult(
        mode: m,
        wallMs: sw.elapsedMilliseconds,
        fps: summary,
        series: monitor.fpsSeries(startMs),
        parse: result,
        at: DateTime.now(),
      );
      results.insert(0, r);
      latest[m] = r;
      state = BenchState.ready;
      _notify();
      return r;
    } catch (e) {
      monitor.stop();
      state = BenchState.ready;
      error = 'Không đọc được tệp / không phải JSON hợp lệ';
      _notify();
      rethrow;
    }
  }

  /// Main -> compute -> Isolate with a 1 s pause between runs.
  Future<void> runAll() async {
    for (final m in RunMode.values) {
      mode = m;
      _notify();
      await runOnce(m);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  void clearResults() {
    results.clear();
    latest.clear();
    _notify();
  }

  String exportMarkdown() {
    final buf = StringBuffer()
      ..writeln(
        '| Chế độ | Wall ms | FPS TB | FPS min | Frame dài nhất (ms) | Vsync bỏ lỡ | Nodes |',
      )
      ..writeln('|---|---|---|---|---|---|---|');
    for (final r in results) {
      buf.writeln(r.toMarkdownRow());
    }
    return buf.toString();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    monitor.dispose();
    super.dispose();
  }
}
