import 'dart:convert';
import 'dart:typed_data';

/// Resultado da extração de um arquivo `.zip` (ou `.csv`) exportado do Letterboxd.
class ExtractedLetterboxdData {
  const ExtractedLetterboxdData({
    required this.watchedCsvContent,
    this.suggestedUsername,
  });

  final String watchedCsvContent;
  final String? suggestedUsername;
}

/// Extrai `watched.csv` (e opcionalmente o `username` do `profile.csv` ou do nome do arquivo)
/// diretamente de um arquivo `.zip` exportado do Letterboxd, 100% em Dart puro (Web e Nativo).
class ZipWatchedExtractor {
  static bool isZipBytes(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);
  }

  static String? extractUsernameFromFileName(String fileName) {
    final match = RegExp(
      r'^letterboxd-([a-zA-Z0-9_]+)-\d{4}-\d{2}-\d{2}',
      caseSensitive: false,
    ).firstMatch(fileName.trim());
    return match?.group(1)?.toLowerCase();
  }

  static ExtractedLetterboxdData extractFromBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    if (!isZipBytes(bytes)) {
      return ExtractedLetterboxdData(
        watchedCsvContent: utf8.decode(bytes, allowMalformed: true),
        suggestedUsername: extractUsernameFromFileName(fileName),
      );
    }

    final files = _readZipEntries(bytes);
    String? watchedContent;
    String? profileContent;

    for (final entry in files.entries) {
      final lower = entry.key.toLowerCase().replaceAll('\\', '/');
      final baseName = lower.split('/').last;
      if (baseName == 'watched.csv') {
        watchedContent = utf8.decode(entry.value, allowMalformed: true);
      } else if (baseName == 'profile.csv') {
        profileContent = utf8.decode(entry.value, allowMalformed: true);
      }
    }

    if (watchedContent == null || watchedContent.trim().isEmpty) {
      throw const FormatException(
        'O arquivo .zip selecionado não contém o arquivo watched.csv do Letterboxd.',
      );
    }

    final usernameFromProfile = _extractUsernameFromProfileCsv(profileContent);
    final usernameFromFile = extractUsernameFromFileName(fileName);

    return ExtractedLetterboxdData(
      watchedCsvContent: watchedContent,
      suggestedUsername: usernameFromProfile ?? usernameFromFile,
    );
  }

  static String? _extractUsernameFromProfileCsv(String? profileCsv) {
    if (profileCsv == null || profileCsv.trim().isEmpty) return null;
    final lines = const LineSplitter().convert(profileCsv.trim());
    if (lines.length < 2) return null;
    final headers = _splitCsvRow(lines[0]);
    final values = _splitCsvRow(lines[1]);
    final userIdx = headers.indexWhere(
      (h) => h.trim().toLowerCase() == 'username',
    );
    if (userIdx >= 0 && userIdx < values.length) {
      final candidate = values[userIdx].trim().toLowerCase();
      if (candidate.isNotEmpty) return candidate;
    }
    return null;
  }

  static List<String> _splitCsvRow(String line) {
    final result = <String>[];
    final current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString());
    return result;
  }

  static Map<String, Uint8List> _readZipEntries(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final result = <String, Uint8List>{};

    // Procura o End of Central Directory (EOCD) de trás para frente
    var eocdOffset = -1;
    final minSearch = (bytes.length - 65557).clamp(0, bytes.length);
    for (var i = bytes.length - 22; i >= minSearch; i--) {
      if (data.getUint32(i, Endian.little) == 0x06054b50) {
        eocdOffset = i;
        break;
      }
    }

    if (eocdOffset != -1) {
      final totalEntries = data.getUint16(eocdOffset + 10, Endian.little);
      final cdOffset = data.getUint32(eocdOffset + 16, Endian.little);
      var ptr = cdOffset;

      for (var entryIdx = 0; entryIdx < totalEntries; entryIdx++) {
        if (ptr + 46 > bytes.length) break;
        final sig = data.getUint32(ptr, Endian.little);
        if (sig != 0x02014b50) break;

        final compressionMethod = data.getUint16(ptr + 10, Endian.little);
        final compressedSize = data.getUint32(ptr + 20, Endian.little);
        final fileNameLen = data.getUint16(ptr + 28, Endian.little);
        final extraLen = data.getUint16(ptr + 30, Endian.little);
        final commentLen = data.getUint16(ptr + 32, Endian.little);
        final localHeaderOffset = data.getUint32(ptr + 42, Endian.little);

        if (ptr + 46 + fileNameLen > bytes.length) break;
        final nameBytes = Uint8List.sublistView(
          bytes,
          ptr + 46,
          ptr + 46 + fileNameLen,
        );
        final entryName = utf8.decode(nameBytes, allowMalformed: true);
        ptr += 46 + fileNameLen + extraLen + commentLen;

        final lowerBase = entryName.toLowerCase().replaceAll('\\', '/').split('/').last;
        if (lowerBase != 'watched.csv' && lowerBase != 'profile.csv') {
          continue;
        }

        if (localHeaderOffset + 30 > bytes.length) continue;
        if (data.getUint32(localHeaderOffset, Endian.little) != 0x04034b50) {
          continue;
        }
        final localNameLen = data.getUint16(
          localHeaderOffset + 26,
          Endian.little,
        );
        final localExtraLen = data.getUint16(
          localHeaderOffset + 28,
          Endian.little,
        );
        final dataStart = localHeaderOffset + 30 + localNameLen + localExtraLen;
        final dataEnd = dataStart + compressedSize;
        if (dataEnd > bytes.length) continue;

        final compressedData = Uint8List.sublistView(bytes, dataStart, dataEnd);
        if (compressionMethod == 0) {
          result[entryName] = compressedData;
        } else if (compressionMethod == 8) {
          result[entryName] = _inflateRaw(compressedData);
        }
      }
      if (result.isNotEmpty) return result;
    }

    // Fallback: varre Local File Headers sequencialmente
    var offset = 0;
    while (offset + 30 <= bytes.length) {
      final sig = data.getUint32(offset, Endian.little);
      if (sig != 0x04034b50) break;

      final flags = data.getUint16(offset + 6, Endian.little);
      final compressionMethod = data.getUint16(offset + 8, Endian.little);
      final compressedSize = data.getUint32(offset + 18, Endian.little);
      final fileNameLen = data.getUint16(offset + 26, Endian.little);
      final extraLen = data.getUint16(offset + 28, Endian.little);

      final nameStart = offset + 30;
      final nameEnd = nameStart + fileNameLen;
      if (nameEnd > bytes.length) break;

      final entryName = utf8.decode(
        Uint8List.sublistView(bytes, nameStart, nameEnd),
        allowMalformed: true,
      );
      final dataStart = nameEnd + extraLen;
      if ((flags & 0x08) != 0 && compressedSize == 0) {
        break;
      }
      final dataEnd = dataStart + compressedSize;
      if (dataEnd > bytes.length) break;

      final lowerBase = entryName.toLowerCase().replaceAll('\\', '/').split('/').last;
      if (lowerBase == 'watched.csv' || lowerBase == 'profile.csv') {
        final payload = Uint8List.sublistView(bytes, dataStart, dataEnd);
        if (compressionMethod == 0) {
          result[entryName] = payload;
        } else if (compressionMethod == 8) {
          result[entryName] = _inflateRaw(payload);
        }
      }
      offset = dataEnd;
    }

    return result;
  }

  /// Descompressor RFC 1951 (DEFLATE raw) em Dart puro para arquivos ZIP.
  static Uint8List _inflateRaw(Uint8List src) {
    final reader = _BitReader(src);
    final out = BytesBuilder(copy: false);
    final window = Uint8List(32768);
    var winPos = 0;

    void emitByte(int b) {
      out.addByte(b);
      window[winPos] = b;
      winPos = (winPos + 1) & 0x7FFF;
    }

    var isFinal = false;
    while (!isFinal) {
      isFinal = reader.readBits(1) == 1;
      final type = reader.readBits(2);

      if (type == 0) {
        reader.alignToByte();
        final len = reader.readUint16();
        reader.readUint16(); // nlen
        for (var i = 0; i < len; i++) {
          emitByte(reader.readByte());
        }
      } else if (type == 1 || type == 2) {
        late final _HuffmanTable litLenTable;
        late final _HuffmanTable distTable;
        if (type == 1) {
          litLenTable = _HuffmanTable.fixedLitLen;
          distTable = _HuffmanTable.fixedDist;
        } else {
          final hlit = reader.readBits(5) + 257;
          final hdist = reader.readBits(5) + 1;
          final hclen = reader.readBits(4) + 4;
          const clOrder = <int>[
            16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
          ];
          final clLengths = List<int>.filled(19, 0);
          for (var i = 0; i < hclen; i++) {
            clLengths[clOrder[i]] = reader.readBits(3);
          }
          final clTable = _HuffmanTable.fromLengths(clLengths);
          final allLengths = List<int>.filled(hlit + hdist, 0);
          var idx = 0;
          while (idx < allLengths.length) {
            final sym = clTable.decode(reader);
            if (sym < 16) {
              allLengths[idx++] = sym;
            } else if (sym == 16) {
              final repeat = reader.readBits(2) + 3;
              final prev = idx > 0 ? allLengths[idx - 1] : 0;
              for (var r = 0; r < repeat && idx < allLengths.length; r++) {
                allLengths[idx++] = prev;
              }
            } else if (sym == 17) {
              final repeat = reader.readBits(3) + 3;
              idx += repeat;
            } else if (sym == 18) {
              final repeat = reader.readBits(7) + 11;
              idx += repeat;
            }
          }
          litLenTable = _HuffmanTable.fromLengths(allLengths.sublist(0, hlit));
          distTable = _HuffmanTable.fromLengths(allLengths.sublist(hlit));
        }

        while (true) {
          final sym = litLenTable.decode(reader);
          if (sym < 256) {
            emitByte(sym);
          } else if (sym == 256) {
            break;
          } else {
            final lenIdx = sym - 257;
            final length =
                _lenBase[lenIdx] + reader.readBits(_lenExtra[lenIdx]);
            final distSym = distTable.decode(reader);
            final distance =
                _distBase[distSym] + reader.readBits(_distExtra[distSym]);
            for (var i = 0; i < length; i++) {
              final b = window[(winPos - distance) & 0x7FFF];
              emitByte(b);
            }
          }
        }
      } else {
        throw const FormatException('Bloco DEFLATE inválido no arquivo .zip.');
      }
    }

    return out.takeBytes();
  }

  static const List<int> _lenBase = <int>[
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
  ];
  static const List<int> _lenExtra = <int>[
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
    3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
  ];
  static const List<int> _distBase = <int>[
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
    257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
    8193, 12289, 16385, 24577,
  ];
  static const List<int> _distExtra = <int>[
    0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
    7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
  ];
}

class _BitReader {
  _BitReader(this.bytes);

  final Uint8List bytes;
  int _bytePos = 0;
  int _bitBuf = 0;
  int _bitCount = 0;

  int readBits(int n) {
    if (n == 0) return 0;
    while (_bitCount < n) {
      final b = _bytePos < bytes.length ? bytes[_bytePos++] : 0;
      _bitBuf |= b << _bitCount;
      _bitCount += 8;
    }
    final val = _bitBuf & ((1 << n) - 1);
    _bitBuf >>= n;
    _bitCount -= n;
    return val;
  }

  void alignToByte() {
    _bitBuf = 0;
    _bitCount = 0;
  }

  int readByte() {
    alignToByte();
    return _bytePos < bytes.length ? bytes[_bytePos++] : 0;
  }

  int readUint16() {
    final lo = readByte();
    final hi = readByte();
    return lo | (hi << 8);
  }
}

class _HuffmanTable {
  _HuffmanTable(this._counts, this._symbols);

  final List<int> _counts;
  final List<int> _symbols;

  static final _HuffmanTable fixedLitLen = _buildFixedLitLen();
  static final _HuffmanTable fixedDist = _buildFixedDist();

  static _HuffmanTable _buildFixedLitLen() {
    final lengths = List<int>.filled(288, 0);
    for (var i = 0; i <= 143; i++) {
      lengths[i] = 8;
    }
    for (var i = 144; i <= 255; i++) {
      lengths[i] = 9;
    }
    for (var i = 256; i <= 279; i++) {
      lengths[i] = 7;
    }
    for (var i = 280; i <= 287; i++) {
      lengths[i] = 8;
    }
    return fromLengths(lengths);
  }

  static _HuffmanTable _buildFixedDist() {
    return fromLengths(List<int>.filled(32, 5));
  }

  static _HuffmanTable fromLengths(List<int> lengths) {
    const maxBits = 15;
    final counts = List<int>.filled(maxBits + 1, 0);
    for (final len in lengths) {
      if (len > 0) counts[len]++;
    }
    final offsets = List<int>.filled(maxBits + 1, 0);
    var total = 0;
    for (var bits = 1; bits <= maxBits; bits++) {
      offsets[bits] = total;
      total += counts[bits];
    }
    final symbols = List<int>.filled(total, 0);
    for (var sym = 0; sym < lengths.length; sym++) {
      final len = lengths[sym];
      if (len > 0) {
        symbols[offsets[len]++] = sym;
      }
    }
    return _HuffmanTable(counts, symbols);
  }

  int decode(_BitReader reader) {
    var code = 0;
    var first = 0;
    var index = 0;
    for (var len = 1; len <= 15; len++) {
      code |= reader.readBits(1);
      final count = _counts[len];
      if (code - count < first) {
        return _symbols[index + (code - first)];
      }
      index += count;
      first += count;
      first <<= 1;
      code <<= 1;
    }
    throw const FormatException('Código Huffman inválido no arquivo .zip.');
  }
}
