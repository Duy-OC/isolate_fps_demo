import 'package:flutter/material.dart';

import 'features/benchmark/benchmark_screen.dart';

class IsolateFpsApp extends StatelessWidget {
  const IsolateFpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Dark theme so the white compute() line on the chart stays visible.
    return MaterialApp(
      title: 'Isolate FPS Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const BenchmarkScreen(),
    );
  }
}
