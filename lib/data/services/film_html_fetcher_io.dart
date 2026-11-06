import 'dart:convert';
import 'dart:io';

Future<String?> fetchLetterboxdFilmHtmlImpl(String letterboxdUri) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  try {
    final directReq = await client
        .getUrl(Uri.parse(letterboxdUri))
        .timeout(const Duration(seconds: 8));
    directReq.headers.set('Accept-Language', 'en-US,en;q=0.9');
    final directRes = await directReq
        .close()
        .timeout(const Duration(seconds: 8));
    if (directRes.statusCode == 200) {
      return await directRes
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));
    }
    await directRes.drain<void>();

    final proxyReq = await client
        .getUrl(Uri.parse('https://r.jina.ai/$letterboxdUri'))
        .timeout(const Duration(seconds: 8));
    proxyReq.headers.set('X-Return-Format', 'html');
    final proxyRes = await proxyReq.close().timeout(const Duration(seconds: 8));
    if (proxyRes.statusCode == 200) {
      return await proxyRes
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));
    }
    await proxyRes.drain<void>();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
  return null;
}
