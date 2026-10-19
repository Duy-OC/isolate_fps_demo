/// Structural stats of any parsed JSON – small, cheap to send between isolates.
class JsonStats {
  const JsonStats({
    required this.topLevel,
    required this.nodes,
    required this.maxDepth,
  });

  /// 'object' | 'array' | 'scalar'
  final String topLevel;
  final int nodes;
  final int maxDepth;
}

class ParseResult {
  const ParseResult({
    required this.fileBytes,
    required this.readMs,
    required this.decodeMs,
    required this.walkMs,
    required this.stats,
  });

  final int fileBytes;
  final int readMs;
  final int decodeMs;
  final int walkMs;
  final JsonStats stats;
}

/// Progress message streamed from a worker isolate to the UI.
class ProgressMsg {
  const ProgressMsg(this.value, this.stage);

  /// 0..1
  final double value;

  /// 'read' | 'decode' | 'walk'
  final String stage;
}
