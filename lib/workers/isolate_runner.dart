import 'dart:async';
import 'dart:isolate';

import '../data/models/parse_result.dart';
import 'json_parser.dart';

/// Manual Isolate.spawn with a two-way handshake and live progress.
/// Worker errors arrive on the onError port and become exceptions in main.
Future<ParseResult> runWithIsolate(
  String path, {
  ProgressCallback? onProgress,
}) async {
  final receive = ReceivePort();
  final errors = ReceivePort();
  final completer = Completer<ParseResult>();
  final isolate = await Isolate.spawn<SendPort>(
    _entry,
    receive.sendPort,
    onError: errors.sendPort,
    errorsAreFatal: true,
  );

  final sub = receive.listen((msg) {
    if (msg is SendPort) {
      msg.send(path); // handshake done -> send the task
    } else if (msg is ProgressMsg) {
      onProgress?.call(msg.value, msg.stage);
    } else if (msg is ParseResult) {
      if (!completer.isCompleted) completer.complete(msg);
    }
  });
  errors.listen((e) {
    // e is a two-element list: [errorString, stackTraceString].
    if (!completer.isCompleted) {
      completer.completeError(StateError('Isolate error: $e'));
    }
  });

  try {
    return await completer.future;
  } finally {
    await sub.cancel();
    receive.close();
    errors.close();
    isolate.kill(priority: Isolate.immediate);
  }
}

/// Top-level entry point of the worker isolate.
void _entry(SendPort mainPort) {
  final port = ReceivePort();
  mainPort.send(port.sendPort); // handshake
  port.listen((msg) {
    if (msg is String) {
      final result = parseJsonFileWithProgress(
        msg,
        (v, s) => mainPort.send(ProgressMsg(v, s)),
      );
      mainPort.send(result);
      port.close();
    }
  });
}
