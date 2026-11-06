import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>?> httpGetJson(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client
        .getUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 8));
    final res = await req.close().timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      await res.drain<void>();
      return null;
    }
    final text = await res
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 8));
    return jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<bool> httpPatchJson(String url, Map<String, dynamic> body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client
        .openUrl('PATCH', Uri.parse(url))
        .timeout(const Duration(seconds: 8));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    final res = await req.close().timeout(const Duration(seconds: 8));
    await res.drain<void>();
    return res.statusCode >= 200 && res.statusCode < 300;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}
