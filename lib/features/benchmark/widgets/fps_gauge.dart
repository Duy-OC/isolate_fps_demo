import 'package:flutter/material.dart';

import '../../../core/fps_monitor.dart';

/// Big FPS number, colored by performance.
class FpsGauge extends StatelessWidget {
  const FpsGauge({super.key, required this.monitor});

  final FpsMonitor monitor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final fps = monitor.currentFps;
        final color = fps >= 55
            ? Colors.green
            : fps >= 30
                ? Colors.orange
                : Colors.red;
        return Column(
          children: [
            Text(
              fps.toStringAsFixed(0),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
            Text('FPS', style: Theme.of(context).textTheme.labelLarge),
          ],
        );
      },
    );
  }
}
