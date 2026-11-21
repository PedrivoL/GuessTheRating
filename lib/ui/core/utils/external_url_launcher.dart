import 'external_url_launcher_stub.dart'
    if (dart.library.js_interop) 'external_url_launcher_web.dart' as impl;

/// Abre uma URL externa em uma nova aba do navegador.
Future<void> openExternalUrl(String url) => impl.openExternalUrlImpl(url);
