import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:my_first_app/domain/models/movie.dart';
import 'package:my_first_app/domain/models/watched_profile.dart';

/// Conta do jogador identificada por um `id` (`uid`) imutável e um `username` editável.
@immutable
class UserAccount {
  const UserAccount({
    String? id,
    required this.username,
    required this.passwordHash,
    required this.watchedMovieIds,
    required this.totalCsvCount,
    this.customMovies = const <Movie>[],
    this.highScore = 0,
  }) : id = (id != null && id != '') ? id : username;

  /// Identificador único e imutável da conta (chave do documento no banco de dados).
  final String id;
  final String username;
  final String passwordHash;
  final List<String> watchedMovieIds;
  final int totalCsvCount;
  final List<Movie> customMovies;
  final int highScore;

  static final Random _idRandom = Random();

  /// Gera um `uid` único e imutável para novas contas (ex: `usr_1934a8f1_9b4c2d1e`).
  static String generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final r1 = _idRandom.nextInt(0x7fffffff).toRadixString(16).padLeft(7, '0');
    final r2 = _idRandom.nextInt(0x7fffffff).toRadixString(16).padLeft(7, '0');
    return 'usr_${ts}_$r1$r2';
  }

  static String normalizeUsername(String input) =>
      input.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();

  /// Gera um hash determinístico de 32 caracteres hexadecimais compatível com Web (JS/Wasm) e Nativo.
  static String hashPassword(String username, String password) =>
      _computeHash('', password);

  static String _computeHash(String normUser, String password) {
    final payload = utf8.encode('gtr_salt_v1:$normUser:${password.trim()}');
    var h1 = 0x811c9dc5;
    var h2 = 0x9e3779b9;
    var h3 = 0x85ebca6b;
    var h4 = 0xc2b2ae35;
    for (final byte in payload) {
      h1 = ((h1 ^ byte) * 0x01000193) & 0xffffffff;
      h2 = ((h2 ^ (byte + 0x3d)) * 0x01000193) & 0xffffffff;
      h3 = ((h3 ^ (byte + 0x7f)) * 0x01000193) & 0xffffffff;
      h4 = ((h4 ^ (byte + 0xb5)) * 0x01000193) & 0xffffffff;
    }
    return '${h1.toRadixString(16).padLeft(8, '0')}'
        '${h2.toRadixString(16).padLeft(8, '0')}'
        '${h3.toRadixString(16).padLeft(8, '0')}'
        '${h4.toRadixString(16).padLeft(8, '0')}';
  }

  bool verifyPassword(String password) {
    if (passwordHash == _computeHash('', password)) return true;
    final normUser = normalizeUsername(username);
    if (passwordHash == _computeHash(normUser, password)) return true;
    for (final legacyUser in const ['betopeixe', 'pedrivol']) {
      if (passwordHash == _computeHash(legacyUser, password)) return true;
    }
    return false;
  }

  WatchedProfile toWatchedProfile({bool isActive = true}) {
    return WatchedProfile(
      username: username,
      watchedMovieIds: watchedMovieIds,
      totalCsvCount: totalCsvCount,
      customMovies: customMovies,
      isActive: isActive,
    );
  }

  UserAccount copyWith({
    String? id,
    String? username,
    String? passwordHash,
    List<String>? watchedMovieIds,
    int? totalCsvCount,
    List<Movie>? customMovies,
    int? highScore,
  }) {
    return UserAccount(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      watchedMovieIds: watchedMovieIds ?? this.watchedMovieIds,
      totalCsvCount: totalCsvCount ?? this.totalCsvCount,
      customMovies: customMovies ?? this.customMovies,
      highScore: highScore ?? this.highScore,
    );
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final username = json['username'];
    final passwordHash = json['passwordHash'];
    final rawIds = json['watchedMovieIds'];
    final totalCsvCount = json['totalCsvCount'];
    final rawCustom = json['customMovies'];
    final highScore = json['highScore'];

    if (username is! String || passwordHash is! String || rawIds is! List) {
      throw const FormatException('JSON inválido para UserAccount.');
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

    final normalizedUser = normalizeUsername(username);
    final effectiveId = (rawId is String && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : normalizedUser;

    return UserAccount(
      id: effectiveId,
      username: normalizedUser,
      passwordHash: passwordHash,
      watchedMovieIds: List<String>.unmodifiable(rawIds.whereType<String>()),
      totalCsvCount: totalCsvCount is num ? totalCsvCount.toInt() : 0,
      customMovies: List<Movie>.unmodifiable(parsedCustom),
      highScore: highScore is num ? highScore.toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'username': username,
    'passwordHash': passwordHash,
    'watchedMovieIds': watchedMovieIds,
    'totalCsvCount': totalCsvCount,
    'customMovies': customMovies.map((m) => m.toJson()).toList(growable: false),
    'highScore': highScore,
  };
}

/// Entrada do ranking global com `username` e `highScore`.
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.username,
    required this.highScore,
  });

  final String username;
  final int highScore;
}
