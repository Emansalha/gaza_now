import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/ads.dart';
import '../news/news_models.dart';
import '../news/news_repository.dart';
import '../theme.dart';
import '../widgets/news_widgets.dart';
import 'reader_page.dart';

Future<void> openExternal(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return;
  } catch (_) {}
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر فتح الرابط')));
  }
}

class ArticlePage extends StatelessWidget {
  final Article article;
  final String? heroTag;
  const ArticlePage({super.key, required this.article, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final repo = NewsScope.of(context);
    final a = article;
    final saved = repo.isSaved(a);
    final related = (a.isGaza ? repo.gaza : repo.all).where((x) => x.link != a.link).take(4).toList();
    final image = NewsImage(article: a);

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 310,
          pinned: true,
          stretch: true,
          backgroundColor: ink,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'مشاركة',
              onPressed: () => Share.share('${a.title}\n\n${a.link}\n\nعبر تطبيق غزة الآن'),
              icon: const Icon(Icons.share_outlined),
            ),
            IconButton(
              tooltip: saved ? 'إزالة من المحفوظات' : 'حفظ',
              onPressed: () => repo.toggleSaved(a),
              icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: Stack(fit: StackFit.expand, children: [
              heroTag == null ? image : Hero(tag: heroTag!, child: image),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Colors.transparent, Color(0x66000000)],
                    stops: [0, .4, 1],
                  ),
                ),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: SourceBadge.of(a)),
                const SizedBox(width: 10),
                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                const SizedBox(width: 3),
                Text(timeAgo(a.published), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                if (a.isBreaking) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: urgent, borderRadius: BorderRadius.circular(6)),
                    child: const Text('عاجل', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
              const SizedBox(height: 14),
              Text(a.title,
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, height: 1.5, color: context.titleColor)),
              if ((a.category ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('# ${a.category}', style: const TextStyle(color: teal, fontWeight: FontWeight.bold)),
              ],
              const Divider(height: 30),
              Text(
                a.summary.isEmpty ? 'لم ينشر المصدر ملخصاً لهذا الخبر. اقرأ التفاصيل كاملة على موقع ${a.sourceName}.' : a.summary,
                style: const TextStyle(fontSize: 17, height: 1.9),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: teal,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  // On a phone the story opens inside the app; in a browser, in a new tab.
                  onPressed: () => webViewAvailable
                      ? Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleReaderPage(article: a)))
                      : openExternal(context, a.link),
                  icon: const Icon(Icons.fullscreen_rounded),
                  label: Text(webViewAvailable ? 'قراءة الخبر كاملاً بملء الشاشة' : 'اقرأ الخبر كاملاً على ${a.sourceName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Share.share('${a.title}\n\n${a.link}\n\nعبر تطبيق غزة الآن'),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('مشاركة'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => repo.toggleSaved(a),
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                    label: Text(saved ? 'محفوظ' : 'حفظ'),
                  ),
                ),
              ]),
              const SizedBox(height: 22),
              if (webViewAvailable) ...[
                SectionTitle('الخبر كاملاً من ${a.sourceName}'),
                const SizedBox(height: 10),
                // The original story, with its text and photos, inside the page.
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * .82,
                    child: ArticleWebView(article: a, embedded: true),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              InfoNote(
                text: 'هذا الخبر منشور من ${a.sourceName} وحقوقه محفوظة لها، ويُعرض النص الكامل من موقعها الأصلي. '
                    'غزة الآن يجمع الأخبار من مصادر معروفة ويعرض دائماً اسم المصدر ورابط الخبر الأصلي.',
              ),
              // Ad 2: under the article.
              Center(child: BannerAdBox.article()),
              if (related.isNotEmpty) ...[
                const SizedBox(height: 26),
                const SectionTitle('أخبار ذات صلة'),
                const SizedBox(height: 12),
                for (final r in related) CompactCard(article: r, tagPrefix: 'rel'),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
