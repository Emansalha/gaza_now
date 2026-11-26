import 'package:flutter/material.dart';

import '../channel/channel_models.dart' show ChannelPost, livePlatformName;
import '../channel/channel_repository.dart';
import '../news/news_models.dart';
import '../news/news_repository.dart';
import '../theme.dart';
import '../widgets/news_widgets.dart';
import 'article_page.dart';

/// Generic list of articles chosen by [articlesOf].
class ArticleListPage extends StatelessWidget {
  final String title;
  final List<Article> Function(NewsRepository repo) articlesOf;
  const ArticleListPage({super.key, required this.title, required this.articlesOf});

  @override
  Widget build(BuildContext context) {
    final repo = NewsScope.of(context);
    final items = articlesOf(repo);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        color: teal,
        onRefresh: repo.refresh,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.search_off,
              title: 'لا توجد أخبار حالياً',
              subtitle: 'لم تذكر المصادر هذه المنطقة في أحدث أخبارها. اسحب للأسفل للتحديث.',
            ),
          for (final a in items) CompactCard(article: a, tagPrefix: 'list'),
        ]),
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  String query = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _set(String q) {
    controller.text = q;
    setState(() => query = q);
  }

  static const suggestions = ['غزة', 'رفح', 'خانيونس', 'الأونروا', 'مساعدات', 'مستشفى', 'الضفة الغربية', 'القدس'];

  @override
  Widget build(BuildContext context) {
    final repo = NewsScope.of(context);
    final results = query.trim().isEmpty ? <Article>[] : repo.search(query);
    return Scaffold(
      appBar: AppBar(title: const Text('البحث')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          autofocus: true,
          controller: controller,
          onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(
            hintText: 'ابحث في أخبار جميع المصادر...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: context.surfaceCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        if (query.trim().isEmpty) ...[
          const SectionTitle('عمليات بحث مقترحة'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in suggestions)
              ActionChip(
                label: Text(s),
                avatar: const Icon(Icons.trending_up, size: 16, color: teal),
                onPressed: () => _set(s),
                side: BorderSide.none,
                backgroundColor: context.surfaceCard,
              ),
          ]),
        ] else ...[
          SectionTitle('النتائج (${results.length})'),
          const SizedBox(height: 10),
          if (results.isEmpty) const EmptyState(icon: Icons.search_off, title: 'لا توجد نتائج', subtitle: 'جرّب كلمات بحث مختلفة.'),
          for (final a in results.take(60)) CompactCard(article: a, tagPrefix: 'search'),
        ],
      ]),
    );
  }
}

class SavedPage extends StatelessWidget {
  const SavedPage({super.key});
  @override
  Widget build(BuildContext context) {
    final saved = NewsScope.of(context).saved;
    return ListView(padding: const EdgeInsets.all(16), children: [
      SectionTitle('الأخبار المحفوظة', trailing: Text('${saved.length}', style: const TextStyle(color: Colors.grey))),
      const SizedBox(height: 12),
      if (saved.isEmpty)
        const EmptyState(
          icon: Icons.bookmark_border,
          title: 'لا توجد أخبار محفوظة',
          subtitle: 'اضغط على أيقونة الحفظ في أي خبر لتعود إليه لاحقاً، حتى بدون إنترنت.',
        ),
      for (final a in saved) CompactCard(article: a, tagPrefix: 'saved'),
    ]);
  }
}

/// Recent Gaza stories, shown as a timeline (replaces the old sample notifications).
class UpdatesPage extends StatelessWidget {
  const UpdatesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = NewsScope.of(context);
    final items = repo.gaza.take(25).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('آخر التحديثات')),
      body: RefreshIndicator(
        color: teal,
        onRefresh: repo.refresh,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.isEmpty ? 1 : items.length,
          itemBuilder: (_, i) {
            if (items.isEmpty) {
              return const EmptyState(title: 'لا توجد تحديثات بعد', subtitle: 'اسحب للأسفل لتحميل آخر الأخبار.');
            }
            final a = items[i];
            return IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Column(children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(color: a.isBreaking ? urgent : teal, shape: BoxShape.circle),
                  ),
                  Expanded(child: Container(width: 2, color: teal.withValues(alpha: .25))),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: () => openArticle(context, a),
                      title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.4)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${a.sourceName} • ${timeAgo(a.published)}'),
                      ),
                    ),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = NewsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('مصادر الأخبار')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [ink, teal]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.verified, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('كيف نضمن موثوقية الأخبار؟',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ]),
            SizedBox(height: 10),
            Text(
              '• نعرض فقط أخبار مؤسسات إعلامية ووكالات دولية معروفة، من موجزاتها الرسمية مباشرة.\n'
              '• كل خبر يظهر باسم مصدره ووقت نشره ورابط للخبر الأصلي.\n'
              '• لا نعدّل نص الخبر ولا نكتب عناوين من عندنا.\n'
              '• يمكنك اختيار المصادر التي تريد متابعتها.',
              style: TextStyle(color: Colors.white, height: 1.8, fontSize: 13),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        for (final s in NewsRepository.availableSources)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SwitchListTile(
                value: repo.enabledSources.contains(s.id),
                onChanged: (v) => repo.setSourceEnabled(s.id, v),
                activeThumbColor: teal,
                secondary: CircleAvatar(
                  backgroundColor: s.color,
                  child: Text(s.name.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
                title: Row(children: [
                  Flexible(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                  if (repo.failedSources.contains(s.id)) ...[
                    const SizedBox(width: 6),
                    const Tooltip(message: 'تعذّر التحديث مؤخراً', child: Icon(Icons.error_outline, color: Colors.orange, size: 16)),
                  ],
                ]),
                subtitle: Text(s.description, style: const TextStyle(height: 1.5, fontSize: 12)),
              ),
            ),
          ),
      ]),
    );
  }
}

class LivePage extends StatelessWidget {
  final ChannelRepository? channel;
  const LivePage({super.key, this.channel});

  static const streams = [
    ('الجزيرة مباشر', 'بث مباشر لقناة الجزيرة الإخبارية', 'https://www.aljazeera.net/video/live', Color(0xFFC8962B)),
    ('بي بي سي عربي', 'آخر الأخبار والتغطيات المصورة', 'https://www.bbc.com/arabic', Color(0xFFB80000)),
    ('أخبار الأمم المتحدة', 'تقارير الوضع الإنساني في غزة', 'https://news.un.org/ar/', Color(0xFF009EDB)),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('البث المباشر')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (channel != null)
            StreamBuilder<List<ChannelPost>>(
              stream: channel!.watchPosts(),
              initialData: channel!.posts,
              builder: (context, _) {
                final lives = channel!.activeLives;
                if (lives.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionTitle('بث المراسلين الآن'),
                  const SizedBox(height: 10),
                  for (final p in lives)
                    Card(
                      color: urgent,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () => openExternal(context, p.liveUrl!),
                        leading: const Icon(Icons.sensors, color: Colors.white, size: 30),
                        title: Text(p.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        subtitle: Text('${p.authorName} • ${p.region} • ${livePlatformName(p.liveUrl!)}',
                            style: const TextStyle(color: Colors.white70)),
                        trailing: const Icon(Icons.play_circle_fill, color: Colors.white, size: 34),
                      ),
                    ),
                  const SizedBox(height: 14),
                  const SectionTitle('قنوات إخبارية'),
                  const SizedBox(height: 10),
                ]);
              },
            ),
          for (final s in streams)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => openExternal(context, s.$3),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 150),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [s.$4, Color.lerp(s.$4, ink, .7)!],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: urgent, borderRadius: BorderRadius.circular(6)),
                          child: const Text('● مباشر', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 10),
                        Text(s.$1, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(s.$2, style: const TextStyle(color: Colors.white70)),
                      ]),
                    ),
                    const Icon(Icons.play_circle_fill, color: Colors.white, size: 58),
                  ]),
                ),
              ),
            ),
          const InfoNote(
            icon: Icons.info_outline,
            text: 'يفتح البث على موقع القناة الرسمي مباشرة. لا يعيد التطبيق بث أي محتوى بدون ترخيص.',
          ),
        ]),
      );
}
