import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:my_first_app/data/repositories/movie_repository.dart';
import 'package:my_first_app/data/repositories/score_repository.dart';
import 'package:my_first_app/data/services/movie_catalog_service.dart';
import 'package:my_first_app/data/services/score_storage_service.dart';
import 'package:my_first_app/domain/models/movie.dart';

enum GamePhase {
  loading,
  playing,
  revealing,
  gameOver,
  error,
}

/// Gerencia o estado do jogo estilo "Higher or Lower" com notas do Letterboxd.
class GameViewModel extends ChangeNotifier {
  GameViewModel({
    required this._movieRepository,
    required this._scoreRepository,
    Random? random,
    this.revealDelay = const Duration(milliseconds: 1200),
    this.gameOverDelay = const Duration(milliseconds: 900),
  }) : _random = random ?? Random();

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
  final Random _random;
  final Duration revealDelay;
  final Duration gameOverDelay;

  List<Movie> _allMovies = const [];
  final List<Movie> _deck = [];
  Timer? _transitionTimer;
  bool _isDisposed = false;
  int _runGeneration = 0;

  GamePhase _phase = GamePhase.loading;
  GamePhase get phase => _phase;

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
      final results = await Future.wait<Object>([
        _movieRepository.getMovies(),
        _scoreRepository.getHighScore(),
      ]);
      if (_isDisposed || generation != _runGeneration) return;

      final movies = results[0] as List<Movie>;
      final savedHighScore = results[1] as int;

      if (movies.length < 2) {
        throw StateError('O catálogo precisa ter pelo menos 2 filmes.');
      }

      _allMovies = movies;
      _highScore = savedHighScore;
      _startNewRun();
    } catch (e) {
      if (_isDisposed || generation != _runGeneration) return;
      _errorMessage = 'Não foi possível carregar os filmes: $e';
      _phase = GamePhase.error;
      _safeNotifyListeners();
    }
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
      ..addAll(_allMovies);
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

      if (beatRecord) {
        _highScore = _score;
        _isNewRecord = true;
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
