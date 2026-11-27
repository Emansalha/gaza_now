import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../ads/ads.dart';
import '../news/news_models.dart';
import '../news/news_repository.dart';
import '../pages/article_page.dart';
import '../theme.dart';

void openArticle(BuildContext context, Article a, {String? heroTag}) {
  // Ad 3: occasional full-screen ad (frequency-capped in AdService).
  AdService.instance.onArticleOpened();
  Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, __, ___) => ArticlePage(article: a, heroTag: heroTag),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  ));
}

/// Article photo with caching, an animated skeleton while loading, and a
/// branded placeholder when the outlet provides no photo.
class NewsImage extends StatefulWidget {
  final Article article;
  final double? width, height;
  final BorderRadius? radius;
  const NewsImage({super.key, required this.article, this.width, this.height, this.radius});
  @override
  State<NewsImage> createState() => _NewsImageState();
}

class _NewsImageState extends State<NewsImage> {
  String? url;
  bool resolving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(NewsImage old) {
    super.didUpdateWidget(old);
    if (old.article.link != widget.article.link) {
      url = null;
      _resolve();
    }
  }

  void _resolve() {
    final repo = NewsScope.read(context);
    url = repo.imageFor(widget.article);
    if (url == null && !resolving) {
      resolving = true;
      final link = widget.article.link;
      repo.resolveImage(widget.article).then((u) {
        if (!mounted || widget.article.link != link) return;
        setState(() {
          url = u;
          resolving = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = url == null
        ? (resolving ? const Skeleton() : _Placeholder(source: widget.article.source))
        : CachedNetworkImage(
            imageUrl: url!,
            // Some news sites refuse image requests that do not look like a browser.
            httpHeaders: {
              'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Mobile Safari/537.36',
              'Referer': widget.article.source.homepage,
            },
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 350),
            placeholder: (_, __) => const Skeleton(),
            errorWidget: (_, __, ___) => _Placeholder(source: widget.article.source),
          );
    return ClipRRect(
      borderRadius: widget.radius ?? BorderRadius.zero,
      child: SizedBox(width: widget.width, height: widget.height, child: child),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final NewsSource source;
  const _Placeholder({required this.source});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [source.color, Color.lerp(source.color, ink, .65)!],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        // Scales down to fit any thumbnail size and any text size.
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.newspaper_rounded, color: Colors.white70, size: 30),
              const SizedBox(height: 4),
              Text(source.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          ),
        ),
      );
}

/// Pulsing grey block used while content loads.
class Skeleton extends StatefulWidget {
  final double? width, height;
  final double radius;
  const Skeleton({super.key, this.width, this.height, this.radius = 0});
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .45, end: 1.0).animate(c),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(color: context.softFill, borderRadius: BorderRadius.circular(widget.radius)),
        ),
      );
}

String _initial(String? name, String fallback) {
  final n = (name ?? '').trim().isNotEmpty ? name!.trim() : fallback;
  return n.isEmpty ? '•' : n.characters.first;
}

class SourceBadge extends StatelessWidget {
  final NewsSource source;
  final String? name;
  final bool light;
  const SourceBadge(this.source, {super.key, this.light = false, this.name});
  SourceBadge.of(Article a, {Key? key, bool light = false}) : this(a.source, key: key, light: light, name: a.publisher);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: source.color, shape: BoxShape.circle),
          child: Text(_initial(name, source.name),
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, height: 1.1)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text((name ?? '').trim().isNotEmpty ? name!.trim() : source.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: light ? Colors.white : context.titleColor,
              )),
        ),
      ]);
}

class _SaveButton extends StatelessWidget {
  final Article article;
  const _SaveButton(this.article);
  @override
  Widget build(BuildContext context) {
    final repo = NewsScope.of(context);
    final saved = repo.isSaved(article);
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: saved ? 'إزالة من المحفوظات' : 'حفظ',
      onPressed: () => repo.toggleSaved(article),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Icon(saved ? Icons.bookmark : Icons.bookmark_border, key: ValueKey(saved), color: teal),
      ),
    );
  }
}

/// Large card: photo on top, headline and summary below.
class FeaturedCard extends StatelessWidget {
  final Article article;
  final String tagPrefix;
  const FeaturedCard({super.key, required this.article, this.tagPrefix = 'f'});
  @override
  Widget build(BuildContext context) {
    final tag = '$tagPrefix-${article.link}';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openArticle(context, article, heroTag: tag),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            Hero(tag: tag, child: NewsImage(article: article, height: 190, width: double.infinity)),
            if (article.isBreaking)
              PositionedDirectional(
                top: 10,
                start: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: urgent, borderRadius: BorderRadius.circular(6)),
                  child: const Text('عاجل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(article.title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.45, color: context.titleColor)),
              if (article.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(article.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.titleColor.withValues(alpha: .7), height: 1.6, fontSize: 14)),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 4, 4),
            child: Row(children: [
              Flexible(child: SourceBadge.of(article)),
              const SizedBox(width: 8),
              Text('• ${timeAgo(article.published)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Spacer(),
              _SaveButton(article),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Compact row card: thumbnail beside the headline.
class CompactCard extends StatelessWidget {
  final Article article;
  final String tagPrefix;
  const CompactCard({super.key, required this.article, this.tagPrefix = 'c'});
  @override
  Widget build(BuildContext context) {
    final tag = '$tagPrefix-${article.link}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openArticle(context, article, heroTag: tag),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Hero(
              tag: tag,
              child: NewsImage(article: article, width: 104, height: 92, radius: BorderRadius.circular(14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 92),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.45, color: context.titleColor)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SourceBadge.of(article),
                    Text(timeAgo(article.published), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ]),
              ),
            ),
            _SaveButton(article),
          ]),
        ),
      ),
    );
  }
}

class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          const Skeleton(width: 104, height: 92, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Skeleton(height: 14, radius: 6),
              SizedBox(height: 8),
              Skeleton(height: 14, width: 160, radius: 6),
              SizedBox(height: 24),
              Skeleton(height: 10, width: 90, radius: 6),
            ]),
          ),
        ]),
      );
}

/// Red "عاجل" strip with headlines scrolling continuously.
class BreakingTicker extends StatefulWidget {
  final List<Article> items;
  const BreakingTicker({super.key, required this.items});
  @override
  State<BreakingTicker> createState() => _BreakingTickerState();
}

class _BreakingTickerState extends State<BreakingTicker> {
  final controller = ScrollController();
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!controller.hasClients) return;
      final next = controller.offset + 1;
      if (next >= controller.position.maxScrollExtent) {
        controller.jumpTo(0);
      } else {
        controller.jumpTo(next);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Container(
      height: 42,
      decoration: BoxDecoration(color: context.surfaceCard, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        Container(
          color: urgent,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: const Row(children: [
            _LiveDot(),
            SizedBox(width: 6),
            Text('عاجل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.isEmpty ? 0 : items.length * 50,
            itemBuilder: (_, i) {
              final a = items[i % items.length];
              return InkWell(
                onTap: () => openArticle(context, a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Text('${a.title}   ◆',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.titleColor)),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: c,
        child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
      );
}

/// Swipeable photo carousel of top stories, auto-advancing.
class HeroCarousel extends StatefulWidget {
  final List<Article> items;
  const HeroCarousel({super.key, required this.items});
  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final controller = PageController(viewportFraction: .9);
  int page = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!controller.hasClients || widget.items.isEmpty) return;
      final next = (page + 1) % widget.items.length;
      controller.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Column(children: [
      SizedBox(
        height: 250,
        child: PageView.builder(
          controller: controller,
          itemCount: items.length,
          onPageChanged: (i) => setState(() => page = i),
          itemBuilder: (_, i) {
            final a = items[i];
            final tag = 'hero-${a.link}';
            return AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: i == page ? 0 : 12),
              child: GestureDetector(
                onTap: () => openArticle(context, a, heroTag: tag),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(fit: StackFit.expand, children: [
                    Hero(tag: tag, child: NewsImage(article: a)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x33000000), Color(0xE6000000)],
                          stops: [.35, .55, 1],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 16,
                      end: 16,
                      bottom: 16,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: SourceBadge.of(a, light: true),
                        ),
                        const SizedBox(height: 8),
                        Text(a.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.4)),
                        const SizedBox(height: 4),
                        Text(timeAgo(a.published), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == page ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == page ? teal : teal.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    ]);
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.titleColor)),
        ),
        if (trailing != null) trailing!,
      ]);
}

class EmptyState extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Widget? action;
  const EmptyState({super.key, required this.title, required this.subtitle, this.icon = Icons.inbox_outlined, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(children: [
          Icon(icon, size: 56, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 5),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, height: 1.5)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      );
}

class InfoNote extends StatelessWidget {
  final String text;
  final IconData icon;
  const InfoNote({super.key, required this.text, this.icon = Icons.verified_user_outlined});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: context.noteFill, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: teal, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: context.titleColor, height: 1.55, fontSize: 12))),
        ]),
      );
}

/// Shown under the last story so the reader knows the list really ended.
class FeedEnd extends StatelessWidget {
  final int count;
  final VoidCallback onRefresh;
  final VoidCallback? onShowAll;
  const FeedEnd({super.key, required this.count, required this.onRefresh, this.onShowAll});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          const Icon(Icons.check_circle_outline, color: teal, size: 30),
          const SizedBox(height: 8),
          Text('شاهدت كل الأخبار ($count خبراً)',
              style: TextStyle(fontWeight: FontWeight.w700, color: context.titleColor)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
            OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('تحديث الأخبار')),
            if (onShowAll != null)
              FilledButton.icon(onPressed: onShowAll, icon: const Icon(Icons.public), label: const Text('عرض كل الأخبار')),
          ]),
        ]),
      );
}
