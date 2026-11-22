import 'dart:async';

import 'package:flutter/material.dart';

import 'channel/channel_models.dart';
import 'channel/channel_page.dart';
import 'channel/channel_repository.dart';
import 'news/news_repository.dart';
import 'pages/home_page.dart';
import 'pages/list_pages.dart';
import 'pages/map_page.dart';
import 'theme.dart';
import 'widgets/news_widgets.dart';

class AppShell extends StatefulWidget {
  final ValueNotifier<bool> darkMode;
  final ChannelRepository channel;
  const AppShell({super.key, required this.darkMode, required this.channel});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const channelTab = 2;
  int tab = 0;
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

  void push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onOpenChannel: () => setTab(channelTab), onOpenLive: () => push(const LivePage())),
      const MapPage(),
      ChannelPage(repo: widget.channel, onOpenLive: () => push(const LivePage())),
      const SavedPage(),
      MorePage(darkMode: widget.darkMode, onOpenChannel: () => setTab(channelTab), push: push),
    ];
    return Scaffold(
      appBar: tab == 4 || tab == channelTab
          ? null
          : AppBar(
              centerTitle: false,
              titleSpacing: 16,
              title: Row(mainAxisSize: MainAxisSize.min, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset('assets/images/logo.png', width: 34, height: 34),
                ),
                const SizedBox(width: 10),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('غزة الآن', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, height: 1.1)),
                  Text('GAZA NOW', style: TextStyle(fontSize: 9, letterSpacing: 3, color: Colors.grey, height: 1.2)),
                ]),
              ]),
              actions: [
                IconButton(onPressed: () => push(const SearchPage()), icon: const Icon(Icons.search), tooltip: 'بحث'),
                IconButton(
                  onPressed: () => push(const UpdatesPage()),
                  icon: const Icon(Icons.notifications_none),
                  tooltip: 'آخر التحديثات',
                ),
                const SizedBox(width: 4),
              ],
            ),
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: setTab,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'الخريطة'),
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

class MorePage extends StatelessWidget {
  final ValueNotifier<bool> darkMode;
  final VoidCallback onOpenChannel;
  final void Function(Widget) push;
  const MorePage({super.key, required this.darkMode, required this.onOpenChannel, required this.push});

  @override
  Widget build(BuildContext context) {
    final repo = NewsScope.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [ink, teal], begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(children: [
          Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/images/logo.png', width: 62, height: 62)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('غزة الآن', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                Text('أخبار غزة من مصادر موثوقة', style: TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _Stat(value: '${repo.gaza.length}', label: 'خبر عن غزة'),
            _Stat(value: '${repo.enabledSources.length}', label: 'مصادر'),
            _Stat(value: '${repo.saved.length}', label: 'محفوظ'),
          ]),
        ]),
      ),
      const SizedBox(height: 18),
      const SectionTitle('الأخبار'),
      const SizedBox(height: 8),
      Card(
        child: Column(children: [
          _Tile(Icons.verified_outlined, 'مصادر الأخبار', 'اختر المصادر وتعرّف على معايير الموثوقية', () => push(const SourcesPage())),
          const Divider(height: 1),
          _Tile(Icons.notifications_outlined, 'آخر التحديثات', 'خط زمني لأحدث أخبار غزة', () => push(const UpdatesPage())),
          const Divider(height: 1),
          _Tile(Icons.live_tv, 'البث المباشر', 'روابط البث الرسمية للقنوات', () => push(const LivePage())),
          const Divider(height: 1),
          _Tile(Icons.campaign_outlined, 'قناة المراسلين', 'اشترك أو انضم كصحفي', onOpenChannel),
        ]),
      ),
      const SizedBox(height: 16),
      const SectionTitle('الإعدادات'),
      const SizedBox(height: 8),
      Card(
        child: Column(children: [
          ValueListenableBuilder<bool>(
            valueListenable: darkMode,
            builder: (_, dark, __) => SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('الوضع الداكن'),
              value: dark,
              activeThumbColor: teal,
              onChanged: (v) => darkMode.value = v,
            ),
          ),
          const Divider(height: 1),
          _Tile(Icons.refresh, 'تحديث الأخبار الآن', repo.lastUpdated == null ? '' : 'آخر تحديث ${timeAgo(repo.lastUpdated!)}',
              repo.refresh),
          const Divider(height: 1),
          _Tile(Icons.info_outline, 'حول التطبيق', 'الإصدار 1.2.0', () {
            showAboutDialog(
              context: context,
              applicationName: 'غزة الآن',
              applicationVersion: '1.2.0',
              applicationIcon: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/images/logo.png', width: 44, height: 44),
              ),
              children: const [
                Text('تطبيق عربي يجمع أخبار غزة وفلسطين من مؤسسات إعلامية موثوقة، مع قناة مباشرة للمراسلين.'),
              ],
            );
          }),
        ]),
      ),
      const SizedBox(height: 14),
      const InfoNote(
        text: 'الأخبار تأتي مباشرة من الموجزات الرسمية للمصادر مع رابط الخبر الأصلي. تحقق دائماً من المعلومات العاجلة قبل مشاركتها.',
      ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _Tile(this.icon, this.title, this.subtitle, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: teal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      );
}
