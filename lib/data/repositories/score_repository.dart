import '../services/score_storage_service.dart';

/// Repositório de pontuação e recordes.
/// Centraliza a leitura/gravação local e facilita a adição futura de ranking global (Firebase).
class ScoreRepository {
  ScoreRepository({required this._storageService});

  final ScoreStorageService _storageService;
  int? _cachedHighScore;

  Future<int> getHighScore() async {
    if (_cachedHighScore != null) {
      return _cachedHighScore!;
    }
    _cachedHighScore = await _storageService.loadHighScore();
    return _cachedHighScore!;
  }

  /// Atualiza o recorde caso [newScore] supere o recorde atual.
  /// Retorna `true` se um novo recorde foi alcançado.
  Future<bool> registerScore(int newScore) async {
    final currentBest = await getHighScore();
    if (newScore > currentBest) {
      _cachedHighScore = newScore;
      await _storageService.saveHighScore(newScore);
      return true;
    }
    return false;
  }
}
