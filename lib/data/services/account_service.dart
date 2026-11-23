import 'dart:async';
import 'dart:convert';
import 'package:my_first_app/data/services/firestore_rest_client.dart';
import 'package:my_first_app/domain/models/movie.dart';
import 'package:my_first_app/domain/models/user_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrato para gerenciamento de contas com `id` (`uid`) imutável e `username` editável.
abstract interface class AccountService {
  Future<UserAccount?> loadActiveSessionAccount();
  Future<UserAccount?> findAccountByUsername(String username);
  Future<List<LeaderboardEntry>> fetchLeaderboard();
  Future<UserAccount> registerAccount({
    required String username,
    required String password,
    required List<String> watchedMovieIds,
    required int totalCsvCount,
    required List<Movie> customMovies,
    required int initialHighScore,
  });
  Future<UserAccount> login({
    required String username,
    required String password,
  });
  Future<UserAccount> updateAccount(UserAccount account);
  Future<UserAccount> renameAccount({
    required String oldUsername,
    required String newUsername,
  });
  Future<void> logout();
}

/// Implementação persistente via SharedPreferences + sincronização na nuvem com Cloud Firestore.
/// Cada conta possui um `id` (`uid`) fixo como chave do documento `/accounts/{id}` e um `username` editável.
class SharedPrefsAccountService implements AccountService {
  const SharedPrefsAccountService({
    this.firestoreClient = const FirestoreAccountClient(),
  });

  final FirestoreAccountClient firestoreClient;

  static const String _accountsMapKey = 'letterboxd_accounts_registry_v1';
  static const String _activeAccountIdKey = 'letterboxd_active_account_id_v1';
  static const String _legacyActiveUsernameKey =
      'letterboxd_active_account_nick_v1';

  Future<Map<String, UserAccount>> _readAllAccounts(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_accountsMapKey);
    if (raw == null || raw.isEmpty) return <String, UserAccount>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, UserAccount>{};
      for (final entry in decoded.entries) {
        if (entry.value is Map<String, dynamic>) {
          final acc = UserAccount.fromJson(entry.value as Map<String, dynamic>);
          result[acc.id] = acc;
        }
      }
      return result;
    } catch (_) {
      return <String, UserAccount>{};
    }
  }

  Future<void> _writeAllAccounts(
    SharedPreferences prefs,
    Map<String, UserAccount> accountsById,
  ) async {
    final serializable = <String, dynamic>{
      for (final acc in accountsById.values) acc.id: acc.toJson(),
    };
    await prefs.setString(_accountsMapKey, jsonEncode(serializable));
  }

  UserAccount? _findLocalByUsername(
    Map<String, UserAccount> accountsById,
    String normalizedUsername,
  ) {
    for (final acc in accountsById.values) {
      if (UserAccount.normalizeUsername(acc.username) == normalizedUsername) {
        return acc;
      }
    }
    return null;
  }

  @override
  Future<UserAccount?> loadActiveSessionAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsById = await _readAllAccounts(prefs);

    var activeId = prefs.getString(_activeAccountIdKey);
    if (activeId == null || activeId.isEmpty) {
      final legacyNick = prefs.getString(_legacyActiveUsernameKey);
      if (legacyNick == null || legacyNick.isEmpty) return null;
      final normLegacy = UserAccount.normalizeUsername(legacyNick);
      final migratedLocal =
          _findLocalByUsername(accountsById, normLegacy) ??
          accountsById[normLegacy];
      if (migratedLocal != null) {
        activeId = migratedLocal.id;
        await prefs.setString(_activeAccountIdKey, activeId);
      } else if (firestoreClient.isConfigured) {
        final remote = await firestoreClient.fetchAccount(normLegacy);
        if (remote != null) {
          accountsById[remote.id] = remote;
          await _writeAllAccounts(prefs, accountsById);
          await prefs.setString(_activeAccountIdKey, remote.id);
          return remote;
        }
        return null;
      } else {
        return null;
      }
    }

    final local = accountsById[activeId];
    if (firestoreClient.isConfigured) {
      final remote = await firestoreClient.fetchAccountById(activeId);
      if (remote != null) {
        accountsById[remote.id] = remote;
        await _writeAllAccounts(prefs, accountsById);
        return remote;
      }
    }
    return local;
  }

  @override
  Future<UserAccount?> findAccountByUsername(String username) async {
    final norm = UserAccount.normalizeUsername(username);
    if (norm.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final accountsById = await _readAllAccounts(prefs);
    if (firestoreClient.isConfigured) {
      final remote = await firestoreClient.fetchAccount(norm);
      if (remote != null) {
        accountsById.removeWhere(
          (id, acc) =>
              id != remote.id &&
              UserAccount.normalizeUsername(acc.username) == norm,
        );
        accountsById[remote.id] = remote;
        await _writeAllAccounts(prefs, accountsById);
        return remote;
      }
    }
    return _findLocalByUsername(accountsById, norm);
  }

  @override
  Future<UserAccount> registerAccount({
    required String username,
    required String password,
    required List<String> watchedMovieIds,
    required int totalCsvCount,
    required List<Movie> customMovies,
    required int initialHighScore,
  }) async {
    final norm = UserAccount.normalizeUsername(username);
    if (norm.isEmpty) {
      throw const FormatException('Informe um username válido.');
    }
    if (password.trim().length < 3) {
      throw const FormatException(
        'A senha/PIN precisa ter pelo menos 3 caracteres.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final accountsById = await _readAllAccounts(prefs);
    var existing = _findLocalByUsername(accountsById, norm);
    if (existing == null && firestoreClient.isConfigured) {
      existing = await firestoreClient.fetchAccount(norm);
    }
    if (existing != null && !existing.verifyPassword(password)) {
      throw FormatException(
        'O username @$norm já possui conta cadastrada. Use a aba Entrar com a senha correta.',
      );
    }

    final accountId = existing?.id ?? UserAccount.generateId();
    final account = UserAccount(
      id: accountId,
      username: norm,
      passwordHash: UserAccount.hashPassword(norm, password),
      watchedMovieIds: List<String>.unmodifiable(watchedMovieIds),
      totalCsvCount: totalCsvCount,
      customMovies: List<Movie>.unmodifiable(customMovies),
      highScore: existing != null && existing.highScore > initialHighScore
          ? existing.highScore
          : initialHighScore,
    );

    accountsById[account.id] = account;
    await _writeAllAccounts(prefs, accountsById);
    await prefs.setString(_activeAccountIdKey, account.id);
    await prefs.setString(_legacyActiveUsernameKey, account.username);
    if (firestoreClient.isConfigured) {
      unawaited(firestoreClient.upsertAccount(account));
    }
    return account;
  }

  @override
  Future<UserAccount> login({
    required String username,
    required String password,
  }) async {
    final norm = UserAccount.normalizeUsername(username);
    if (norm.isEmpty) {
      throw const FormatException('Informe o seu username.');
    }

    final prefs = await SharedPreferences.getInstance();
    final accountsById = await _readAllAccounts(prefs);
    var account = _findLocalByUsername(accountsById, norm);
    if (firestoreClient.isConfigured) {
      final remote = await firestoreClient.fetchAccount(norm);
      if (remote != null) {
        account = remote;
        accountsById[remote.id] = remote;
        await _writeAllAccounts(prefs, accountsById);
      }
    }
    if (account == null) {
      throw FormatException(
        'Conta @$norm não encontrada. Crie sua conta na aba ao lado.',
      );
    }
    if (!account.verifyPassword(password)) {
      throw const FormatException('Senha/PIN incorreto para esta conta.');
    }

    await prefs.setString(_activeAccountIdKey, account.id);
    await prefs.setString(_legacyActiveUsernameKey, account.username);
    return account;
  }

  @override
  Future<UserAccount> updateAccount(UserAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    final accountsById = await _readAllAccounts(prefs);
    accountsById[account.id] = account;
    await _writeAllAccounts(prefs, accountsById);
    if (firestoreClient.isConfigured) {
      unawaited(firestoreClient.upsertAccount(account));
    }
    return account;
  }

  @override
  Future<UserAccount> renameAccount({
    required String oldUsername,
    required String newUsername,
  }) async {
    final normOld = UserAccount.normalizeUsername(oldUsername);
    final normNew = UserAccount.normalizeUsername(newUsername);
    if (normNew.isEmpty || normNew.length > 40) {
      throw const FormatException('Informe um novo username válido.');
    }

    final prefs = await SharedPreferences.getInstance();
    final accountsById = await _readAllAccounts(prefs);
    final activeId = prefs.getString(_activeAccountIdKey);

    UserAccount? current;
    if (activeId != null && activeId.isNotEmpty) {
      current = accountsById[activeId];
      if (current == null && firestoreClient.isConfigured) {
        current = await firestoreClient.fetchAccountById(activeId);
      }
    }
    current ??= _findLocalByUsername(accountsById, normOld);
    if (current == null && firestoreClient.isConfigured) {
      current = await firestoreClient.fetchAccount(normOld);
    }
    if (current == null) {
      throw FormatException('Conta @$normOld não encontrada.');
    }
    if (UserAccount.normalizeUsername(current.username) == normNew) {
      return current;
    }

    var conflict = _findLocalByUsername(accountsById, normNew);
    if (conflict == null && firestoreClient.isConfigured) {
      conflict = await firestoreClient.fetchAccount(normNew);
    }
    if (conflict != null && conflict.id != current.id) {
      throw FormatException(
        'O username @$normNew já está sendo usado por outra conta.',
      );
    }

    // Mantém o mesmo `id` (`uid`) imutável do documento e atualiza apenas o campo `username`
    final renamed = current.copyWith(username: normNew);
    accountsById[renamed.id] = renamed;
    await _writeAllAccounts(prefs, accountsById);
    await prefs.setString(_activeAccountIdKey, renamed.id);
    await prefs.setString(_legacyActiveUsernameKey, renamed.username);

    if (firestoreClient.isConfigured) {
      await firestoreClient.upsertAccount(renamed);
    }
    return renamed;
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeAccountIdKey);
    await prefs.remove(_legacyActiveUsernameKey);
  }

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    final localAccounts = await _readAllAccounts(prefs);
    final scoreByUsername = <String, int>{
      for (final acc in localAccounts.values)
        UserAccount.normalizeUsername(acc.username): acc.highScore,
    };

    if (firestoreClient.isConfigured) {
      final remoteEntries = await firestoreClient.fetchLeaderboard();
      for (final entry in remoteEntries) {
        final norm = UserAccount.normalizeUsername(entry.username);
        if (norm.isEmpty) continue;
        final existing = scoreByUsername[norm];
        if (existing == null || entry.highScore > existing) {
          scoreByUsername[norm] = entry.highScore;
        }
      }
    }

    final entries = <LeaderboardEntry>[
      for (final e in scoreByUsername.entries)
        if (e.key.isNotEmpty)
          LeaderboardEntry(username: e.key, highScore: e.value),
    ];
    entries.sort((a, b) {
      final cmp = b.highScore.compareTo(a.highScore);
      if (cmp != 0) return cmp;
      return a.username.compareTo(b.username);
    });
    return entries;
  }
}

/// Implementação em memória para testes e Widget Previews.
class InMemoryAccountService implements AccountService {
  InMemoryAccountService({
    Map<String, UserAccount>? initialAccounts,
    String? activeUsername,
  }) : _accountsById = <String, UserAccount>{} {
    if (initialAccounts != null) {
      for (final acc in initialAccounts.values) {
        _accountsById[acc.id] = acc;
      }
    }
    if (activeUsername != null) {
      final norm = UserAccount.normalizeUsername(activeUsername);
      final match = _findByUsername(norm);
      _activeAccountId = match?.id;
    }
  }

  final Map<String, UserAccount> _accountsById;
  String? _activeAccountId;

  UserAccount? _findByUsername(String normalizedUsername) {
    for (final acc in _accountsById.values) {
      if (UserAccount.normalizeUsername(acc.username) == normalizedUsername) {
        return acc;
      }
    }
    return null;
  }

  @override
  Future<UserAccount?> loadActiveSessionAccount() async {
    if (_activeAccountId == null) return null;
    return _accountsById[_activeAccountId!];
  }

  @override
  Future<UserAccount?> findAccountByUsername(String username) async {
    final norm = UserAccount.normalizeUsername(username);
    return _findByUsername(norm);
  }

  @override
  Future<UserAccount> registerAccount({
    required String username,
    required String password,
    required List<String> watchedMovieIds,
    required int totalCsvCount,
    required List<Movie> customMovies,
    required int initialHighScore,
  }) async {
    final norm = UserAccount.normalizeUsername(username);
    if (norm.isEmpty) {
      throw const FormatException('Informe um username válido.');
    }
    if (password.trim().length < 3) {
      throw const FormatException(
        'A senha/PIN precisa ter pelo menos 3 caracteres.',
      );
    }
    final existing = _findByUsername(norm);
    if (existing != null && !existing.verifyPassword(password)) {
      throw FormatException(
        'O username @$norm já possui conta cadastrada. Use a aba Entrar com a senha correta.',
      );
    }

    final accountId = existing?.id ?? UserAccount.generateId();
    final account = UserAccount(
      id: accountId,
      username: norm,
      passwordHash: UserAccount.hashPassword(norm, password),
      watchedMovieIds: List<String>.unmodifiable(watchedMovieIds),
      totalCsvCount: totalCsvCount,
      customMovies: List<Movie>.unmodifiable(customMovies),
      highScore: existing != null && existing.highScore > initialHighScore
          ? existing.highScore
          : initialHighScore,
    );
    _accountsById[account.id] = account;
    _activeAccountId = account.id;
    return account;
  }

  @override
  Future<UserAccount> login({
    required String username,
    required String password,
  }) async {
    final norm = UserAccount.normalizeUsername(username);
    final account = _findByUsername(norm);
    if (account == null) {
      throw FormatException(
        'Conta @$norm não encontrada. Crie sua conta na aba ao lado.',
      );
    }
    if (!account.verifyPassword(password)) {
      throw const FormatException('Senha/PIN incorreto para esta conta.');
    }
    _activeAccountId = account.id;
    return account;
  }

  @override
  Future<UserAccount> updateAccount(UserAccount account) async {
    _accountsById[account.id] = account;
    return account;
  }

  @override
  Future<UserAccount> renameAccount({
    required String oldUsername,
    required String newUsername,
  }) async {
    final normOld = UserAccount.normalizeUsername(oldUsername);
    final normNew = UserAccount.normalizeUsername(newUsername);
    if (normNew.isEmpty || normNew.length > 40) {
      throw const FormatException('Informe um novo username válido.');
    }
    final current =
        (_activeAccountId != null ? _accountsById[_activeAccountId!] : null) ??
        _findByUsername(normOld);
    if (current == null) {
      throw FormatException('Conta @$normOld não encontrada.');
    }
    if (UserAccount.normalizeUsername(current.username) == normNew) {
      return current;
    }
    final conflict = _findByUsername(normNew);
    if (conflict != null && conflict.id != current.id) {
      throw FormatException(
        'O username @$normNew já está sendo usado por outra conta.',
      );
    }
    final renamed = current.copyWith(username: normNew);
    _accountsById[renamed.id] = renamed;
    _activeAccountId = renamed.id;
    return renamed;
  }

  @override
  Future<void> logout() async {
    _activeAccountId = null;
  }

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard() async {
    final entries = <LeaderboardEntry>[
      for (final acc in _accountsById.values)
        LeaderboardEntry(
          username: UserAccount.normalizeUsername(acc.username),
          highScore: acc.highScore,
        ),
    ];
    entries.sort((a, b) {
      final cmp = b.highScore.compareTo(a.highScore);
      if (cmp != 0) return cmp;
      return a.username.compareTo(b.username);
    });
    return entries;
  }
}
