import 'package:flutter/material.dart';

import '../news/news_repository.dart';
import '../theme.dart';
import '../widgets/news_widgets.dart';
import 'list_pages.dart';

/// Stylised, tappable map of the Gaza Strip's five governorates, with a live
/// count of current stories mentioning each one.
class MapPage extends StatelessWidget {
  const MapPage({super.key});

  static const _segments = [
    ('شمال غزة', 66.0, Color(0xFF0B6E79)),
    ('مدينة غزة', 78.0, Color(0xFF087D89)),
    ('دير البلح', 86.0, Color(0xFF16949E)),
    ('خانيونس', 104.0, Color(0xFF2AA8A8)),
    ('رفح', 80.0, Color(0xFF47B9A9)),
  ];

  void _open(BuildContext context, String g) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleListPage(title: 'أخبار $g', articlesOf: (r) => r.forGovernorate(g)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final repo = NewsScope.of(context);
    final counts = {for (final s in _segments) s.$1: repo.forGovernorate(s.$1).length};
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SectionTitle('خريطة قطاع غزة'),
      const SizedBox(height: 6),
      const Text('اضغط على المحافظة لعرض آخر الأخبار المتعلقة بها.', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 14),
      Container(
        height: 430,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: context.isDark
                ? const [Color(0xFF0E3550), Color(0xFF123B45), Color(0xFF1A2E2A)]
                : const [Color(0xFF9FD3EA), Color(0xFFCFE9F2), Color(0xFFEFE6D2)],
            stops: const [0, .42, .7],
          ),
        ),
        child: Stack(children: [
          // Sea (west) and land (east) labels.
          Positioned(
            left: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text('البحر المتوسط',
                    style: TextStyle(
                      color: context.isDark ? Colors.white54 : const Color(0xFF2F6F8F),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    )),
              ),
            ),
          ),
          Center(
            child: Transform.rotate(
              angle: .5,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < _segments.length; i++)
                  _Governorate(
                    name: _segments[i].$1,
                    width: _segments[i].$2,
                    color: _segments[i].$3,
                    count: counts[_segments[i].$1] ?? 0,
                    first: i == 0,
                    last: i == _segments.length - 1,
                    onTap: () => _open(context, _segments[i].$1),
                  ),
              ]),
            ),
          ),
          const PositionedDirectional(
            top: 14,
            start: 14,
            child: _Compass(),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      const SectionTitle('المحافظات'),
      const SizedBox(height: 10),
      for (final s in _segments)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => _open(context, s.$1),
            leading: CircleAvatar(backgroundColor: s.$3, child: const Icon(Icons.location_city, color: Colors.white, size: 20)),
            title: Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${counts[s.$1]} خبر حالياً'),
            trailing: const Icon(Icons.chevron_left),
          ),
        ),
      const SizedBox(height: 8),
      const InfoNote(
        icon: Icons.info_outline,
        text: 'الخريطة تمثيل توضيحي مبسّط وليست خريطة ملاحية. يُحسب عدد الأخبار من ذكر اسم المحافظة أو مناطقها في الأخبار الحالية.',
      ),
    ]);
  }
}

class _Governorate extends StatelessWidget {
  final String name;
  final double width;
  final Color color;
  final int count;
  final bool first, last;
  final VoidCallback onTap;
  const _Governorate({
    required this.name,
    required this.width,
    required this.color,
    required this.count,
    required this.first,
    required this.last,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Material(
          color: color,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(first ? 30 : 8),
            bottom: Radius.circular(last ? 26 : 8),
          ),
          elevation: 3,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: width,
              height: 62,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: count > 0 ? urgent : Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _Compass extends StatelessWidget {
  const _Compass();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: context.surfaceCard.withValues(alpha: .85), shape: BoxShape.circle),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.navigation, color: urgent, size: 18),
          Text('ش', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.titleColor)),
        ]),
      );
}
