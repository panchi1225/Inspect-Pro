// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

void openBrowserTab(String url) => html.window.open(url, '_blank');

bool goBackInBrowser() {
  // Flutter 3.38.5's multi-entry history tags app entries with serialCount.
  // A refreshed/direct link starts at zero: never send that user off-site.
  final state = html.window.history.state;
  if (state is! Map ||
      state['serialCount'] is! num ||
      state['serialCount'] <= 0) {
    return false;
  }
  html.window.history.back();
  return true;
}
