import 'film_html_fetcher_io.dart'
    if (dart.library.js_interop) 'film_html_fetcher_web.dart' as impl;

typedef FilmHtmlFetcherCallback = Future<String?> Function(String letterboxdUri);

/// Busca o HTML da página de um filme (`https://boxd.it/<id>`) de forma compatível com Web (CORS) e Nativo.
Future<String?> fetchLetterboxdFilmHtml(String letterboxdUri) =>
    impl.fetchLetterboxdFilmHtmlImpl(letterboxdUri);
