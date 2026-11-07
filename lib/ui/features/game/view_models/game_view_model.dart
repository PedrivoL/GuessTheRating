import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:my_first_app/data/repositories/account_repository.dart';
import 'package:my_first_app/data/repositories/movie_repository.dart';
import 'package:my_first_app/data/repositories/score_repository.dart';
import 'package:my_first_app/data/repositories/watched_profile_repository.dart';
import 'package:my_first_app/data/services/account_service.dart';
import 'package:my_first_app/data/services/film_html_fetcher.dart';
import 'package:my_first_app/data/services/movie_catalog_service.dart';
import 'package:my_first_app/data/services/score_storage_service.dart';
import 'package:my_first_app/data/services/watched_profile_service.dart';
import 'package:my_first_app/domain/models/movie.dart';
import 'package:my_first_app/domain/models/user_account.dart';
import 'package:my_first_app/domain/models/watched_profile.dart';

enum GamePhase {
  loading,
  playing,
  revealing,
  gameOver,
  error,
}

/// Níveis de dificuldade baseados nos filmes mais logados do Letterboxd + catálogo Secret.
enum GameDifficulty {
  easy(label: 'Fácil', poolSize: 100),
  medium(label: 'Médio', poolSize: 500),
  hard(label: 'Difícil', poolSize: 1000),
  secret(label: 'Secret', poolSize: 1000);

  const GameDifficulty({
    required this.label,
    required this.poolSize,
  });

  final String label;
  final int poolSize;
}

/// Gerencia o estado do jogo estilo "Higher or Lower" com notas do Letterboxd.
class GameViewModel extends ChangeNotifier {
  GameViewModel({
    required this._movieRepository,
    required this._scoreRepository,
    WatchedProfileRepository? watchedProfileRepository,
    AccountRepository? accountRepository,
    this.filmHtmlFetcher = fetchLetterboxdFilmHtml,
    Random? random,
    this.revealDelay = const Duration(milliseconds: 1200),
    this.gameOverDelay = const Duration(milliseconds: 900),
    this.initialUri,
  }) : _watchedProfileRepository =
           watchedProfileRepository ??
           WatchedProfileRepository(
             storageService: InMemoryWatchedProfileService(),
           ),
       _accountRepository =
           accountRepository ??
           AccountRepository(accountService: InMemoryAccountService()),
       _random = random ?? Random();

  /// Construtor síncrono auxiliar para o Flutter Widget Preview.
  factory GameViewModel.preview({
    List<Movie> movies = StaticMovieCatalogService.previewSampleMovies,
    int score = 3,
    int highScore = 7,
    bool gameOver = false,
  }) {
    final vm = GameViewModel(
      movieRepository: MovieRepository(
        catalogService: StaticMovieCatalogService(movies),
      ),
      scoreRepository: ScoreRepository(
        storageService: InMemoryScoreService(initialHighScore: highScore),
      ),
      random: Random(42),
    );
    vm._allMovies = List<Movie>.of(movies);
    vm._deck
      ..addAll(movies.skip(2))
      ..shuffle(vm._random);
    vm._currentMovie = movies[0];
    vm._challengerMovie = movies[1];
    vm._score = score;
    vm._highScore = highScore;
    vm._phase = gameOver ? GamePhase.gameOver : GamePhase.playing;
    if (gameOver) {
      vm._lastGuessCorrect = false;
      vm._selectedMovieId = movies[1].id;
    }
    return vm;
  }

  final MovieRepository _movieRepository;
  final ScoreRepository _scoreRepository;
  final WatchedProfileRepository _watchedProfileRepository;
  final AccountRepository _accountRepository;
  final FilmHtmlFetcherCallback filmHtmlFetcher;
  final Random _random;
  final Duration revealDelay;
  final Duration gameOverDelay;
  final Uri? initialUri;

  /// Extrai um `@nick` alvo caso o jogador tenha aberto um link direto como
  /// `https://guesstherating.web.app/nickalvo` ou `/?nick=nickalvo`.
  static String? extractTargetNickFromUri(Uri uri) {
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    final queryNick = uri.queryParameters['nick'] ?? uri.queryParameters['u'];
    if (queryNick != null && queryNick.trim().isNotEmpty) {
      final norm = UserAccount.normalizeUsername(queryNick);
      if (norm.isNotEmpty) return norm;
    }

    const reservedSegments = <String>{
      'index.html',
      'assets',
      'icons',
      'canvaskit',
      'favicon.ico',
      'manifest.json',
      'flutter_service_worker.js',
    };

    final cleanSegments = uri.pathSegments
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (cleanSegments.length == 1) {
      final segment = cleanSegments.first;
      if (!reservedSegments.contains(segment.toLowerCase()) &&
          !segment.contains('.')) {
        final norm = UserAccount.normalizeUsername(segment);
        if (norm.isNotEmpty) return norm;
      }
    }

    if (uri.fragment.isNotEmpty) {
      final fragPath = uri.fragment.replaceFirst(RegExp(r'^/+'), '').trim();
      if (fragPath.isNotEmpty &&
          !fragPath.contains('/') &&
          !fragPath.contains('.')) {
        final norm = UserAccount.normalizeUsername(fragPath);
        if (norm.isNotEmpty) return norm;
      }
    }

    return null;
  }

  List<Movie> _allMovies = const [];
  List<Movie> _secretMovies = const [];
  WatchedProfile? _watchedProfile;
  UserAccount? _currentAccount;
  final List<Movie> _deck = [];
  Timer? _transitionTimer;
  bool _isDisposed = false;
  int _runGeneration = 0;

  GamePhase _phase = GamePhase.loading;
  GamePhase get phase => _phase;

  GameDifficulty _difficulty = GameDifficulty.easy;
  GameDifficulty get difficulty => _difficulty;

  Movie? _currentMovie;
  Movie? get currentMovie => _currentMovie;

  Movie? _challengerMovie;
  Movie? get challengerMovie => _challengerMovie;

  int _score = 0;
  int get score => _score;

  int _highScore = 0;
  int get highScore => _highScore;

  bool _isNewRecord = false;
  bool get isNewRecord => _isNewRecord;

  bool? _lastGuessCorrect;
  bool? get lastGuessCorrect => _lastGuessCorrect;

  String? _selectedMovieId;
  String? get selectedMovieId => _selectedMovieId;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  WatchedProfile? get watchedProfile => _watchedProfile;
  UserAccount? get currentAccount => _currentAccount;

  /// Catálogo base somado ao catálogo Secret e quaisquer filmes extras buscados do `watched.csv`.
  List<Movie> get combinedCatalog {
    final custom = _watchedProfile?.customMovies ?? const <Movie>[];
    final accountCustom = _currentAccount?.customMovies ?? const <Movie>[];
    if (_secretMovies.isEmpty && custom.isEmpty && accountCustom.isEmpty) {
      return _allMovies;
    }
    final byId = <String, Movie>{
      for (final m in _secretMovies) m.id: m,
      for (final m in _allMovies) m.id: m,
      for (final m in accountCustom) m.id: m,
      for (final m in custom) m.id: m,
    };
    return byId.values.toList(growable: false);
  }

  List<Movie> get _activeMovies {
    final profile = _watchedProfile;
    final catalog = combinedCatalog;
    if (profile != null && profile.isActive) {
      final idSet = profile.watchedMovieIds.toSet();
      final filtered = catalog
          .where((m) => idSet.contains(m.id))
          .toList(growable: false);
      if (filtered.length >= 2) {
        return filtered;
      }
    }
    if (_difficulty == GameDifficulty.secret && _secretMovies.length >= 2) {
      return _secretMovies;
    }
    if (_allMovies.isEmpty) return const [];
    final limit = min(_difficulty.poolSize, _allMovies.length);
    return _allMovies.take(limit).toList(growable: false);
  }

  /// Altera a dificuldade (Fácil: 100, Médio: 500, Difícil: 1000) e reinicia a partida.
  Future<void> setDifficulty(GameDifficulty newDifficulty) async {
    final wasUsingWatched = isUsingWatchedPool;
    if (_difficulty == newDifficulty && !wasUsingWatched) {
      return;
    }
    _difficulty = newDifficulty;
    final profile = _watchedProfile;
    if (profile != null && profile.isActive) {
      final deactivated = profile.copyWith(isActive: false);
      _watchedProfile = deactivated;
      await _watchedProfileRepository.saveProfile(deactivated);
      if (_isDisposed) return;
    }
    _startNewRun();
  }

  bool get isUsingWatchedPool {
    final profile = _watchedProfile;
    if (profile == null || !profile.isActive) return false;
    final idSet = profile.watchedMovieIds.toSet();
    final matchCount = combinedCatalog.where((m) => idSet.contains(m.id)).length;
    return matchCount >= 2;
  }

  int get activePoolCount => _activeMovies.length;
  int get totalCatalogCount => _allMovies.length;

  bool get isCurrentRatingVisible =>
      _score > 0 ||
      _phase == GamePhase.revealing ||
      _phase == GamePhase.gameOver;

  bool get isChallengerRatingVisible =>
      _phase == GamePhase.revealing || _phase == GamePhase.gameOver;

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    _cancelTimer();
    final generation = ++_runGeneration;
    _phase = GamePhase.loading;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final results = await Future.wait<Object?>([
        _movieRepository.getMovies(),
        _scoreRepository.getHighScore(),
        _watchedProfileRepository.getProfile(),
        _accountRepository.getActiveAccount(),
        _movieRepository.getSecretMovies(),
      ]);
      if (_isDisposed || generation != _runGeneration) return;

      final movies = results[0]! as List<Movie>;
      final savedHighScore = results[1]! as int;
      final savedProfile = results[2] as WatchedProfile?;
      final savedAccount = results[3] as UserAccount?;
      final secretMovies = results[4]! as List<Movie>;

      if (movies.length < 2) {
        throw StateError('O catálogo precisa ter pelo menos 2 filmes.');
      }

      _allMovies = movies;
      _secretMovies = secretMovies;
      _currentAccount = savedAccount;
      _highScore = (savedAccount != null && savedAccount.highScore > savedHighScore)
          ? savedAccount.highScore
          : savedHighScore;
      _watchedProfile = savedProfile ?? savedAccount?.toWatchedProfile();

      final targetNick = extractTargetNickFromUri(initialUri ?? Uri.base);
      if (targetNick != null && targetNick.isNotEmpty) {
        try {
          final targetAccount = await _accountRepository.findAccountByUsername(
            targetNick,
          );
          if (_isDisposed || generation != _runGeneration) return;
          if (targetAccount != null) {
            final targetProfile = targetAccount.toWatchedProfile(isActive: true);
            await _watchedProfileRepository.saveProfile(targetProfile);
            if (_isDisposed || generation != _runGeneration) return;
            _watchedProfile = targetProfile;
          } else if (_watchedProfile != null &&
              UserAccount.normalizeUsername(_watchedProfile!.username) ==
                  targetNick) {
            final activated = _watchedProfile!.copyWith(isActive: true);
            await _watchedProfileRepository.saveProfile(activated);
            if (_isDisposed || generation != _runGeneration) return;
            _watchedProfile = activated;
          }
        } catch (_) {
          // Ignora silenciosamente caso o nick da URL não seja encontrado
        }
      }

      _startNewRun();
    } catch (e) {
      if (_isDisposed || generation != _runGeneration) return;
      _errorMessage = 'Não foi possível carregar os filmes: $e';
      _phase = GamePhase.error;
      _safeNotifyListeners();
    }
  }

  /// Processa o `watched.csv` e carrega imediatamente do Letterboxd todos os filmes
  /// que ainda não estão no `movies.json`.
  Future<WatchedCsvMatchResult> resolveWatchedCsv(
    String csvContent, {
    void Function(int completed, int total)? onLookupProgress,
  }) async {
    final initialResult = WatchedCsvParser.matchAgainstCatalog(
      csvContent: csvContent,
      catalog: combinedCatalog,
    );

    final newlyFetched = <Movie>[];
    final remainingUnmatched = <UnmatchedCsvFilm>[];

    if (initialResult.unmatchedEntries.isNotEmpty) {
      final entries = initialResult.unmatchedEntries;
      final total = entries.length;
      var nextIdx = 0;
      var completed = 0;
      onLookupProgress?.call(0, total);

      Future<void> worker() async {
        while (true) {
          if (_isDisposed) break;
          final i = nextIdx++;
          if (i >= total) break;
          final entry = entries[i];
          Movie? resolved;
          try {
            final html = await filmHtmlFetcher(entry.letterboxdUri);
            if (html != null && html.isNotEmpty) {
              resolved = WatchedCsvParser.parseMovieFromLetterboxdHtml(
                entry: entry,
                html: html,
              );
            }
          } catch (_) {}

          if (resolved != null) {
            newlyFetched.add(resolved);
          } else {
            remainingUnmatched.add(entry);
          }
          completed++;
          onLookupProgress?.call(completed, total);
        }
      }

      final concurrency = min(4, total);
      await Future.wait(List.generate(concurrency, (_) => worker()));
    }

    final allMatchedById = <String, Movie>{
      for (final m in initialResult.matchedMovies) m.id: m,
      for (final m in newlyFetched) m.id: m,
    };

    return WatchedCsvMatchResult(
      matchedMovies: allMatchedById.values.toList(growable: false),
      unmatchedEntries: remainingUnmatched,
      totalCsvRows: initialResult.totalCsvRows,
    );
  }

  List<Movie> _extractCustomMovies(WatchedCsvMatchResult resolvedResult) {
    final baseIds = {for (final m in _allMovies) m.id};
    final customById = <String, Movie>{
      for (final m in (_watchedProfile?.customMovies ?? const <Movie>[]))
        m.id: m,
      for (final m in (_currentAccount?.customMovies ?? const <Movie>[]))
        m.id: m,
      for (final m in resolvedResult.matchedMovies)
        if (!baseIds.contains(m.id)) m.id: m,
    };
    return customById.values.toList(growable: false);
  }

  /// Cria (ou atualiza) uma conta com `@nick` + senha/PIN e o `watched.csv` carregado.
  Future<UserAccount> registerAccountWithCsv({
    required String username,
    required String password,
    required WatchedCsvMatchResult resolvedResult,
  }) async {
    if (resolvedResult.matchedMovies.length < 2) {
      throw const FormatException(
        'Encontrados menos de 2 filmes compatíveis no arquivo watched.csv.',
      );
    }

    final customMovies = _extractCustomMovies(resolvedResult);
    final watchedIds = resolvedResult.matchedMovies
        .map((m) => m.id)
        .toList(growable: false);

    final account = await _accountRepository.registerAccount(
      username: username,
      password: password,
      watchedMovieIds: watchedIds,
      totalCsvCount: resolvedResult.totalCsvRows,
      customMovies: customMovies,
      initialHighScore: _highScore,
    );

    final profile = account.toWatchedProfile(isActive: true);
    await _watchedProfileRepository.saveProfile(profile);
    if (_isDisposed) return account;

    _currentAccount = account;
    if (account.highScore > _highScore) {
      _highScore = account.highScore;
      await _scoreRepository.registerScore(_highScore);
    }
    _watchedProfile = profile;
    _startNewRun();
    return account;
  }

  /// Faz login em uma conta existente por `@nick` + senha/PIN, restaurando a pool de filmes e o recorde.
  Future<UserAccount> loginAccount({
    required String username,
    required String password,
  }) async {
    final account = await _accountRepository.login(
      username: username,
      password: password,
    );
    final profile = account.toWatchedProfile(isActive: true);
    await _watchedProfileRepository.saveProfile(profile);
    if (_isDisposed) return account;

    _currentAccount = account;
    if (account.highScore > _highScore) {
      _highScore = account.highScore;
      await _scoreRepository.registerScore(_highScore);
    }
    _watchedProfile = profile;
    _startNewRun();
    return account;
  }

  /// Encerra a sessão da conta atual no dispositivo.
  Future<void> logoutAccount() async {
    await _accountRepository.logout();
    if (_isDisposed) return;
    _currentAccount = null;
    _safeNotifyListeners();
  }

  /// Carrega a pool de filmes apenas pelo `username` (caso o perfil já tenha sido cadastrado em uma conta),
  /// sem exigir senha nem reenvio do `watched.csv`.
  Future<void> loadPoolByNick(String username) async {
    final norm = UserAccount.normalizeUsername(username);
    if (norm.isEmpty) {
      throw const FormatException('Digite um username do Letterboxd.');
    }

    final account = await _accountRepository.findAccountByUsername(norm);
    if (account != null) {
      final profile = account.toWatchedProfile(isActive: true);
      await _watchedProfileRepository.saveProfile(profile);
      if (_isDisposed) return;
      _watchedProfile = profile;
      _startNewRun();
      return;
    }

    final existingProfile = _watchedProfile;
    if (existingProfile != null &&
        UserAccount.normalizeUsername(existingProfile.username) == norm) {
      await setWatchedPoolActive(true);
      return;
    }

    throw FormatException(
      'O username @$norm ainda não possui catálogo salvo. Crie sua Conta ao lado importando o arquivo watched.csv.',
    );
  }

  /// Aplica o resultado já carregado do `watched.csv`, salva no perfil do jogador e inicia a partida.
  Future<WatchedCsvMatchResult> applyResolvedWatchedCsv({
    required String username,
    required WatchedCsvMatchResult resolvedResult,
  }) async {
    final cleanUsername = UserAccount.normalizeUsername(username);
    final effectiveUsername = cleanUsername.isEmpty ? 'voce' : cleanUsername;

    if (resolvedResult.matchedMovies.length < 2) {
      throw const FormatException(
        'Encontrados menos de 2 filmes compatíveis. Verifique se selecionou o arquivo watched.csv exportado do Letterboxd.',
      );
    }

    final customMovies = _extractCustomMovies(resolvedResult);
    final watchedIds = resolvedResult.matchedMovies
        .map((m) => m.id)
        .toList(growable: false);

    final profile = WatchedProfile(
      username: effectiveUsername,
      watchedMovieIds: watchedIds,
      totalCsvCount: resolvedResult.totalCsvRows,
      customMovies: customMovies,
      isActive: true,
    );

    await _watchedProfileRepository.saveProfile(profile);

    final activeAccount = _currentAccount;
    if (activeAccount != null && activeAccount.username == effectiveUsername) {
      final updatedAcc = activeAccount.copyWith(
        watchedMovieIds: watchedIds,
        totalCsvCount: resolvedResult.totalCsvRows,
        customMovies: customMovies,
      );
      _currentAccount = await _accountRepository.updateAccount(updatedAcc);
    }

    if (_isDisposed) return resolvedResult;

    _watchedProfile = profile;
    _startNewRun();
    return resolvedResult;
  }

  /// Importa o `watched.csv` do jogador carregando imediatamente os filmes fora do `movies.json`.
  Future<WatchedCsvMatchResult> importWatchedCsv({
    required String username,
    required String csvContent,
    void Function(int completed, int total)? onLookupProgress,
  }) async {
    final resolved = await resolveWatchedCsv(
      csvContent,
      onLookupProgress: onLookupProgress,
    );
    return applyResolvedWatchedCsv(
      username: username,
      resolvedResult: resolved,
    );
  }

  /// Alterna entre a pool de filmes assistidos do jogador e o catálogo geral.
  Future<void> setWatchedPoolActive(bool active) async {
    final currentProfile = _watchedProfile;
    if (currentProfile == null || currentProfile.isActive == active) return;

    final updated = currentProfile.copyWith(isActive: active);
    await _watchedProfileRepository.saveProfile(updated);
    if (_isDisposed) return;

    _watchedProfile = updated;
    _startNewRun();
  }

  /// Ativa o catálogo próprio do jogador (da conta conectada ou perfil salvo).
  Future<void> activateOwnCatalog() async {
    final account = _currentAccount;
    if (account != null) {
      final profile = account.toWatchedProfile(isActive: true);
      await _watchedProfileRepository.saveProfile(profile);
      if (_isDisposed) return;
      _watchedProfile = profile;
      _startNewRun();
      return;
    }
    await setWatchedPoolActive(true);
  }

  /// Atualiza o nick salvo sem precisar reimportar o arquivo `watched.csv`.
  Future<void> updateProfileUsername(String username) async {
    final currentProfile = _watchedProfile;
    if (currentProfile == null) return;
    final cleanUsername = UserAccount.normalizeUsername(username);
    if (cleanUsername.isEmpty || cleanUsername == currentProfile.username) {
      return;
    }

    final updated = currentProfile.copyWith(username: cleanUsername);
    await _watchedProfileRepository.saveProfile(updated);
    if (_isDisposed) return;

    _watchedProfile = updated;
    _safeNotifyListeners();
  }

  /// Remove o perfil salvo e volta para o catálogo geral.
  Future<void> clearWatchedProfile() async {
    await _watchedProfileRepository.clearProfile();
    if (_isDisposed) return;

    _watchedProfile = null;
    _startNewRun();
  }

  void _startNewRun() {
    _cancelTimer();
    _runGeneration++;
    _score = 0;
    _isNewRecord = false;
    _lastGuessCorrect = null;
    _selectedMovieId = null;

    _refillDeck();
    _currentMovie = _deck.removeLast();
    _challengerMovie = _drawNextChallenger(against: _currentMovie!);
    _phase = GamePhase.playing;
    _safeNotifyListeners();
  }

  void _refillDeck({Movie? exclude}) {
    _deck
      ..clear()
      ..addAll(_activeMovies);
    if (exclude != null) {
      _deck.removeWhere((m) => m.id == exclude.id);
    }
    _deck.shuffle(_random);
  }

  Movie _drawNextChallenger({required Movie against}) {
    if (_deck.isEmpty) {
      _refillDeck(exclude: against);
    }

    final differentRatingIndex = _deck.lastIndexWhere(
      (candidate) =>
          candidate.id != against.id && candidate.rating != against.rating,
    );

    if (differentRatingIndex != -1) {
      return _deck.removeAt(differentRatingIndex);
    }

    _refillDeck(exclude: against);
    final retryIndex = _deck.lastIndexWhere(
      (candidate) => candidate.rating != against.rating,
    );
    if (retryIndex != -1) {
      return _deck.removeAt(retryIndex);
    }
    return _deck.removeLast();
  }

  /// Registra a escolha de qual dos dois filmes na tela possui a MAIOR nota no Letterboxd.
  Future<void> chooseMovieWithHigherRating(Movie chosenMovie) async {
    if (_isDisposed || _phase != GamePhase.playing) return;
    final current = _currentMovie;
    final challenger = _challengerMovie;
    if (current == null || challenger == null) return;
    if (chosenMovie.id != current.id && chosenMovie.id != challenger.id) return;

    final generation = _runGeneration;
    final otherMovie = chosenMovie.id == current.id ? challenger : current;
    final isCorrect = chosenMovie.rating >= otherMovie.rating;

    _selectedMovieId = chosenMovie.id;
    _lastGuessCorrect = isCorrect;
    _phase = GamePhase.revealing;

    if (isCorrect) {
      _score += 1;
      final beatRecord = await _scoreRepository.registerScore(_score);
      if (_isDisposed || generation != _runGeneration) return;

      if (beatRecord || _score > _highScore) {
        _highScore = _score;
        _isNewRecord = true;
        final acc = _currentAccount;
        if (acc != null && _highScore > acc.highScore) {
          final updatedAcc = acc.copyWith(highScore: _highScore);
          _currentAccount = updatedAcc;
          unawaited(_accountRepository.updateAccount(updatedAcc));
        }
      }
      _safeNotifyListeners();

      _transitionTimer = Timer(revealDelay, () {
        if (_isDisposed ||
            generation != _runGeneration ||
            _phase != GamePhase.revealing) {
          return;
        }
        _currentMovie = challenger;
        _challengerMovie = _drawNextChallenger(against: challenger);
        _selectedMovieId = null;
        _lastGuessCorrect = null;
        _phase = GamePhase.playing;
        _safeNotifyListeners();
      });
    } else {
      _safeNotifyListeners();
      _transitionTimer = Timer(gameOverDelay, () {
        if (_isDisposed ||
            generation != _runGeneration ||
            _phase != GamePhase.revealing) {
          return;
        }
        _phase = GamePhase.gameOver;
        _safeNotifyListeners();
      });
    }
  }

  void restartGame() {
    if (_isDisposed) return;
    if (_allMovies.length < 2) {
      initialize();
      return;
    }
    _startNewRun();
  }

  void _cancelTimer() {
    _transitionTimer?.cancel();
    _transitionTimer = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelTimer();
    super.dispose();
  }
}
