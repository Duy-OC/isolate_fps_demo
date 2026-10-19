import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'constants.dart';

/// Aggregated FPS statistics for a measured window.
class FpsSummary {
  const FpsSummary({
    required this.frames,
    required this.avgFps,
    required this.minFps,
    required this.longestFrameMs,
    required this.jankFrames,
    required this.missedVsync,
    required this.baselineFps,
  });

  final int frames;
  final int jankFrames;
  final int missedVsync;
  final double avgFps;
  final double minFps;
  final double longestFrameMs;
  final double baselineFps;

  static const empty = FpsSummary(
    frames: 0,
    avgFps: 0,
    minFps: 0,
    longestFrameMs: 0,
    jankFrames: 0,
    missedVsync: 0,
    baselineFps: 0,
  );
}

class _Frame {
  const _Frame(this.endMs, this.intervalMs);
  final double endMs;
  final double intervalMs;
}

/// Measures UI FPS using a [Ticker].
///
/// When the UI isolate is blocked, ticks stop arriving; the next tick has a
/// huge interval, which is exactly how a frozen frame is detected.
class FpsMonitor extends ChangeNotifier {
  FpsMonitor({this.budgetMs = AppConstants.frameBudgetMs}) {
    _ticker = Ticker(_onTick, debugLabel: 'FpsMonitor');
  }

  final double budgetMs;
  late final Ticker _ticker;
  final Stopwatch _clock = Stopwatch();
  final List<_Frame> _frames = [];
  double? _prevMs;
  double currentFps = 0;
  int _winFrames = 0;
  double _winStartMs = 0;

  bool get isRunning => _ticker.isActive;
  double get nowMs => _clock.elapsedMicroseconds / 1000.0;

  void start() {
    _frames.clear();
    _prevMs = null;
    currentFps = 0;
    _winFrames = 0;
    _winStartMs = 0;
    _clock
      ..reset()
      ..start();
    _ticker.start();
  }

  void stop() {
    if (_ticker.isActive) _ticker.stop();
    _clock.stop();
  }

  void _onTick(Duration _) {
    final now = nowMs;
    final prev = _prevMs;
    if (prev != null) _frames.add(_Frame(now, now - prev));
    _prevMs = now;
    _winFrames++;
    final span = now - _winStartMs;
    if (span >= 500) {
      currentFps = _winFrames * 1000.0 / span;
      _winFrames = 0;
      _winStartMs = now;
      notifyListeners();
    }
  }

  /// Step series relative to the task start (seconds). Each FULL bin becomes
  /// a flat segment (two spots at the same FPS), so the line drops straight
  /// down and stays flat at 0 FPS while the UI is frozen, with no diagonal
  /// edges and no fall-off at the right edge. The last partial bin is dropped
  /// because it would be divided by a full bin duration and drag every curve
  /// down to ~0 at the end of the chart.
  List<(double, double)> fpsSeries(double startMs, {int binMs = 200}) {
    if (_frames.isEmpty) return const [];
    final first = _frames.first.endMs;
    final last = _frames.last.endMs;
    final out = <(double, double)>[];
    var i = 0;
    for (var b = first; b + binMs <= last; b += binMs) {
      var n = 0;
      while (i < _frames.length && _frames[i].endMs < b + binMs) {
        n++;
        i++;
      }
      final fps = (n * 1000.0 / binMs).clamp(0.0, 65.0).toDouble();
      out
        ..add(((b - startMs) / 1000.0, fps)) // left edge of the bin
        ..add(((b + binMs - startMs) / 1000.0, fps)); // right edge
    }
    return out;
  }

  /// Summarize frames that overlap the window [startMs, endMs].
  FpsSummary summarize(double startMs, double endMs) {
    final inWin = _frames
        .where((f) => f.endMs > startMs && f.endMs - f.intervalMs < endMs)
        .toList();
    if (inWin.isEmpty) return FpsSummary.empty;

    var totalMs = 0.0;
    var longest = 0.0;
    var jank = 0;
    var missed = 0;
    for (final f in inWin) {
      totalMs += f.intervalMs;
      if (f.intervalMs > longest) longest = f.intervalMs;
      if (f.intervalMs > budgetMs * 1.1) jank++;
      final skipped = (f.intervalMs / budgetMs).floor() - 1;
      if (skipped > 0) missed += skipped;
    }

    final baselineFrames = _frames
        .where((f) => f.endMs <= startMs && f.endMs > startMs - 700)
        .toList();
    var baselineFps = 0.0;
    if (baselineFrames.isNotEmpty) {
      var baseTotal = 0.0;
      for (final f in baselineFrames) {
        baseTotal += f.intervalMs;
      }
      baselineFps = baselineFrames.length * 1000.0 / baseTotal;
    }

    return FpsSummary(
      frames: inWin.length,
      avgFps: inWin.length * 1000.0 / totalMs,
      minFps: longest > 0 ? 1000 / longest : 0,
      longestFrameMs: longest,
      jankFrames: jank,
      missedVsync: missed,
      baselineFps: baselineFps,
    );
  }

  @visibleForTesting
  void debugAddFrame(double endMs, double intervalMs) =>
      _frames.add(_Frame(endMs, intervalMs));

  @override
  void dispose() {
    stop();
    _ticker.dispose();
    super.dispose();
  }
}
