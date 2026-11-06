import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:my_first_app/domain/models/movie.dart';
import 'package:my_first_app/domain/models/watched_profile.dart';

/// Conta do jogador identificada por `@nick` + senha/PIN, guardando sua pool de filmes e recorde.
@immutable
class UserAccount {
  const UserAccount({
    required this.username,
    required this.passwordHash,
    required this.watchedMovieIds,
    required this.totalCsvCount,
    this.customMovies = const <Movie>[],
    this.highScore = 0,
  });

  final String username;
  final String passwordHash;
  final List<String> watchedMovieIds;
  final int totalCsvCount;
  final List<Movie> customMovies;
  final int highScore;

  static String normalizeUsername(String input) =>
      input.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();

  /// Gera um hash determinístico de 32 caracteres hexadecimais compatível com Web (JS/Wasm) e Nativo.
  static String hashPassword(String username, String password) {
    final normUser = normalizeUsername(username);
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

  bool verifyPassword(String password) =>
      passwordHash == hashPassword(username, password);

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
    String? username,
    String? passwordHash,
    List<String>? watchedMovieIds,
    int? totalCsvCount,
    List<Movie>? customMovies,
    int? highScore,
  }) {
    return UserAccount(
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      watchedMovieIds: watchedMovieIds ?? this.watchedMovieIds,
      totalCsvCount: totalCsvCount ?? this.totalCsvCount,
      customMovies: customMovies ?? this.customMovies,
      highScore: highScore ?? this.highScore,
    );
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
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

    return UserAccount(
      username: username,
      passwordHash: passwordHash,
      watchedMovieIds: List<String>.unmodifiable(rawIds.whereType<String>()),
      totalCsvCount: totalCsvCount is num ? totalCsvCount.toInt() : 0,
      customMovies: List<Movie>.unmodifiable(parsedCustom),
      highScore: highScore is num ? highScore.toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'username': username,
    'passwordHash': passwordHash,
    'watchedMovieIds': watchedMovieIds,
    'totalCsvCount': totalCsvCount,
    'customMovies': customMovies.map((m) => m.toJson()).toList(growable: false),
    'highScore': highScore,
  };
}
