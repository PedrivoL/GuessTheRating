import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:my_first_app/domain/models/movie.dart';

/// Contrato para carregamento do catálogo de filmes.
abstract interface class MovieCatalogService {
  Future<List<Movie>> fetchMovies();
}

/// Carrega o catálogo JSON embutido nos assets do app.
class AssetMovieCatalogService implements MovieCatalogService {
  const AssetMovieCatalogService({
    this.assetPath = 'assets/data/movies.json',
    this._bundle,
  });

  final String assetPath;
  final AssetBundle? _bundle;

  @override
  Future<List<Movie>> fetchMovies() async {
    final bundle = _bundle ?? rootBundle;
    final rawJson = await bundle.loadString(assetPath);
    final decoded = (jsonDecode(rawJson) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return decoded.map(Movie.fromJson).toList(growable: false);
  }
}

/// Serviço em memória usado para testes e para o Flutter Widget Preview.
class StaticMovieCatalogService implements MovieCatalogService {
  const StaticMovieCatalogService([this.movies = previewSampleMovies]);

  final List<Movie> movies;

  @override
  Future<List<Movie>> fetchMovies() async => movies;

  static const List<Movie> previewSampleMovies = [
    Movie(
      id: 'city_of_god',
      title: 'Cidade de Deus',
      originalTitle: 'City of God',
      year: 2002,
      director: 'Fernando Meirelles',
      rating: 4.5,
      posterUrl:
          'https://m.media-amazon.com/images/M/MV5BYjY4NGI5OTUtY2ZlZS00Zjk4LTk5N2MtN2JmYWVjNGNmMGRlXkEyXkFqcGc@._V1_UX600_.jpg',
    ),
    Movie(
      id: 'barbie',
      title: 'Barbie',
      originalTitle: 'Barbie',
      year: 2023,
      director: 'Greta Gerwig',
      rating: 3.8,
      posterUrl:
          'https://m.media-amazon.com/images/M/MV5BYjI3NDU0ZGYtYjA2YS00Y2RlLTgwZDAtYTE2YTM5ZjE1M2JlXkEyXkFqcGc@._V1_UX600_.jpg',
    ),
    Movie(
      id: 'parasite',
      title: 'Parasita',
      originalTitle: 'Parasite',
      year: 2019,
      director: 'Bong Joon-ho',
      rating: 4.6,
      posterUrl:
          'https://m.media-amazon.com/images/M/MV5BYjk1Y2U4MjQtY2ZiNS00OWQyLWI3MmYtZWUwNmRjYWRiNWNhXkEyXkFqcGc@._V1_UX600_.jpg',
    ),
    Movie(
      id: 'ainda_estou_aqui',
      title: 'Ainda Estou Aqui',
      originalTitle: "I'm Still Here",
      year: 2024,
      director: 'Walter Salles',
      rating: 4.4,
      posterUrl:
          'https://m.media-amazon.com/images/M/MV5BM2FjMjBiZjgtZDkyYy00YTRlLTk5N2QtODE2ZWIyYWE0Yzg0XkEyXkFqcGc@._V1_UX600_.jpg',
    ),
    Movie(
      id: 'morbius',
      title: 'Morbius',
      originalTitle: 'Morbius',
      year: 2022,
      director: 'Daniel Espinosa',
      rating: 1.7,
      posterUrl:
          'https://m.media-amazon.com/images/M/MV5BY2UzYzFiZWUtOGU5ZC00YTIxLWFlNGUtMGU1YmI4OWUzN2FmXkEyXkFqcGc@._V1_UX600_.jpg',
    ),
  ];
}
