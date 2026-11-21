import 'dart:async';
import 'dart:js_interop';
import 'package:my_first_app/ui/core/utils/csv_file_picker.dart';
import 'package:web/web.dart' as web;

Future<PickedCsvFile?> pickCsvFileImpl() {
  final completer = Completer<PickedCsvFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept =
        '.zip,.csv,application/zip,application/x-zip-compressed,text/csv,text/comma-separated-values,application/csv,application/octet-stream';

  input.onchange = ((web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.item(0);
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final reader = web.FileReader();
    reader.onload = ((web.Event _) {
      try {
        final result = reader.result;
        if (result == null) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        final buffer = (result as JSArrayBuffer).toDart;
        final bytes = buffer.asUint8List();
        final picked = PickedCsvFile.fromBytes(
          name: file.name,
          bytes: bytes,
        );
        if (!completer.isCompleted) {
          completer.complete(picked);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    }).toJS;
    reader.onerror = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }).toJS;
    reader.readAsArrayBuffer(file);
  }).toJS;

  input.click();
  return completer.future;
}
