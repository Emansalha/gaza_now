import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'channel/channel_models.dart';
import 'channel/channel_page.dart';
import 'channel/channel_repository.dart';
import 'theme.dart';

class NewsItem {
  final String title, summary, region, category, time;
  final bool breaking, live;
  const NewsItem(this.title, this.summary, this.region, this.category, this.time,
      {this.breaking = false, this.live = false});
}

const news = <NewsItem>[
  NewsItem('آخر المستجدات في شمال غزة', 'تغطية إخبارية مستمرة لأبرز التطورات الميدانية والإنسانية في شمال القطاع.', 'شمال غزة', 'أخبار عاجلة', 'منذ 12 دقيقة', breaking: true),
  NewsItem('جهود إنسانية لدعم العائلات النازحة', 'متابعة أوضاع العائلات واحتياجاتها الأساسية ومعلومات الخدمات المتاحة.', 'مدينة غزة', 'إنساني', 'منذ 35 دقيقة'),
  NewsItem('تحديث حول الخدمات الصحية', 'معلومات وإرشادات حول الخدمات الصحية ونقاط تقديم الرعاية وفق المصادر المتاحة.', 'دير البلح', 'صحة', 'منذ ساعة'),
  NewsItem('تغطية مباشرة من قطاع غزة', 'تابع التغطية المباشرة وآخر التحديثات من فريق الأخبار.', 'قطاع غزة', 'بث مباشر', 'مباشر', live: true),
  NewsItem('مستجدات الأوضاع في خانيونس', 'ملخص لأهم الأخبار والتطورات الواردة من محافظة خانيونس.', 'خانيونس', 'أخبار', 'منذ ساعتين'),
];

const governorates = ['شمال غزة', 'مدينة غزة', 'دير البلح', 'خانيونس', 'رفح'];

class HomeShell extends StatefulWidget {
  final SharedPreferences prefs;
  final ValueNotifier<bool> darkMode;
  final ChannelRepository channel;
  const HomeShell({super.key, required this.prefs, required this.darkMode, required this.channel});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  late final Set<int> saved = {
    for (final s in widget.prefs.getStringList('saved') ?? const <String>[])
      if (int.tryParse(s) case final i? when i >= 0 && i < news.length) i,
  };

  static const channelTab = 2;
  int unread = 0;
  late int _lastCount = widget.channel.posts.length;
  StreamSubscription<List<ChannelPost>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.channel.watchPosts().listen(_onPosts);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onPosts(List<ChannelPost> posts) {
    final added = posts.length - _lastCount;
    _lastCount = posts.length;
    if (added <= 0 || !mounted || tab == channelTab) return;
    setState(() => unread += added);
    final latest = posts.first;
    if (latest.urgent && widget.channel.subscribed && !widget.channel.muted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: urgent,
        content: Text('عاجل: ${latest.text}', maxLines: 2, overflow: TextOverflow.ellipsis),
        action: SnackBarAction(label: 'عرض', textColor: Colors.white, onPressed: () => setTab(channelTab)),
      ));
    }
  }

  void setTab(int i) => setState(() {
        tab = i;
        if (i == channelTab) unread = 0;
      });

  void openLive() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('البث المباشر')), body: const LivePage())),
      );

  void openNotifications() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
  void openSearch() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => SearchPage(onOpen: openArticle)));

  void toggleSave(int i) {
    setState(() => saved.contains(i) ? saved.remove(i) : saved.add(i));
    widget.prefs.setStringList('saved', saved.map((e) => '$e').toList());
  }

  void openArticle(int i) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticlePage(item: news[i], initiallySaved: saved.contains(i), onSave: () => toggleSave(i)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onSearch: openSearch,
        onOpen: openArticle,
        saved: saved,
        onSave: toggleSave,
        onOpenChannel: () => setTab(channelTab),
        onOpenLive: openLive,
      ),
      const MapPage(),
      ChannelPage(repo: widget.channel, onOpenLive: openLive),
      SavedPage(saved: saved, onOpen: openArticle, onSave: toggleSave),
      MorePage(darkMode: widget.darkMode, onNotifications: openNotifications),
    ];
    return Scaffold(
      appBar: tab == 4 || tab == channelTab
          ? null
          : AppBar(
              title: Row(mainAxisSize: MainAxisSize.min, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset('assets/images/logo.png', width: 28, height: 28),
                ),
                const SizedBox(width: 8),
                const Text('غزة الآن', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(width: 6),
                const Text('Gaza Now', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
              actions: [
                IconButton(onPressed: openSearch, icon: const Icon(Icons.search), tooltip: 'بحث'),
                IconButton(onPressed: openNotifications, icon: const Icon(Icons.notifications_none), tooltip: 'الإشعارات'),
              ],
            ),
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: setTab,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'الخريطة'),
          NavigationDestination(
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.campaign_outlined)),
            selectedIcon: const Icon(Icons.campaign),
            label: 'القناة',
          ),
          const NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'المحفوظات'),
          const NavigationDestination(icon: Icon(Icons.menu), selectedIcon: Icon(Icons.menu_open), label: 'المزيد'),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onSearch, onOpenChannel, onOpenLive;
  final ValueChanged<int> onOpen, onSave;
  final Set<int> saved;
  const HomePage({super.key, required this.onSearch, required this.onOpen, required this.onSave, required this.saved,
      required this.onOpenChannel, required this.onOpenLive});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? region; // null = all of Gaza

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (var i = 0; i < news.length; i++)
        if (region == null || news[i].region == region || news[i].region == 'قطاع غزة') i,
    ];
    return RefreshIndicator(
      color: teal,
      onRefresh: () => Future.delayed(const Duration(milliseconds: 700)),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [ink, teal], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.campaign, color: Colors.white),
              const SizedBox(width: 8),
              const Text('تنبيه الأخبار العاجلة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: urgent, borderRadius: BorderRadius.circular(20)),
                child: const Text('عاجل', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ]),
            const SizedBox(height: 12),
            const Text('تابع آخر المستجدات من مختلف مناطق قطاع غزة',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('أخبار • خدمات • تغطية مباشرة', style: TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _QuickAction(icon: Icons.campaign, label: 'قناة المراسلين', onTap: widget.onOpenChannel)),
          const SizedBox(width: 10),
          Expanded(child: _QuickAction(icon: Icons.live_tv, label: 'البث المباشر', onTap: widget.onOpenLive, color: urgent)),
        ]),
        const SizedBox(height: 18),
        const SectionTitle('تصفح حسب المنطقة'),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            RegionChip('كل غزة', selected: region == null, onTap: () => setState(() => region = null)),
            for (final g in governorates)
              RegionChip(g, selected: region == g, onTap: () => setState(() => region = g)),
          ]),
        ),
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: SectionTitle('أهم الأخبار')),
          TextButton(onPressed: widget.onSearch, child: const Text('بحث متقدم')),
        ]),
        if (visible.isEmpty)
          const EmptyState(title: 'لا توجد أخبار لهذه المنطقة حالياً', subtitle: 'اختر منطقة أخرى أو عد لاحقاً.'),
        ...visible.map((i) => NewsCard(
              item: news[i],
              saved: widget.saved.contains(i),
              onTap: () => widget.onOpen(i),
              onSave: () => widget.onSave(i),
            )),
        const SizedBox(height: 12),
        const InfoNote(text: 'نعرض الأخبار مع إظهار المصدر ووقت النشر. تحقق دائماً من المعلومات العاجلة عبر المصادر الموثوقة.'),
      ]),
    );
  }
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
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Row(children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: context.titleColor))),
            ]),
          ),
        ),
      );
}

class RegionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const RegionChip(this.label, {super.key, this.selected = false, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: onTap == null ? null : (_) => onTap!(),
          selectedColor: teal,
          backgroundColor: context.surfaceCard,
          disabledColor: context.surfaceCard,
          labelStyle: TextStyle(color: selected ? Colors.white : context.titleColor, fontWeight: FontWeight.w600),
          side: BorderSide.none,
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.titleColor));
}

class NewsCard extends StatelessWidget {
  final NewsItem item;
  final bool saved;
  final VoidCallback onTap, onSave;
  const NewsCard({super.key, required this.item, required this.saved, required this.onTap, required this.onSave});
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(color: context.softFill, borderRadius: BorderRadius.circular(14)),
                child: Icon(item.live ? Icons.play_circle_fill : Icons.newspaper, size: 36, color: teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (item.breaking || item.live) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: item.live ? teal : urgent, borderRadius: BorderRadius.circular(6)),
                        child: Text(item.live ? 'مباشر' : 'عاجل',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(item.category, style: const TextStyle(color: teal, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text('${item.region} • ${item.time}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ]),
              ),
              IconButton(
                onPressed: onSave,
                tooltip: saved ? 'إزالة من المحفوظات' : 'حفظ',
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: teal),
              ),
            ]),
          ),
        ),
      );
}

class ArticlePage extends StatefulWidget {
  final NewsItem item;
  final bool initiallySaved;
  final VoidCallback onSave;
  const ArticlePage({super.key, required this.item, required this.initiallySaved, required this.onSave});
  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  late bool isSaved = widget.initiallySaved;

  void toggle() {
    widget.onSave();
    setState(() => isSaved = !isSaved);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(isSaved ? 'تم حفظ الخبر' : 'تمت إزالة الخبر من المحفوظات')));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الخبر'), actions: [
        IconButton(onPressed: toggle, icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border)),
      ]),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(
          height: 210,
          decoration: BoxDecoration(color: context.softFill, borderRadius: BorderRadius.circular(20)),
          child: Icon(item.live ? Icons.play_circle : Icons.image, size: 72, color: teal),
        ),
        const SizedBox(height: 18),
        Text(item.category, style: const TextStyle(color: teal, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(item.title, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: context.titleColor)),
        const SizedBox(height: 8),
        Text('${item.region} • ${item.time}', style: const TextStyle(color: Colors.grey)),
        const Divider(height: 28),
        Text(item.summary, style: const TextStyle(fontSize: 16, height: 1.8)),
        const SizedBox(height: 20),
        const InfoNote(text: 'هذه نسخة تجريبية ببيانات توضيحية. يجب ربط التطبيق بمصادر أخبار موثوقة قبل النشر العام.'),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: toggle,
          icon: Icon(isSaved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
          label: Text(isSaved ? 'إزالة من المحفوظات' : 'حفظ الخبر'),
        ),
      ]),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const entries = [
    ('عاجل: تحديث من شمال غزة', 'تحديث إخباري تجريبي • شمال غزة', 'منذ 5 دقائق', urgent, true),
    ('معلومات خدمات جديدة', 'تحديث خدمات • مدينة غزة', 'منذ 35 دقيقة', teal, false),
    ('بدأ بث مباشر', 'تغطية مباشرة من قطاع غزة', 'منذ ساعة', teal, false),
    ('تحديث حول الخدمات الصحية', 'معلومات صحية • الوسطى', 'منذ ساعتين', Colors.blueGrey, false),
  ];
  final Set<int> read = {};
  int filter = 0; // 0 all, 1 unread, 2 urgent

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (var i = 0; i < entries.length; i++)
        if (filter == 0 || (filter == 1 && !read.contains(i)) || (filter == 2 && entries[i].$5)) i,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات'), actions: [
        TextButton(
          onPressed: () => setState(() => read.addAll(List.generate(entries.length, (i) => i))),
          child: const Text('قراءة الكل'),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('تابع التنبيهات حسب اهتماماتك ومناطقك المفضلة.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        Wrap(children: [
          RegionChip('الكل', selected: filter == 0, onTap: () => setState(() => filter = 0)),
          RegionChip('غير مقروء', selected: filter == 1, onTap: () => setState(() => filter = 1)),
          RegionChip('عاجل', selected: filter == 2, onTap: () => setState(() => filter = 2)),
        ]),
        const SizedBox(height: 12),
        if (shown.isEmpty) const EmptyState(title: 'لا توجد إشعارات', subtitle: 'ستظهر التنبيهات الجديدة هنا.'),
        ...shown.map((i) {
          final e = entries[i];
          return Card(
            child: ListTile(
              onTap: () => setState(() => read.add(i)),
              leading: CircleAvatar(
                backgroundColor: e.$4.withValues(alpha: .12),
                child: Icon(Icons.notifications_active, color: e.$4),
              ),
              title: Text(e.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${e.$2}\n${e.$3}'),
              isThreeLine: true,
              trailing: read.contains(i) ? null : const Icon(Icons.circle, color: teal, size: 9),
            ),
          );
        }),
        const SizedBox(height: 10),
        const InfoNote(text: 'يمكن لاحقاً تفعيل الإشعارات الفورية عبر Firebase Cloud Messaging وربطها باختيار المحافظة.'),
      ]),
    );
  }
}

class SearchPage extends StatefulWidget {
  final ValueChanged<int> onOpen;
  const SearchPage({super.key, required this.onOpen});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    final results = [
      for (var i = 0; i < news.length; i++)
        if ('${news[i].title} ${news[i].summary} ${news[i].region} ${news[i].category}'.contains(q)) i,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('البحث')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          autofocus: true,
          onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(
            hintText: 'ابحث عن خبر أو منطقة...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: context.surfaceCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('نتائج البحث'),
        const SizedBox(height: 10),
        if (results.isEmpty) const EmptyState(title: 'لا توجد نتائج', subtitle: 'جرّب كلمات بحث مختلفة.'),
        ...results.map((i) => Card(
              child: ListTile(
                onTap: () => widget.onOpen(i),
                leading: const Icon(Icons.article_outlined, color: teal),
                title: Text(news[i].title),
                subtitle: Text('${news[i].region} • ${news[i].time}'),
              ),
            )),
      ]),
    );
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const SectionTitle('خريطة قطاع غزة'),
        const SizedBox(height: 8),
        const Text('اختر المحافظة لمتابعة الأخبار والمعلومات المرتبطة بها.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 14),
        Container(
          height: 300,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: context.isDark
                  ? const [Color(0xFF17343B), Color(0xFF0F2328)]
                  : const [Color(0xFFDDEBED), Color(0xFFBBD5D9)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Stack(children: [
            Center(child: Icon(Icons.map, size: 150, color: Color(0xFF6F9DA5))),
            Positioned(top: 55, right: 65, child: MapPin('شمال غزة')),
            Positioned(top: 125, left: 70, child: MapPin('مدينة غزة')),
            Positioned(bottom: 90, right: 95, child: MapPin('الوسطى')),
            Positioned(bottom: 45, left: 80, child: MapPin('خانيونس')),
            Positioned(bottom: 12, right: 155, child: MapPin('رفح')),
          ]),
        ),
        const SizedBox(height: 16),
        const SectionTitle('المحافظات'),
        const SizedBox(height: 8),
        Wrap(runSpacing: 8, children: [for (final g in governorates) RegionChip(g)]),
        const SizedBox(height: 12),
        const InfoNote(text: 'الخريطة هنا توضيحية. يلزم ربط مزود خرائط وبيانات جغرافية موثوقة لعرض المواقع الفعلية.'),
      ]);
}

class MapPin extends StatelessWidget {
  final String label;
  const MapPin(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        const Icon(Icons.location_on, color: urgent, size: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ink)),
        ),
      ]);
}

class LivePage extends StatelessWidget {
  const LivePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const SectionTitle('البث المباشر'),
        const SizedBox(height: 12),
        Container(
          height: 220,
          decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(20)),
          child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 72)),
        ),
        const SizedBox(height: 14),
        Text('تغطية مباشرة من قطاع غزة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: context.titleColor)),
        const SizedBox(height: 8),
        const Text('مساحة مخصصة للبث المباشر من مصادر إعلامية موثوقة. لا يوجد بث مربوط في النسخة التجريبية.',
            style: TextStyle(height: 1.7)),
        const SizedBox(height: 16),
        const InfoNote(text: 'لإطلاق البث يلزم توفير رابط بث مرخّص وآمن والتحقق من حقوق استخدامه.'),
      ]);
}

class SavedPage extends StatelessWidget {
  final Set<int> saved;
  final ValueChanged<int> onOpen, onSave;
  const SavedPage({super.key, required this.saved, required this.onOpen, required this.onSave});
  @override
  Widget build(BuildContext context) {
    final items = saved.toList()..sort();
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SectionTitle('الأخبار المحفوظة'),
      const SizedBox(height: 12),
      if (items.isEmpty) const EmptyState(title: 'لا توجد أخبار محفوظة', subtitle: 'احفظ الأخبار المهمة لتعود إليها لاحقاً.'),
      ...items.map((i) => NewsCard(item: news[i], saved: true, onTap: () => onOpen(i), onSave: () => onSave(i))),
    ]);
  }
}

class MorePage extends StatelessWidget {
  final ValueNotifier<bool> darkMode;
  final VoidCallback onNotifications;
  const MorePage({super.key, required this.darkMode, required this.onNotifications});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [ink, teal], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset('assets/images/logo.png', width: 58, height: 58),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('غزة الآن', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                Text('Gaza Now • أخبار موثوقة من غزة', style: TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        const SectionTitle('الإعدادات'),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('الإشعارات والتنبيهات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: onNotifications,
            ),
            const Divider(height: 1),
            ValueListenableBuilder<bool>(
              valueListenable: darkMode,
              builder: (_, dark, __) => SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('الوضع الداكن'),
                value: dark,
                onChanged: (v) => darkMode.value = v,
              ),
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.language),
              title: Text('اللغة'),
              subtitle: Text('العربية (الافتراضية)'),
              trailing: Icon(Icons.chevron_left),
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.location_on_outlined),
              title: Text('المناطق المفضلة'),
              subtitle: Text('تحديد المحافظات التي تهمك'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('حول التطبيق'),
              subtitle: const Text('الإصدار 1.1.0'),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'غزة الآن',
                applicationVersion: '1.1.0',
                applicationIcon: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/images/logo.png', width: 44, height: 44),
                ),
                children: const [Text('تطبيق إخباري عربي لمتابعة مستجدات قطاع غزة.')],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        const InfoNote(text: 'هذه النسخة واجهة تشغيل أولية. قبل النشر يجب إعداد الخادم، مصادر الأخبار، سياسة الخصوصية، وإدارة صلاحيات الإشعارات.'),
      ]);
}

class EmptyState extends StatelessWidget {
  final String title, subtitle;
  const EmptyState({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 45),
        child: Column(children: [
          const Icon(Icons.inbox_outlined, size: 54, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 5),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ]),
      );
}

class InfoNote extends StatelessWidget {
  final String text;
  const InfoNote({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: context.noteFill, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, color: teal, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: context.titleColor, height: 1.5, fontSize: 12)),
          ),
        ]),
      );
}
