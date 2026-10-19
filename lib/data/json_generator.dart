import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

/// Ensure a JSON file of at least [targetBytes] exists in [dir].
/// Generation runs in a short-lived isolate so even the setup stays off the
/// UI thread. The closure only captures two Strings/int, never `this`.
Future<File> ensureJsonFile({
  required String dir,
  required int targetBytes,
  bool force = false,
}) async {
  final mb = (targetBytes / (1024 * 1024)).round();
  final path = '$dir${Platform.pathSeparator}generated_${mb}mb.json';
  final file = File(path);
  if (!force && await file.exists() && await file.length() >= targetBytes) {
    return file;
  }
  await Isolate.run(() => generateJsonSync(path, targetBytes));
  return file;
}

const _words = [
  'quantum', 'nebula', 'cobalt', 'aurora', 'zephyr', 'onyx', 'lunar', 'solar',
  'crimson', 'ember', 'frost', 'storm', 'vortex', 'prism', 'echo', 'nova',
  'terra', 'aqua', 'void', 'flux', 'rapid', 'solid', 'prime', 'ultra',
];

const _categories = [
  'electronics', 'books', 'clothing', 'toys', 'sports', 'grocery',
  'home', 'garden', 'auto', 'health', 'music', 'office',
];

/// Deterministic (seed 42) streaming JSON writer.
/// ASCII-only so String.length == byte count; buffered to keep RAM low.
void generateJsonSync(String path, int targetBytes) {
  final rnd = Random(42);
  final sink = File(path).openSync(mode: FileMode.write);
  var written = 0;
  final buf = StringBuffer();

  String word() => _words[rnd.nextInt(_words.length)];
  String name() {
    final n = 2 + rnd.nextInt(2);
    return List.generate(n, (_) => word()).join(' ');
  }

  String description() => List.generate(40, (_) => word()).join(' ');

  void flush() {
    final s = buf.toString();
    sink.writeStringSync(s);
    written += s.length;
    buf.clear();
  }

  try {
    buf.write('[');
    var id = 1;
    while (written < targetBytes) {
      final record = <String, dynamic>{
        'id': id,
        'sku': 'SKU-${id.toString().padLeft(6, '0')}',
        'name': name(),
        'category': _categories[id % _categories.length],
        'price': double.parse((1 + rnd.nextDouble() * 1999).toStringAsFixed(2)),
        'rating': double.parse((1 + rnd.nextDouble() * 4).toStringAsFixed(1)),
        'stock': rnd.nextInt(1000),
        'tags': List.generate(3 + rnd.nextInt(3), (_) => word()),
        'description': description(),
        'dimensions': {
          'w': double.parse((rnd.nextDouble() * 100).toStringAsFixed(1)),
          'h': double.parse((rnd.nextDouble() * 100).toStringAsFixed(1)),
          'd': double.parse((rnd.nextDouble() * 100).toStringAsFixed(1)),
        },
        'createdAt': DateTime.utc(
          2020 + rnd.nextInt(6),
          1 + rnd.nextInt(12),
          1 + rnd.nextInt(28),
          rnd.nextInt(24),
          rnd.nextInt(60),
        ).toIso8601String(),
      };
      if (id > 1) buf.write(',');
      buf.write(jsonEncode(record));
      id++;
      if (buf.length > 64 * 1024) flush();
    }
    buf.write(']');
    flush();
  } finally {
    sink.closeSync();
  }
}
