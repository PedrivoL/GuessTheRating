import 'package:my_first_app/data/services/account_service.dart';
import 'package:my_first_app/domain/models/movie.dart';
import 'package:my_first_app/domain/models/user_account.dart';

/// Repositório para autenticação, criação de conta e consulta de pool por `@nick`.
class AccountRepository {
  AccountRepository({required this._accountService});

  final AccountService _accountService;

  Future<UserAccount?> getActiveAccount() =>
      _accountService.loadActiveSessionAccount();

  Future<UserAccount?> findAccountByUsername(String username) =>
      _accountService.findAccountByUsername(username);

  Future<UserAccount> registerAccount({
    required String username,
    required String password,
    required List<String> watchedMovieIds,
    required int totalCsvCount,
    required List<Movie> customMovies,
    required int initialHighScore,
  }) => _accountService.registerAccount(
    username: username,
    password: password,
    watchedMovieIds: watchedMovieIds,
    totalCsvCount: totalCsvCount,
    customMovies: customMovies,
    initialHighScore: initialHighScore,
  );

  Future<UserAccount> login({
    required String username,
    required String password,
  }) => _accountService.login(username: username, password: password);

  Future<UserAccount> updateAccount(UserAccount account) =>
      _accountService.updateAccount(account);

  Future<void> logout() => _accountService.logout();
}
