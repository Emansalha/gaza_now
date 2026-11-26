import 'package:flutter/material.dart';

import '../ads/ads.dart';
import '../news/news_models.dart';
import '../news/news_repository.dart';
import '../theme.dart';
import '../widgets/news_widgets.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onOpenChannel, onOpenLive, onOpenRadio, onOpenMap;
  const HomePage({
    super.key,
    required this.onOpenChannel,
    required this.onOpenLive,
    required this.onOpenRadio,
    required this.onOpenMap,
  });
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool gazaOnly = true;
  String? sourceFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NewsScope.read(context).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = NewsScope.of(context);
    var list = gazaOnly ? repo.gaza : repo.all;
    if (sourceFilter != null) list = list.where((a) => a.sourceId == sourceFilter).toList();
    final gazaNews = repo.gaza;
    final carousel = (gazaNews.length >= 3 ? gazaNews : repo.all).where((a) => repo.imageFor(a) != null).take(6).toList();
    final carouselLinks = carousel.map((a) => a.link).toSet();
    final feed = list.where((a) => !carouselLinks.contains(a.link)).toList();
    final loadingFirst = repo.loading && !repo.hasData;

    return RefreshIndicator(
      color: teal,
      onRefresh: repo.refresh,
      child: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (gazaNews.isNotEmpty) BreakingTicker(items: gazaNews.take(8).toList()),
              const SizedBox(height: 16),
            ]),
          ),
        ),
        if (loadingFirst)
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Skeleton(height: 250, radius: 24)),
          )
        else if (carousel.isNotEmpty)
          SliverToBoxAdapter(child: HeroCarousel(items: carousel)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(children: [
                Expanded(child: _QuickAction(icon: Icons.campaign, label: 'قناة المراسلين', onTap: widget.onOpenChannel)),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(icon: Icons.live_tv, label: 'البث المباشر', onTap: widget.onOpenLive, color: urgent),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _QuickAction(icon: Icons.radio, label: 'راديو الأخبار', onTap: widget.onOpenRadio, color: const Color(0xFF6A4FB3)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(icon: Icons.map_outlined, label: 'خريطة غزة', onTap: widget.onOpenMap, color: const Color(0xFF2B8C8C)),
                ),
              ]),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: teal,
                    selectedForegroundColor: Colors.white,
                  ),
                  segments: const [
                    ButtonSegment(value: true, label: Text('غزة وفلسطين'), icon: Icon(Icons.location_on_outlined)),
                    ButtonSegment(value: false, label: Text('كل الأخبار'), icon: Icon(Icons.public)),
                  ],
                  selected: {gazaOnly},
                  onSelectionChanged: (s) => setState(() => gazaOnly = s.first),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _SourceChip(label: 'كل المصادر', selected: sourceFilter == null, onTap: () => setState(() => sourceFilter = null)),
                  for (final s in NewsRepository.availableSources.where((s) => repo.enabledSources.contains(s.id)))
                    _SourceChip(
                      label: s.name,
                      color: s.color,
                      selected: sourceFilter == s.id,
                      onTap: () => setState(() => sourceFilter = sourceFilter == s.id ? null : s.id),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              SectionTitle(
                gazaOnly ? 'آخر أخبار غزة' : 'آخر الأخبار',
                trailing: repo.loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: teal))
                    : Text(
                        repo.lastUpdated == null ? '' : 'حُدّث ${timeAgo(repo.lastUpdated!)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
              ),
              if (repo.failedSources.isNotEmpty && repo.hasData) ...[
                const SizedBox(height: 8),
                Text(
                  'تعذّر تحديث: ${repo.failedSources.map((id) => sourceById(id).name).join('، ')}',
                  style: const TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ],
              const SizedBox(height: 12),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: loadingFirst
              ? SliverList(delegate: SliverChildBuilderDelegate((_, __) => const CardSkeleton(), childCount: 6))
              : feed.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyState(
                        icon: repo.hasData ? Icons.search_off : Icons.wifi_off_rounded,
                        title: repo.hasData ? 'لا توجد أخبار بهذا التصنيف الآن' : 'تعذّر تحميل الأخبار',
                        subtitle: repo.hasData ? 'جرّب مصدراً آخر أو «كل الأخبار».' : 'تأكد من اتصالك بالإنترنت ثم حاول مجدداً.',
                        action: FilledButton.icon(
                          onPressed: repo.refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          // Ad 1 sits after the 4th story.
                          const adAt = 4;
                          if (feed.length > adAt && i == adAt) return BannerAdBox.home();
                          final idx = feed.length > adAt && i > adAt ? i - 1 : i;
                          final a = feed[idx];
                          return idx % 5 == 0 ? FeaturedCard(article: a) : CompactCard(article: a);
                        },
                        childCount: feed.length + (feed.length > 4 ? 1 : 0),
                      ),
                    ),
        ),
        SliverToBoxAdapter(
          child: loadingFirst || feed.isEmpty
              ? const SizedBox(height: 24)
              : FeedEnd(
                  count: feed.length,
                  onRefresh: repo.refresh,
                  onShowAll: gazaOnly ? () => setState(() => gazaOnly = false) : null,
                ),
        ),
      ]),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _SourceChip({required this.label, required this.selected, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          avatar: color == null ? null : CircleAvatar(backgroundColor: color, radius: 6),
          onSelected: (_) => onTap(),
          selectedColor: teal,
          backgroundColor: context.surfaceCard,
          labelStyle: TextStyle(color: selected ? Colors.white : context.titleColor, fontWeight: FontWeight.w700, fontSize: 12),
          side: BorderSide.none,
        ),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.color = teal});
  @override
  Widget build(BuildContext context) => Material(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: context.titleColor))),
            ]),
          ),
        ),
      );
}
