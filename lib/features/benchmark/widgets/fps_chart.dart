import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../data/models/benchmark_result.dart';
import '../../../workers/runners.dart';

/// Combined FPS chart: one step line per RunMode (latest run only), all x
/// values relative to the task start so the three curves are comparable.
///
/// Axes (the chart assumes a 60 Hz display):
/// * Y = FPS (frames per 200 ms bin × 5), fixed 0..65, dashed references at
///   60 (target) and 30 (half). 0 = the UI is completely frozen.
/// * X = seconds from the task start. 0.0 is the dashed "start" line;
///   negative values are the baseline before the task, positive values
///   cover the task and the short tail afterwards.
class FpsChart extends StatelessWidget {
  const FpsChart({super.key, required this.latest});

  final Map<RunMode, BenchmarkResult> latest;

  /// Draw order and thickness. compute() (white) is drawn LAST and thinnest
  /// so it stays visible where it overlaps the thicker Main/Isolate lines.
  static const Map<RunMode, double> _barWidth = {
    RunMode.main: 4,
    RunMode.isolate: 3,
    RunMode.compute: 2,
  };

  @override
  Widget build(BuildContext context) {
    final all = latest.values.expand((r) => r.series).toList();
    if (all.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('Chưa có dữ liệu – bấm Run')),
      );
    }
    // Round outward to multiples of 0.5 so every x tick lands on a clean
    // 0.5 s step and fl_chart never prints odd labels such as "-0.6".
    final minX = (all.map((p) => p.$1).reduce(math.min) / 0.5).floor() * 0.5;
    final maxX = (all.map((p) => p.$1).reduce(math.max) / 0.5).ceil() * 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final m in RunMode.values)
              _LegendItem(mode: m, result: latest[m]),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: 0,
              maxY: 65,
              lineBarsData: [
                for (final m in _barWidth.keys)
                  if (latest[m] case final r?)
                    LineChartBarData(
                      spots: [for (final p in r.series) FlSpot(p.$1, p.$2)],
                      color: m.color,
                      barWidth: _barWidth[m]!,
                      isCurved: false,
                      dotData: const FlDotData(show: false),
                    ),
              ],
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 60,
                    color: Colors.white24,
                    dashArray: [4, 4],
                  ),
                  HorizontalLine(
                    y: 30,
                    color: Colors.white24,
                    dashArray: [4, 4],
                  ),
                ],
                verticalLines: [
                  VerticalLine(
                    x: 0,
                    color: Colors.white38,
                    dashArray: [4, 4],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                      labelResolver: (_) => 'start',
                    ),
                  ),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  axisNameWidget: const Text(
                    'FPS (khung hình/giây)',
                    style: TextStyle(fontSize: 11),
                  ),
                  axisNameSize: 20,
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 15,
                    reservedSize: 32,
                    getTitlesWidget: (v, _) => v > 60
                        ? const SizedBox.shrink() // hide the "65" label
                        : Text(
                            v.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text(
                    'Thời gian từ lúc bắt đầu tác vụ (giây)',
                    style: TextStyle(fontSize: 11),
                  ),
                  axisNameSize: 20,
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 0.5,
                    reservedSize: 24,
                    getTitlesWidget: (v, _) {
                      // fl_chart also draws min/max labels: keep only
                      // multiples of 0.5.
                      if ((v * 2 - (v * 2).round()).abs() > 1e-6) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(drawVerticalLine: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const Text(
          'FPS = (số frame trong ô 200 ms) × 5; 0 = giao diện đứng hình. '
          'Vạch "start" = lúc bắt đầu tác vụ.',
          style: TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.mode, required this.result});

  final RunMode mode;
  final BenchmarkResult? result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: mode.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          r == null
              ? '${mode.label} · chưa chạy'
              : '${mode.label} · frame dài nhất ${r.fps.longestFrameMs.round()} ms',
          style: TextStyle(
            fontSize: 12,
            color: r == null ? Colors.white38 : Colors.white,
          ),
        ),
      ],
    );
  }
}
