import '../../core/fps_monitor.dart';
import 'parse_result.dart';
import '../../workers/runners.dart';

/// One benchmark run's full record.
class BenchmarkResult {
  const BenchmarkResult({
    required this.mode,
    required this.wallMs,
    required this.fps,
    required this.series,
    required this.parse,
    required this.at,
  });

  final RunMode mode;
  final int wallMs;
  final FpsSummary fps;

  /// FPS points (x = seconds from task start) captured during the run.
  final List<(double, double)> series;
  final ParseResult parse;
  final DateTime at;

  String toMarkdownRow() =>
      '| ${mode.label} | $wallMs | ${fps.avgFps.toStringAsFixed(1)} | '
      '${fps.minFps.toStringAsFixed(1)} | ${fps.longestFrameMs.toStringAsFixed(0)} | '
      '${fps.missedVsync} | ${parse.stats.nodes} |';
}
