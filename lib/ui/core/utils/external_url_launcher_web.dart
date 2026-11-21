import 'package:web/web.dart' as web;

Future<void> openExternalUrlImpl(String url) async {
  web.window.open(url, '_blank');
}
