/// Representa um filme com sua nota média no Letterboxd (escala de 0.5 a 5.0).
class Movie {
  final String id;
  final String title;
  final String originalTitle;
  final int year;
  final String director;
  final double rating;
  final String posterUrl;

  const Movie({
    required this.id,
    required this.title,
    required this.originalTitle,
    required this.year,
    required this.director,
    required this.rating,
    required this.posterUrl,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': final String id,
        'title': final String title,
        'originalTitle': final String originalTitle,
        'year': final int year,
        'director': final String director,
        'rating': final num rating,
        'posterUrl': final String posterUrl,
      } =>
        Movie(
          id: id,
          title: title,
          originalTitle: originalTitle,
          year: year,
          director: director,
          rating: rating.toDouble(),
          posterUrl: posterUrl,
        ),
      _ => throw const FormatException('Formato inválido para Movie.'),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'originalTitle': originalTitle,
      'year': year,
      'director': director,
      'rating': rating,
      'posterUrl': posterUrl,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Movie && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

