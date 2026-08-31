import 'package:web/web.dart' as web;

bool openBrowserTab(Uri uri) {
  try {
    return web.window.open(uri.toString(), '_blank') != null;
  } catch (_) {
    return false;
  }
}
