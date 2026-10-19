import 'package:flutter/material.dart';

import '../../../data/models/benchmark_result.dart';
import '../../../workers/runners.dart';

/// Card showing one benchmark run's numbers.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.result});

  final BenchmarkResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final ok = r.fps.avgFps >= 50 || r.mode != RunMode.main;
    final color = ok ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(r.mode.label),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                Text(
                  '${r.wallMs} ms',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _stat('FPS TB', r.fps.avgFps.toStringAsFixed(1)),
                _stat('FPS min', r.fps.minFps.toStringAsFixed(1)),
                _stat(
                  'Frame dài nhất',
                  '${r.fps.longestFrameMs.toStringAsFixed(0)} ms',
                ),
                _stat('Jank', '${r.fps.jankFrames}'),
                _stat('Vsync bỏ lỡ', '${r.fps.missedVsync}'),
                _stat('Nodes', '${r.parse.stats.nodes}'),
                _stat(
                  'File',
                  '${(r.parse.fileBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                ),
                _stat(
                  'read/decode/walk',
                  '${r.parse.readMs}/${r.parse.decodeMs}/${r.parse.walkMs} ms',
                ),
              ],
            ),
            const SizedBox(height: 4),
            const _UnitLegend(),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
}

/// Collapsible legend explaining the unit / meaning of every number above.
class _UnitLegend extends StatelessWidget {
  const _UnitLegend();

  static const List<(String, String)> _rows = [
    ('Thời gian lớn', 'ms – tổng thời gian hoàn thành tác vụ, đo bằng Stopwatch ở main isolate'),
    ('FPS TB', 'khung hình/giây trung bình trong lúc chạy tác vụ'),
    ('FPS min', '1000 / Frame dài nhất – FPS thấp nhất tức thời'),
    ('Frame dài nhất', 'ms – khoảng cách lâu nhất giữa 2 frame liên tiếp'),
    ('Jank', 'số frame dài hơn 18,3 ms (> 110% ngân sách 16,67 ms)'),
    ('Vsync bỏ lỡ', 'số chu kỳ vsync 16,67 ms bị bỏ qua'),
    ('Nodes', 'số nút JSON (object/array/giá trị)'),
    ('File', 'dung lượng tệp (MB)'),
    ('read/decode/walk', 'ms cho từng giai đoạn đọc / jsonDecode / duyệt cây trong parser'),
  ];

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return ExpansionTile(
      dense: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 8, bottom: 8),
      title: const Row(
        children: [
          Icon(Icons.info_outline, size: 16),
          SizedBox(width: 6),
          Text('Chú giải đơn vị', style: TextStyle(fontSize: 12)),
        ],
      ),
      children: [
        for (final (name, meaning) in _rows)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$name: $meaning',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
      ],
    );
  }
}
