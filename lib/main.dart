import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ads.dart';
import 'app_shell.dart';
import 'channel/channel_repository.dart';
import 'news/news_repository.dart';
import 'splash_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final darkMode = ValueNotifier<bool>(prefs.getBool('dark') ?? false);
  darkMode.addListener(() => prefs.setBool('dark', darkMode.value));
  final news = NewsRepository(prefs);
  // Start downloading news while the splash animation plays.
  news.refresh();
  runApp(GazaNowApp(darkMode: darkMode, channel: LocalChannelRepository(prefs), news: news));
  // Ads start after the first frame so they never delay the app opening.
  AdService.instance.init();
}

class GazaNowApp extends StatelessWidget {
  final ValueNotifier<bool> darkMode;
  final ChannelRepository channel;
  final NewsRepository news;
  const GazaNowApp({super.key, required this.darkMode, required this.channel, required this.news});

  @override
  Widget build(BuildContext context) {
    // NewsScope sits above MaterialApp so every route (and hero flight) can reach it.
    return NewsScope(
      repo: news,
      child: ValueListenableBuilder<bool>(
        valueListenable: darkMode,
        builder: (context, dark, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'غزة الآن | Gaza Now',
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: SplashScreen(
            next: (_) => AppShell(darkMode: darkMode, channel: channel),
          ),
        ),
      ),
    );
  }
}
