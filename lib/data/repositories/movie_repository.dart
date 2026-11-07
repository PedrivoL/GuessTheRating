import '../../domain/models/movie.dart';
import '../services/movie_catalog_service.dart';

/// Repositório único para acesso ao catálogo de filmes.
class MovieRepository {
  MovieRepository({required this._catalogService});

  final MovieCatalogService _catalogService;
  List<Movie>? _cachedMovies;
  List<Movie>? _cachedSecretMovies;

  Future<List<Movie>> getMovies() async {
    final cached = _cachedMovies;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final loaded = await _catalogService.fetchMovies();
    _cachedMovies = List<Movie>.unmodifiable(loaded);
    return _cachedMovies!;
  }

  Future<List<Movie>> getSecretMovies() async {
    final cached = _cachedSecretMovies;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final loaded = await _catalogService.fetchSecretMovies();
    _cachedSecretMovies = List<Movie>.unmodifiable(loaded);
    return _cachedSecretMovies!;
  }
}
