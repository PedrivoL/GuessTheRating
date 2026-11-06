import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<Map<String, dynamic>?> httpGetJson(String url) async {
  try {
    final response = await web.window
        .fetch(url.toJS)
        .toDart
        .timeout(const Duration(seconds: 8));
    if (!response.ok) return null;
    final jsText = await response.text().toDart.timeout(
      const Duration(seconds: 8),
    );
    return jsonDecode(jsText.toDart) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Future<bool> httpPatchJson(String url, Map<String, dynamic> body) async {
  try {
    final headers = web.Headers()
      ..append('Content-Type', 'application/json; charset=utf-8');
    final init = web.RequestInit(
      method: 'PATCH',
      headers: headers,
      body: jsonEncode(body).toJS,
    );
    final response = await web.window
        .fetch(url.toJS, init)
        .toDart
        .timeout(const Duration(seconds: 8));
    return response.ok;
  } catch (_) {
    return false;
  }
}
