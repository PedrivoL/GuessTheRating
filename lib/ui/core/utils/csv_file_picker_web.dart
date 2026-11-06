import 'dart:async';
import 'dart:js_interop';
import 'package:my_first_app/ui/core/utils/csv_file_picker.dart';
import 'package:web/web.dart' as web;

Future<PickedCsvFile?> pickCsvFileImpl() {
  final completer = Completer<PickedCsvFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.csv,text/csv';

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
      final result = reader.result;
      final text = (result as JSString?)?.toDart ?? '';
      if (!completer.isCompleted) {
        completer.complete(PickedCsvFile(name: file.name, content: text));
      }
    }).toJS;
    reader.onerror = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }).toJS;
    reader.readAsText(file);
  }).toJS;

  input.click();
  return completer.future;
}
