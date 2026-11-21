import 'package:flutter/foundation.dart';
import 'package:my_first_app/ui/core/utils/zip_watched_extractor.dart';

import 'csv_file_picker_stub.dart'
    if (dart.library.js_interop) 'csv_file_picker_web.dart' as impl;

/// Arquivo `.csv` ou `.zip` (contendo `watched.csv`) selecionado pelo usuário.
@immutable
class PickedCsvFile {
  const PickedCsvFile({
    required this.name,
    required this.content,
    this.suggestedUsername,
  });

  /// Cria um `PickedCsvFile` a partir dos bytes brutos de um arquivo `.zip` ou `.csv`.
  factory PickedCsvFile.fromBytes({
    required String name,
    required Uint8List bytes,
  }) {
    final extracted = ZipWatchedExtractor.extractFromBytes(
      fileName: name,
      bytes: bytes,
    );
    return PickedCsvFile(
      name: name,
      content: extracted.watchedCsvContent,
      suggestedUsername: extracted.suggestedUsername,
    );
  }

  final String name;
  final String content;
  final String? suggestedUsername;
}

typedef CsvFilePickerCallback = Future<PickedCsvFile?> Function();

/// Abre o seletor de arquivo `.zip` ou `.csv` na plataforma atual.
Future<PickedCsvFile?> pickCsvFile() => impl.pickCsvFileImpl();
