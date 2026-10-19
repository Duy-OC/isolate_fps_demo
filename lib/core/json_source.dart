import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../data/json_generator.dart';

/// A JSON file ready to benchmark (generated or user-picked).
class JsonSource {
  const JsonSource(this.path, this.bytes, this.label);

  final String path;
  final int bytes;
  final String label;
}

/// Generate (or reuse) a deterministic file of [mb] megabytes in the temp dir.
Future<JsonSource> generateSource(int mb) async {
  final dir = (await getTemporaryDirectory()).path;
  final f = await ensureJsonFile(dir: dir, targetBytes: mb * 1024 * 1024);
  return JsonSource(f.path, await f.length(), 'generated_${mb}mb.json');
}

/// Pick any local .json file. Only the path is read here – the main isolate
/// never touches the content.
Future<JsonSource?> pickSource() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (files.isEmpty) return null; // cancelled
  final file = files.single;
  if (file.path == null) return null; // no local path (e.g. some web cases)
  return JsonSource(file.path!, await File(file.path!).length(), file.name);
}
