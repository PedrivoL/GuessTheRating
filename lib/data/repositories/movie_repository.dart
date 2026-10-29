import '../../domain/models/movie.dart';
import '../services/movie_catalog_service.dart';

/// Repositório único para acesso ao catálogo de filmes.
class MovieRepository {
  MovieRepository({required this._catalogService});

  final MovieCatalogService _catalogService;
  List<Movie>? _cachedMovies;

  Future<List<Movie>> getMovies() async {
    final cached = _cachedMovies;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final loaded = await _catalogService.fetchMovies();
    _cachedMovies = List<Movie>.unmodifiable(loaded);
    return _cachedMovies!;
  }
}
