import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:my_first_app/domain/models/movie.dart';

/// Filme presente no `watched.csv` do jogador que ainda não consta no `movies.json` local.
@immutable
class UnmatchedCsvFilm {
  const UnmatchedCsvFilm({
    required this.name,
    required this.year,
    required this.letterboxdUri,
    required this.boxdId,
  });

  final String name;
  final int year;
  final String letterboxdUri;
  final String boxdId;
}

/// Perfil local do jogador com os filmes assistidos importados do Letterboxd (`watched.csv`).
@immutable
class WatchedProfile {
  const WatchedProfile({
    required this.username,
    required this.watchedMovieIds,
    required this.totalCsvCount,
    this.customMovies = const <Movie>[],
    this.isActive = true,
  });

  final String username;
  final List<String> watchedMovieIds;
  final int totalCsvCount;
  final List<Movie> customMovies;
  final bool isActive;

  WatchedProfile copyWith({
    String? username,
    List<String>? watchedMovieIds,
    int? totalCsvCount,
    List<Movie>? customMovies,
    bool? isActive,
  }) {
    return WatchedProfile(
      username: username ?? this.username,
      watchedMovieIds: watchedMovieIds ?? this.watchedMovieIds,
      totalCsvCount: totalCsvCount ?? this.totalCsvCount,
      customMovies: customMovies ?? this.customMovies,
      isActive: isActive ?? this.isActive,
    );
  }

  factory WatchedProfile.fromJson(Map<String, dynamic> json) {
    final username = json['username'];
    final rawIds = json['watchedMovieIds'];
    final totalCsvCount = json['totalCsvCount'];
    final rawCustom = json['customMovies'];
    final isActive = json['isActive'];

    if (username is! String || rawIds is! List) {
      throw const FormatException('JSON inválido para WatchedProfile.');
    }

    final parsedCustom = <Movie>[];
    if (rawCustom is List) {
      for (final item in rawCustom) {
        if (item is Map<String, dynamic>) {
          try {
            parsedCustom.add(Movie.fromJson(item));
          } catch (_) {}
        }
      }
    }

    return WatchedProfile(
      username: username,
      watchedMovieIds: List<String>.unmodifiable(rawIds.whereType<String>()),
      totalCsvCount: totalCsvCount is num ? totalCsvCount.toInt() : 0,
      customMovies: List<Movie>.unmodifiable(parsedCustom),
      isActive: isActive is bool ? isActive : true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'username': username,
    'watchedMovieIds': watchedMovieIds,
    'totalCsvCount': totalCsvCount,
    'customMovies': customMovies.map((m) => m.toJson()).toList(growable: false),
    'isActive': isActive,
  };
}

/// Resultado do cruzamento do `watched.csv` do jogador com o catálogo do jogo.
@immutable
class WatchedCsvMatchResult {
  const WatchedCsvMatchResult({
    required this.matchedMovies,
    required this.unmatchedEntries,
    required this.totalCsvRows,
  });

  final List<Movie> matchedMovies;
  final List<UnmatchedCsvFilm> unmatchedEntries;
  final int totalCsvRows;
}

/// Utilitário para ler o arquivo `watched.csv` do Letterboxd, cruzar com o catálogo
/// e extrair metadados de filmes fora do catálogo.
abstract final class WatchedCsvParser {
  static WatchedCsvMatchResult matchAgainstCatalog({
    required String csvContent,
    required List<Movie> catalog,
  }) {
    final byId = <String, Movie>{};
    final byNormTitleYear = <String, Movie>{};

    for (final movie in catalog) {
      byId[movie.id] = movie;
      final normTitle = _normalizeTitle(movie.title);
      final normOrig = _normalizeTitle(movie.originalTitle);
      final normId = movie.id
          .replaceFirst(RegExp(r'^boxd_'), '')
          .replaceAll('_', '')
          .toLowerCase();
      byNormTitleYear['$normTitle|${movie.year}'] = movie;
      byNormTitleYear['$normOrig|${movie.year}'] = movie;
      byNormTitleYear['$normId|${movie.year}'] = movie;
    }

    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty) {
      throw const FormatException('O arquivo CSV está vazio.');
    }

    var startIdx = 0;
    var nameCol = 1;
    var yearCol = 2;
    var uriCol = 3;

    final headerCols = _parseCsvLine(lines.first)
        .map((c) => c.trim().toLowerCase())
        .toList(growable: false);
    if (headerCols.contains('name') || headerCols.contains('letterboxd uri')) {
      startIdx = 1;
      final foundName = headerCols.indexOf('name');
      final foundYear = headerCols.indexOf('year');
      final foundUri = headerCols.indexOf('letterboxd uri');
      if (foundName >= 0) nameCol = foundName;
      if (foundYear >= 0) yearCol = foundYear;
      if (foundUri >= 0) uriCol = foundUri;
    }

    final matchedById = <String, Movie>{};
    final unmatchedById = <String, UnmatchedCsvFilm>{};
    var validRows = 0;

    for (var i = startIdx; i < lines.length; i++) {
      final cols = _parseCsvLine(lines[i]);
      if (cols.length <= nameCol) continue;

      final name = cols[nameCol].trim();
      final year = cols.length > yearCol
          ? (int.tryParse(cols[yearCol].trim()) ?? 0)
          : 0;
      final uri = cols.length > uriCol ? cols[uriCol].trim() : '';

      if (name.isEmpty && uri.isEmpty) continue;
      validRows++;

      Movie? found;
      final lid = RegExp(r'boxd\.it/([A-Za-z0-9_]+)')
          .firstMatch(uri)
          ?.group(1);
      if (lid != null) {
        found = byId['boxd_$lid'];
      }

      if (found == null && name.isNotEmpty && year > 0) {
        final norm = _normalizeTitle(name);
        found = byNormTitleYear['$norm|$year'] ??
            byNormTitleYear['$norm|${year - 1}'] ??
            byNormTitleYear['$norm|${year + 1}'];
      }

      if (found != null) {
        matchedById[found.id] = found;
      } else if (name.isNotEmpty && uri.startsWith('http')) {
        final boxdId = lid != null
            ? 'boxd_$lid'
            : 'custom_${_normalizeTitle(name)}_$year';
        unmatchedById[boxdId] = UnmatchedCsvFilm(
          name: name,
          year: year,
          letterboxdUri: uri,
          boxdId: boxdId,
        );
      }
    }

    return WatchedCsvMatchResult(
      matchedMovies: matchedById.values.toList(growable: false),
      unmatchedEntries: unmatchedById.values.toList(growable: false),
      totalCsvRows: validRows,
    );
  }

  /// Extrai um objeto `Movie` a partir do HTML da página do filme no Letterboxd.
  static Movie? parseMovieFromLetterboxdHtml({
    required UnmatchedCsvFilm entry,
    required String html,
  }) {
    String? ldTitle;
    String? director;
    double? rating;
    int ratingCount = 0;
    String? posterUrl;

    final ldMatch = RegExp(
      r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);

    if (ldMatch != null) {
      final rawLd = ldMatch
          .group(1)!
          .replaceAll('/* <![CDATA[ */', '')
          .replaceAll('/* ]]> */', '')
          .trim();
      try {
        final ld = jsonDecode(rawLd) as Map<String, dynamic>;
        ldTitle = (ld['name'] as String?)?.trim();
        posterUrl = (ld['image'] as String?)?.trim();
        final agg = ld['aggregateRating'] as Map<String, dynamic>?;
        final rv = agg?['ratingValue'];
        if (rv is num) {
          rating = rv.toDouble();
        } else if (rv is String) {
          rating = double.tryParse(rv);
        }
        final rc = agg?['ratingCount'];
        if (rc is num) {
          ratingCount = rc.toInt();
        } else if (rc is String) {
          ratingCount = int.tryParse(rc.replaceAll(',', '').trim()) ?? 0;
        }
        final dirs = ld['director'];
        if (dirs is List && dirs.isNotEmpty) {
          director = dirs
              .map((d) => (d as Map<String, dynamic>)['name'] as String?)
              .whereType<String>()
              .join(', ');
        }
      } catch (_) {}
    }

    if (rating == null) {
      final tw2 = RegExp(r'twitter:data2"\s+content="([0-9.]+)\s+out of 5"')
          .firstMatch(html)
          ?.group(1);
      if (tw2 != null) rating = double.tryParse(tw2);
    }

    director ??= RegExp(r'twitter:data1"\s+content="([^"]+)"')
        .firstMatch(html)
        ?.group(1);

    var year = entry.year;
    if (year <= 0) {
      final ogTitle = RegExp(r'property="og:title"\s+content="([^"]+)"')
          .firstMatch(html)
          ?.group(1);
      if (ogTitle != null) {
        final ym = RegExp(r'\((\d{4})\)').firstMatch(ogTitle);
        if (ym != null) year = int.tryParse(ym.group(1)!) ?? 0;
      }
    }

    if (rating == null ||
        rating < 0.5 ||
        rating > 5.0 ||
        year <= 0 ||
        posterUrl == null ||
        posterUrl.isEmpty) {
      return null;
    }

    final cleanTitle = _decodeHtmlEntities(
      (ldTitle != null && ldTitle.isNotEmpty) ? ldTitle : entry.name,
    );
    final origTag = RegExp(
      r'<em[^>]*class="[^"]*originalname[^"]*"[^>]*>(.*?)</em>',
      dotAll: true,
    ).firstMatch(html)?.group(1);
    final origTitle = origTag != null
        ? _decodeHtmlEntities(
            origTag.replaceAll(RegExp(r'<[^>]+>'), ''),
          ).trim()
        : cleanTitle;

    return Movie(
      id: entry.boxdId,
      title: cleanTitle,
      originalTitle: origTitle.isNotEmpty ? origTitle : cleanTitle,
      year: year,
      director: (director == null || director.trim().isEmpty)
          ? 'Direção creditada'
          : _decodeHtmlEntities(director).trim(),
      rating: double.parse(rating.toStringAsFixed(2)),
      ratingCount: ratingCount,
      posterUrl: posterUrl,
    );
  }

  static String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }

  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            sb.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          sb.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          fields.add(sb.toString());
          sb.clear();
        } else {
          sb.write(ch);
        }
      }
    }
    fields.add(sb.toString());
    return fields;
  }

  static String _normalizeTitle(String input) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ–—';
    const to = 'aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn--';
    var s = input;
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    s = s.toLowerCase();
    s = s.replaceAll('&', 'and');
    s = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return s;
  }
}
