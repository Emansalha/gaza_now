import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../news/news_models.dart';
import '../theme.dart';
import 'article_page.dart' show openExternal;

/// True on Android/iOS where an in-app web view exists. Widget tests switch it off.
bool webViewAvailable = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Hides cookie banners, pop-ups and sticky bars so the story itself is what shows.
const _tidyScript = r'''
(function(){
  var sel = ['[id*="cookie"]','[class*="cookie"]','[class*="consent"]','[id*="consent"]',
             '[class*="newsletter"]','[class*="popup"]','[class*="modal"]','[class*="sticky-ad"]',
             '[class*="app-banner"]','[class*="smartbanner"]'];
  try { document.querySelectorAll(sel.join(',')).forEach(function(e){ e.style.display='none'; }); } catch(e) {}
  try { document.documentElement.style.overflow='auto'; document.body.style.overflow='auto'; } catch(e) {}
})();
''';

/// The original article page, shown inside the app.
class ArticleWebView extends StatefulWidget {
  final Article article;

  /// Inside a scrolling page the web view must own the drag gestures.
  final bool embedded;
  const ArticleWebView({super.key, required this.article, this.embedded = false});

  @override
  State<ArticleWebView> createState() => _ArticleWebViewState();
}

class _ArticleWebViewState extends State<ArticleWebView> {
  late final WebViewController controller;
  int progress = 0;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => progress = p);
        },
        onPageStarted: (_) {
          if (mounted) setState(() => failed = false);
        },
        onPageFinished: (_) => controller.runJavaScript(_tidyScript).catchError((_) {}),
        onWebResourceError: (e) {
          // Only a failure of the page itself counts, not of an ad or image on it.
          if (e.isForMainFrame == true && mounted) setState(() => failed = true);
        },
        onNavigationRequest: (r) =>
            r.url.startsWith('http') ? NavigationDecision.navigate : NavigationDecision.prevent,
      ))
      ..loadRequest(Uri.parse(widget.article.link));
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Container(
        color: context.softFill,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.blueGrey),
            const SizedBox(height: 10),
            const Text('تعذّر تحميل الخبر كاملاً', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
              FilledButton.icon(
                onPressed: () {
                  setState(() => failed = false);
                  controller.reload();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
              OutlinedButton.icon(
                onPressed: () => openExternal(context, widget.article.link),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('فتح في المتصفح'),
              ),
            ]),
          ]),
        ),
      );
    }
    return Stack(children: [
      WebViewWidget(
        controller: controller,
        gestureRecognizers: widget.embedded
            ? {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())}
            : const <Factory<OneSequenceGestureRecognizer>>{},
      ),
      if (progress < 100)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(value: progress == 0 ? null : progress / 100, color: teal, minHeight: 3),
        ),
    ]);
  }
}

/// Full-screen reading of the original article inside the app.
class ArticleReaderPage extends StatelessWidget {
  final Article article;
  const ArticleReaderPage({super.key, required this.article});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(article.sourceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: 'مشاركة',
              onPressed: () => Share.share('${article.title}\n\n${article.link}\n\nعبر تطبيق غزة الآن'),
              icon: const Icon(Icons.share_outlined),
            ),
            IconButton(
              tooltip: 'فتح في المتصفح',
              onPressed: () => openExternal(context, article.link),
              icon: const Icon(Icons.open_in_browser),
            ),
          ],
        ),
        body: webViewAvailable
            ? ArticleWebView(article: article)
            : const Center(child: Text('القراءة داخل التطبيق غير متاحة على هذا الجهاز')),
      );
}
