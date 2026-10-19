import 'package:flutter_test/flutter_test.dart';
import 'package:isolate_fps_demo/core/constants.dart';
import 'package:isolate_fps_demo/core/fps_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('60 normal frames + one 2000 ms freeze', () {
    final m = FpsMonitor();
    var t = 0.0;
    for (var i = 0; i < 60; i++) {
      t += 16.7;
      m.debugAddFrame(t, 16.7);
    }
    t += 2000;
    m.debugAddFrame(t, 2000);

    final s = m.summarize(0, t);
    expect(s.frames, 61);
    expect(s.longestFrameMs, closeTo(2000, 0.001));
    expect(s.minFps, closeTo(1000 / 2000, 0.001));
    final total = 60 * 16.7 + 2000;
    expect(s.avgFps, closeTo(61 * 1000 / total, 0.01));
    // floor(2000 / (1000/60)) = 119.999... due to float -> 118 missed.
    expect(s.missedVsync, 118);
    expect(s.jankFrames, 1);
  });

  test('fpsSeries: ~60 FPS while running, ~0 FPS during freeze', () {
    final m = FpsMonitor();
    var t = 0.0;
    // 1 s of healthy frames (60 fps)
    for (var i = 0; i < 60; i++) {
      t += 16.7;
      m.debugAddFrame(t, 16.7);
    }
    // 2 s freeze
    t += 2000;
    m.debugAddFrame(t, 2000);
    // 1 s of healthy frames again
    for (var i = 0; i < 60; i++) {
      t += 16.7;
      m.debugAddFrame(t, 16.7);
    }

    final series = m.fpsSeries(0, binMs: 200);
    expect(series, isNotEmpty);
    // Step shape: every FULL bin contributes two spots with the same FPS
    // (flat segment + vertical edge at the bin boundary), the partial last
    // bin is dropped.
    expect(series.length.isEven, isTrue);
    for (var i = 0; i + 1 < series.length; i += 2) {
      expect(series[i].$2, series[i + 1].$2);
      expect(series[i].$1, lessThan(series[i + 1].$1));
    }
    // Bins entirely inside the freeze window have no frames -> 0 FPS.
    // Freeze spans roughly (1000, 3002]; bins centred 1.3–2.7 s should be ~0.
    final frozen = series.where((p) => p.$1 > 1.4 && p.$1 < 2.6).toList();
    expect(frozen, isNotEmpty);
    for (final p in frozen) {
      expect(p.$2, lessThan(5), reason: 'bin at ${p.$1}s should be ~0 FPS');
    }
    // Early bins (healthy) are near 60 FPS.
    final healthy = series.where((p) => p.$1 > 0.1 && p.$1 < 0.8).toList();
    expect(healthy, isNotEmpty);
    for (final p in healthy) {
      expect(p.$2, greaterThan(50), reason: 'bin at ${p.$1}s should be ~60 FPS');
    }
  });

  test('long frame ending after endMs still counted (overlap rule)', () {
    final m = FpsMonitor();
    m.debugAddFrame(3000, 2000); // spans (1000, 3000]
    final s = m.summarize(0, 2000);
    expect(s.frames, 1);
    expect(s.longestFrameMs, 2000);
  });

  test('frame entirely outside window is excluded', () {
    final m = FpsMonitor();
    m.debugAddFrame(500, 16.7);
    m.debugAddFrame(3000, 16.7);
    final s = m.summarize(1000, 2000);
    expect(s.frames, 0);
  });

  test('empty monitor returns empty summary and empty series', () {
    final m = FpsMonitor();
    expect(m.summarize(0, 100).frames, 0);
    expect(m.fpsSeries(0), isEmpty);
  });

  test('baselineFps uses frames before startMs', () {
    final m = FpsMonitor();
    var t = 0.0;
    for (var i = 0; i < 10; i++) {
      t += 16.7;
      m.debugAddFrame(t, 16.7);
    }
    t += 100;
    m.debugAddFrame(t, 100);
    final s = m.summarize(170, t);
    expect(s.baselineFps, closeTo(10 * 1000 / (10 * 16.7), 0.01));
    expect(s.frames, 1);
    expect(AppConstants.frameBudgetMs, closeTo(16.667, 0.01));
  });
}
