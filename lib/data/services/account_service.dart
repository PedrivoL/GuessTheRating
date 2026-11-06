import 'dart:async';
import 'dart:convert';
import 'package:my_first_app/data/services/firestore_rest_client.dart';
import 'package:my_first_app/domain/models/movie.dart';
import 'package:my_first_app/domain/models/user_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrato para gerenciamento de contas por `@nick` + senha/PIN.
abstract interface class AccountService {
  Future<UserAccount?> loadActiveSessionAccount();
  Future<UserAccount?> findAccountByUsername(String username);
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
  Future<void> logout();
}

/// Implementação persistente via SharedPreferences + sincronização na nuvem com Cloud Firestore.
class SharedPrefsAccountService implements AccountService {
  const SharedPrefsAccountService({
    this.firestoreClient = const FirestoreAccountClient(),
  });

  final FirestoreAccountClient firestoreClient;

  static const String _accountsMapKey = 'letterboxd_accounts_registry_v1';
  static const String _activeUsernameKey = 'letterboxd_active_account_nick_v1';

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
          result[entry.key] = UserAccount.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
      return result;
    } catch (_) {
      return <String, UserAccount>{};
    }
  }

  Future<void> _writeAllAccounts(
    SharedPreferences prefs,
    Map<String, UserAccount> accounts,
  ) async {
    final serializable = <String, dynamic>{
      for (final entry in accounts.entries) entry.key: entry.value.toJson(),
    };
    await prefs.setString(_accountsMapKey, jsonEncode(serializable));
  }

  @override
  Future<UserAccount?> loadActiveSessionAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final activeNick = prefs.getString(_activeUsernameKey);
    if (activeNick == null || activeNick.isEmpty) return null;
    final norm = UserAccount.normalizeUsername(activeNick);
    final accounts = await _readAllAccounts(prefs);
    final local = accounts[norm];
    if (firestoreClient.isConfigured) {
      final remote = await firestoreClient.fetchAccount(norm);
      if (remote != null) {
        accounts[norm] = remote;
        await _writeAllAccounts(prefs, accounts);
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
    final accounts = await _readAllAccounts(prefs);
    if (firestoreClient.isConfigured) {
      final remote = await firestoreClient.fetchAccount(norm);
      if (remote != null) {
        accounts[norm] = remote;
        await _writeAllAccounts(prefs, accounts);
        return remote;
      }
    }
    return accounts[norm];
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
      throw const FormatException('Informe um @nick válido do Letterboxd.');
    }
    if (password.trim().length < 3) {
      throw const FormatException(
        'A senha/PIN precisa ter pelo menos 3 caracteres.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final accounts = await _readAllAccounts(prefs);
    var existing = accounts[norm];
    if (existing == null && firestoreClient.isConfigured) {
      existing = await firestoreClient.fetchAccount(norm);
    }
    if (existing != null && !existing.verifyPassword(password)) {
      throw FormatException(
        'O nick @$norm já possui conta cadastrada. Use a aba Entrar com a senha correta.',
      );
    }

    final account = UserAccount(
      username: norm,
      passwordHash: UserAccount.hashPassword(norm, password),
      watchedMovieIds: List<String>.unmodifiable(watchedMovieIds),
      totalCsvCount: totalCsvCount,
      customMovies: List<Movie>.unmodifiable(customMovies),
      highScore: existing != null && existing.highScore > initialHighScore
          ? existing.highScore
          : initialHighScore,
    );

    accounts[norm] = account;
    await _writeAllAccounts(prefs, accounts);
    await prefs.setString(_activeUsernameKey, norm);
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
      throw const FormatException('Informe o seu @nick do Letterboxd.');
    }

    final prefs = await SharedPreferences.getInstance();
    final accounts = await _readAllAccounts(prefs);
    var account = accounts[norm];
    if (firestoreClient.isConfigured) {
      final remote = await firestoreClient.fetchAccount(norm);
      if (remote != null) {
        account = remote;
        accounts[norm] = remote;
        await _writeAllAccounts(prefs, accounts);
      }
    }
    if (account == null) {
      throw FormatException(
        'Conta @$norm não encontrada. Crie sua conta importando o watched.csv uma única vez.',
      );
    }
    if (!account.verifyPassword(password)) {
      throw const FormatException('Senha/PIN incorreto para esta conta.');
    }

    await prefs.setString(_activeUsernameKey, norm);
    return account;
  }

  @override
  Future<UserAccount> updateAccount(UserAccount account) async {
    final norm = UserAccount.normalizeUsername(account.username);
    final prefs = await SharedPreferences.getInstance();
    final accounts = await _readAllAccounts(prefs);
    accounts[norm] = account;
    await _writeAllAccounts(prefs, accounts);
    if (firestoreClient.isConfigured) {
      unawaited(firestoreClient.upsertAccount(account));
    }
    return account;
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeUsernameKey);
  }
}

/// Implementação em memória para testes e Widget Previews.
class InMemoryAccountService implements AccountService {
  InMemoryAccountService({
    Map<String, UserAccount>? initialAccounts,
    String? activeUsername,
  }) : _accounts = Map<String, UserAccount>.of(initialAccounts ?? const {}) {
    _activeUsername = activeUsername;
  }

  final Map<String, UserAccount> _accounts;
  String? _activeUsername;

  @override
  Future<UserAccount?> loadActiveSessionAccount() async {
    if (_activeUsername == null) return null;
    return _accounts[UserAccount.normalizeUsername(_activeUsername!)];
  }

  @override
  Future<UserAccount?> findAccountByUsername(String username) async {
    final norm = UserAccount.normalizeUsername(username);
    return _accounts[norm];
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
      throw const FormatException('Informe um @nick válido do Letterboxd.');
    }
    if (password.trim().length < 3) {
      throw const FormatException(
        'A senha/PIN precisa ter pelo menos 3 caracteres.',
      );
    }
    final existing = _accounts[norm];
    if (existing != null && !existing.verifyPassword(password)) {
      throw FormatException(
        'O nick @$norm já possui conta cadastrada. Use a aba Entrar com a senha correta.',
      );
    }

    final account = UserAccount(
      username: norm,
      passwordHash: UserAccount.hashPassword(norm, password),
      watchedMovieIds: List<String>.unmodifiable(watchedMovieIds),
      totalCsvCount: totalCsvCount,
      customMovies: List<Movie>.unmodifiable(customMovies),
      highScore: existing != null && existing.highScore > initialHighScore
          ? existing.highScore
          : initialHighScore,
    );
    _accounts[norm] = account;
    _activeUsername = norm;
    return account;
  }

  @override
  Future<UserAccount> login({
    required String username,
    required String password,
  }) async {
    final norm = UserAccount.normalizeUsername(username);
    final account = _accounts[norm];
    if (account == null) {
      throw FormatException(
        'Conta @$norm não encontrada. Crie sua conta importando o watched.csv uma única vez.',
      );
    }
    if (!account.verifyPassword(password)) {
      throw const FormatException('Senha/PIN incorreto para esta conta.');
    }
    _activeUsername = norm;
    return account;
  }

  @override
  Future<UserAccount> updateAccount(UserAccount account) async {
    final norm = UserAccount.normalizeUsername(account.username);
    _accounts[norm] = account;
    return account;
  }

  @override
  Future<void> logout() async {
    _activeUsername = null;
  }
}
