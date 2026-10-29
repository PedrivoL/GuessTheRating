import 'package:shared_preferences/shared_preferences.dart';

/// Contrato de persistência de pontuação.
/// Permite trocar ou combinar armazenamento local com Firebase no futuro.
abstract interface class ScoreStorageService {
  Future<int> loadHighScore();
  Future<void> saveHighScore(int score);
}

/// Implementação local usando SharedPreferences (funciona em Android e Web).
class SharedPreferencesScoreService implements ScoreStorageService {
  const SharedPreferencesScoreService();

  static const String _highScoreKey = 'letterboxd_higher_lower_high_score';

  @override
  Future<int> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highScoreKey) ?? 0;
  }

  @override
  Future<void> saveHighScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highScoreKey, score);
  }
}

/// Implementação em memória para testes unitários e Flutter Widget Preview.
class InMemoryScoreService implements ScoreStorageService {
  InMemoryScoreService({int initialHighScore = 0})
    : _highScore = initialHighScore;

  int _highScore;

  @override
  Future<int> loadHighScore() async => _highScore;

  @override
  Future<void> saveHighScore(int score) async {
    _highScore = score;
  }
}

