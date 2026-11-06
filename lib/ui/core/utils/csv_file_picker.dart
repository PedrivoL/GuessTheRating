import 'package:flutter/foundation.dart';

import 'csv_file_picker_stub.dart'
    if (dart.library.js_interop) 'csv_file_picker_web.dart' as impl;

/// Arquivo CSV selecionado pelo usuário.
@immutable
class PickedCsvFile {
  const PickedCsvFile({required this.name, required this.content});

  final String name;
  final String content;
}

typedef CsvFilePickerCallback = Future<PickedCsvFile?> Function();

/// Abre o seletor de arquivo `.csv` na plataforma atual.
Future<PickedCsvFile?> pickCsvFile() => impl.pickCsvFileImpl();
