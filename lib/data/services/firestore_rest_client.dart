import 'package:my_first_app/domain/models/movie.dart';
import 'package:my_first_app/domain/models/user_account.dart';

import 'firestore_rest_client_io.dart'
    if (dart.library.js_interop) 'firestore_rest_client_web.dart' as impl;

/// Cliente leve para sincronizar `UserAccount` com a coleção `accounts/{username}` do Cloud Firestore.
class FirestoreAccountClient {
  const FirestoreAccountClient({
    this.projectId = const String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'guesstherating',
    ),
    this.databaseId = const String.fromEnvironment(
      'FIRESTORE_DATABASE_ID',
      defaultValue: '(default)',
    ),
  });

  final String projectId;
  final String databaseId;

  bool get isConfigured => projectId.trim().isNotEmpty;

  String _docUrl(String username) {
    final norm = UserAccount.normalizeUsername(username);
    final encodedDb = Uri.encodeComponent(databaseId);
    return 'https://firestore.googleapis.com/v1/projects/$projectId/databases/$encodedDb/documents/accounts/$norm';
  }

  Future<UserAccount?> fetchAccount(String username) async {
    if (!isConfigured) return null;
    final raw = await impl.httpGetJson(_docUrl(username));
    if (raw == null) return null;
    return decodeFirestoreDocument(raw);
  }

  Future<bool> upsertAccount(UserAccount account) async {
    if (!isConfigured) return false;
    final body = encodeFirestoreDocument(account);
    return impl.httpPatchJson(_docUrl(account.username), body);
  }

  static Map<String, dynamic> encodeFirestoreDocument(UserAccount account) {
    return <String, dynamic>{
      'fields': <String, dynamic>{
        'username': <String, dynamic>{'stringValue': account.username},
        'passwordHash': <String, dynamic>{'stringValue': account.passwordHash},
        'totalCsvCount': <String, dynamic>{
          'integerValue': account.totalCsvCount.toString(),
        },
        'highScore': <String, dynamic>{
          'integerValue': account.highScore.toString(),
        },
        'watchedMovieIds': <String, dynamic>{
          'arrayValue': <String, dynamic>{
            'values': account.watchedMovieIds
                .map((id) => <String, dynamic>{'stringValue': id})
                .toList(growable: false),
          },
        },
        'customMovies': <String, dynamic>{
          'arrayValue': <String, dynamic>{
            'values': account.customMovies
                .map(
                  (m) => <String, dynamic>{
                    'mapValue': <String, dynamic>{
                      'fields': <String, dynamic>{
                        'id': <String, dynamic>{'stringValue': m.id},
                        'title': <String, dynamic>{'stringValue': m.title},
                        'originalTitle': <String, dynamic>{
                          'stringValue': m.originalTitle,
                        },
                        'year': <String, dynamic>{
                          'integerValue': m.year.toString(),
                        },
                        'director': <String, dynamic>{
                          'stringValue': m.director,
                        },
                        'rating': <String, dynamic>{'doubleValue': m.rating},
                        'posterUrl': <String, dynamic>{
                          'stringValue': m.posterUrl,
                        },
                      },
                    },
                  },
                )
                .toList(growable: false),
          },
        },
      },
    };
  }

  static UserAccount? decodeFirestoreDocument(Map<String, dynamic> doc) {
    final fields = doc['fields'] as Map<String, dynamic>?;
    if (fields == null) return null;

    String? readString(Map<String, dynamic>? f) => f?['stringValue'] as String?;
    int readInt(Map<String, dynamic>? f) {
      final iv = f?['integerValue'];
      if (iv is int) return iv;
      if (iv is String) return int.tryParse(iv) ?? 0;
      return 0;
    }

    double readDouble(Map<String, dynamic>? f) {
      final dv = f?['doubleValue'];
      if (dv is num) return dv.toDouble();
      final iv = f?['integerValue'];
      if (iv is String) return double.tryParse(iv) ?? 0.0;
      return 0.0;
    }

    final username = readString(fields['username'] as Map<String, dynamic>?);
    final passwordHash = readString(
      fields['passwordHash'] as Map<String, dynamic>?,
    );
    if (username == null || passwordHash == null) return null;

    final rawWatchedValues =
        ((fields['watchedMovieIds'] as Map<String, dynamic>?)?['arrayValue']
                as Map<String, dynamic>?)?['values']
            as List?;
    final watchedIds = <String>[
      if (rawWatchedValues != null)
        for (final item in rawWatchedValues)
          if (item is Map<String, dynamic> && item['stringValue'] is String)
            item['stringValue'] as String,
    ];

    final rawCustomValues =
        ((fields['customMovies'] as Map<String, dynamic>?)?['arrayValue']
                as Map<String, dynamic>?)?['values']
            as List?;
    final customMovies = <Movie>[];
    if (rawCustomValues != null) {
      for (final item in rawCustomValues) {
        if (item is! Map<String, dynamic>) continue;
        final mf =
            (item['mapValue'] as Map<String, dynamic>?)?['fields']
                as Map<String, dynamic>?;
        if (mf == null) continue;
        final id = readString(mf['id'] as Map<String, dynamic>?);
        final title = readString(mf['title'] as Map<String, dynamic>?);
        final orig = readString(mf['originalTitle'] as Map<String, dynamic>?);
        final director = readString(mf['director'] as Map<String, dynamic>?);
        final poster = readString(mf['posterUrl'] as Map<String, dynamic>?);
        final year = readInt(mf['year'] as Map<String, dynamic>?);
        final rating = readDouble(mf['rating'] as Map<String, dynamic>?);
        if (id != null &&
            title != null &&
            poster != null &&
            year > 0 &&
            rating > 0) {
          customMovies.add(
            Movie(
              id: id,
              title: title,
              originalTitle: orig ?? title,
              year: year,
              director: director ?? 'Direção creditada',
              rating: rating,
              posterUrl: poster,
            ),
          );
        }
      }
    }

    return UserAccount(
      username: username,
      passwordHash: passwordHash,
      watchedMovieIds: watchedIds,
      totalCsvCount: readInt(fields['totalCsvCount'] as Map<String, dynamic>?),
      customMovies: customMovies,
      highScore: readInt(fields['highScore'] as Map<String, dynamic>?),
    );
  }
}
