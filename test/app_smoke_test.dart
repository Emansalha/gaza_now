import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaza_now/ads/ads.dart';
import 'package:gaza_now/app_shell.dart';
import 'package:gaza_now/channel/channel_models.dart';
import 'package:gaza_now/channel/channel_page.dart';
import 'package:gaza_now/channel/channel_repository.dart';
import 'package:gaza_now/news/news_models.dart';
import 'package:gaza_now/news/news_repository.dart';
import 'package:gaza_now/pages/article_page.dart';
import 'package:gaza_now/pages/list_pages.dart';
import 'package:gaza_now/radio/radio.dart';
import 'package:gaza_now/theme.dart';
import 'package:gaza_now/widgets/news_widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stories of every shape: very long titles, empty summaries, empty publisher
/// names, breaking stories, all sources.
List<Article> sampleArticles(int n) => [
      for (var i = 0; i < n; i++)
        Article(
          link: 'https://example.com/story/$i',
          title: i % 4 == 0
              ? 'عاجل: ${'تطورات ميدانية وإنسانية متسارعة في قطاع غزة ' * 3}رقم $i'
              : 'خبر رقم $i من غزة عن المساعدات والمستشفيات',
          summary: 'ملخص الخبر في غزة. ' * (i % 6 * 8),
          sourceId: newsSources[i % newsSources.length].id,
          published: DateTime.now().subtract(Duration(minutes: i * 37)),
          publisher: i % 9 == 0 ? '' : null,
          category: i % 5 == 0 ? 'سياسة' : null,
        ),
    ];

class Harness {
  final NewsRepository news;
  final LocalChannelRepository channel;
  final RadioService radio = RadioService();
  Harness(this.news, this.channel);

  Widget wrap(Widget home) => NewsScope(
        repo: news,
        child: RadioScope(
          radio: radio,
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: buildTheme(Brightness.light),
            home: home,
          ),
        ),
      );
}

Future<Harness> setUpHarness(WidgetTester tester, {int stories = 60}) async {
  AdService.enabled = false;
  // A small phone with the largest text size the app allows.
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final news = NewsRepository(prefs, client: MockClient((_) async => http.Response('', 404)));
  news.debugSetItems(sampleArticles(stories));
  return Harness(news, LocalChannelRepository(prefs));
}

Future<void> scrollToEnd(WidgetTester tester, Finder scrollable) async {
  for (var k = 0; k < 60; k++) {
    await tester.drag(scrollable, const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> tearDownApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('Home feed scrolls to the very last story with no errors', (tester) async {
    final h = await setUpHarness(tester);
    await tester.pumpWidget(h.wrap(AppShell(darkMode: ValueNotifier(false), channel: h.channel)));
    await tester.pump(const Duration(milliseconds: 300));

    await scrollToEnd(tester, find.byType(CustomScrollView).first);
    expect(tester.takeException(), isNull);
    expect(find.byType(FeedEnd), findsOneWidget);

    // Switch to "all news" from the end of the list and scroll again.
    await tester.tap(find.text('عرض كل الأخبار'));
    await tester.pump(const Duration(milliseconds: 300));
    await scrollToEnd(tester, find.byType(CustomScrollView).first);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester);
  });

  testWidgets('Every tab opens and scrolls without errors', (tester) async {
    final h = await setUpHarness(tester);
    await tester.pumpWidget(h.wrap(AppShell(darkMode: ValueNotifier(false), channel: h.channel)));
    await tester.pump(const Duration(milliseconds: 300));

    for (final label in ['الراديو', 'القناة', 'المحفوظات', 'المزيد', 'الرئيسية']) {
      await tester.tap(find.text(label).last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'tab $label');
    }
    await tearDownApp(tester);
  });

  testWidgets('Article page shows the whole story and scrolls', (tester) async {
    final h = await setUpHarness(tester);
    final a = sampleArticles(10)[4];
    await tester.pumpWidget(h.wrap(ArticlePage(article: a)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(a.title), findsOneWidget);
    await scrollToEnd(tester, find.byType(CustomScrollView).first);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester);
  });

  testWidgets('Journalist live shows a banner in the channel and on the live page', (tester) async {
    final h = await setUpHarness(tester);
    await h.channel.registerJournalist(const Journalist(name: 'مراسل', outlet: 'غزة الآن', phone: '0599', pressId: ''));
    await h.channel.publish(ChannelPost(
      id: 'live1',
      authorName: 'مراسل',
      outlet: 'غزة الآن',
      text: 'تغطية مباشرة من خانيونس',
      region: 'خانيونس',
      createdAt: DateTime.now(),
      liveUrl: 'https://www.youtube.com/live/abc',
    ));

    await tester.pumpWidget(h.wrap(ChannelPage(repo: h.channel, onOpenLive: () {})));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('مباشر الآن: '), findsOneWidget);
    expect(find.text('إنهاء البث'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(h.wrap(LivePage(channel: h.channel)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تغطية مباشرة من خانيونس'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await h.channel.endLive('live1');
    expect(h.channel.activeLives, isEmpty);
    await tearDownApp(tester);
  });

  testWidgets('Go-live form checks the link and publishes', (tester) async {
    final h = await setUpHarness(tester);
    const j = Journalist(name: 'مراسل', outlet: 'غزة الآن', phone: '0599', pressId: '', region: 'رفح');
    await h.channel.registerJournalist(j);
    await tester.pumpWidget(h.wrap(Scaffold(body: GoLiveSheet(repo: h.channel, journalist: j))));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), 'بث مباشر من رفح');
    await tester.enterText(find.byType(TextFormField).at(1), 'not a link');
    await tester.tap(find.text('انشر البث للمشتركين'));
    await tester.pump();
    expect(find.text('أدخل رابطاً كاملاً يبدأ بـ https://'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'https://www.youtube.com/live/xyz');
    await tester.tap(find.text('انشر البث للمشتركين'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.channel.activeLives.single.text, 'بث مباشر من رفح');
    expect(tester.takeException(), isNull);
    await tearDownApp(tester);
  });

  testWidgets('Radio page lists all stations', (tester) async {
    final h = await setUpHarness(tester);
    await tester.pumpWidget(h.wrap(const Scaffold(body: RadioPage())));
    await tester.pump();
    for (final s in radioStations.take(3)) {
      expect(find.text(s.name), findsOneWidget);
    }
    await scrollToEnd(tester, find.byType(ListView).first);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester);
  });

  testWidgets('Search, saved and updates pages render', (tester) async {
    final h = await setUpHarness(tester);
    h.news.toggleSaved(sampleArticles(3).first);
    for (final page in [const SearchPage(), const Scaffold(body: SavedPage()), const UpdatesPage(), const SourcesPage()]) {
      await tester.pumpWidget(h.wrap(page));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull, reason: '$page');
    }
    await tearDownApp(tester);
  });
}
