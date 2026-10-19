import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';
import '../../../core/json_source.dart';
import '../../../workers/runners.dart';
import '../benchmark/widgets/fps_chart.dart';
import '../benchmark/widgets/fps_gauge.dart';
import '../benchmark/widgets/jank_animation.dart';
import '../benchmark/widgets/result_card.dart';
import 'benchmark_controller.dart';

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  final BenchmarkController c = BenchmarkController();
  int selectedMb = AppConstants.defaultSizeMb;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Controller already set c.error and notified.
      final msg = c.error ?? 'Không đọc được tệp / không phải JSON hợp lệ';
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _pick() async {
    final s = await pickSource();
    if (s == null || !mounted) return;
    if (s.bytes > AppConstants.warnPickedBytes) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tệp rất lớn'),
          content: Text(
            'Tệp ${(s.bytes / 1024 / 1024).toStringAsFixed(0)} MB sau khi '
            'decode sẽ chiếm nhiều RAM. Tiếp tục?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    c.setSource(s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Isolate FPS Demo')),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (kDebugMode) _debugBanner(),
              const JankAnimation(),
              const SizedBox(height: 8),
              Center(child: FpsGauge(monitor: c.monitor)),
              const SizedBox(height: 16),
              SegmentedButton<RunMode>(
                segments: [
                  for (final m in RunMode.values)
                    ButtonSegment(value: m, label: Text(m.label)),
                ],
                selected: {c.mode},
                onSelectionChanged:
                    c.busy ? null : (s) => c.setMode(s.first),
              ),
              const SizedBox(height: 12),
              _sourceRow(),
              const SizedBox(height: 8),
              _runRow(),
              if (c.mode == RunMode.main && c.source != null) ...[
                const SizedBox(height: 6),
                const Text(
                  'UI sẽ đứng hình vài giây khi chạy Main, đừng chạm màn hình.',
                  style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
                ),
              ],
              if (c.busy || c.progress > 0) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: c.progress == 0 ? null : c.progress,
                ),
                const SizedBox(height: 4),
                Center(child: Text(_stateLabel())),
              ],
              if (c.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  c.error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              FpsChart(latest: c.latest),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Kết quả', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (c.results.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: c.exportMarkdown()),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã copy bảng Markdown'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Markdown'),
                    ),
                  if (c.results.isNotEmpty)
                    IconButton(
                      onPressed: c.clearResults,
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Xóa kết quả',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (final r in c.results) ResultCard(result: r),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _sourceRow() {
    final src = c.source;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<int>(
          segments: [
            for (final mb in AppConstants.sizeOptionsMb)
              ButtonSegment(value: mb, label: Text('$mb MB')),
          ],
          selected: {selectedMb},
          onSelectionChanged:
              c.busy ? null : (s) => setState(() => selectedMb = s.first),
        ),
        FilledButton.icon(
          onPressed:
              c.busy ? null : () => _run(() => c.generate(selectedMb)),
          icon: const Icon(Icons.dataset),
          label: const Text('Generate'),
        ),
        OutlinedButton.icon(
          onPressed: c.busy ? null : _pick,
          icon: const Icon(Icons.folder_open),
          label: const Text('Chọn tệp JSON'),
        ),
        if (src != null)
          Text(
            '${src.label} • ${(src.bytes / 1024 / 1024).toStringAsFixed(1)} MB'
            '${src.bytes < 15 * 1024 * 1024 ? ' • nhỏ hơn 15 MB – jank có thể không rõ' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _runRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: c.busy || c.source == null
              ? null
              : () => _run(() => c.runOnce(c.mode)),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Run'),
        ),
        FilledButton.tonalIcon(
          onPressed: c.busy || c.source == null
              ? null
              : () => _run(c.runAll),
          icon: const Icon(Icons.compare),
          label: const Text('Run all modes'),
        ),
      ],
    );
  }

  String _stateLabel() => switch (c.state) {
        BenchState.idle => 'Sẵn sàng',
        BenchState.generating => 'Đang sinh JSON…',
        BenchState.ready => 'Sẵn sàng',
        BenchState.settling => 'Chuẩn bị…',
        BenchState.running =>
          'Đang chạy ${c.mode.label}${c.stage.isEmpty ? '' : ' • ${c.stage}'}',
        BenchState.summarizing => 'Tổng hợp kết quả…',
      };

  Widget _debugBanner() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: const Text(
          'Đang chạy Debug – số liệu không đại diện. '
          'Hãy chạy: flutter run --profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
}
