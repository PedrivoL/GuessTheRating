import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<String?> fetchLetterboxdFilmHtmlImpl(String letterboxdUri) async {
  try {
    final headers = web.Headers()..append('X-Return-Format', 'html');
    final init = web.RequestInit(method: 'GET', headers: headers);
    final response = await web.window
        .fetch('https://r.jina.ai/$letterboxdUri'.toJS, init)
        .toDart
        .timeout(const Duration(seconds: 10));
    if (!response.ok) return null;
    final jsText = await response.text().toDart.timeout(
      const Duration(seconds: 10),
    );
    return jsText.toDart;
  } catch (_) {
    return null;
  }
}
