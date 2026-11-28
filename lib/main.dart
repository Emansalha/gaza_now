import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ads.dart';
import 'app_shell.dart';
import 'channel/channel_repository.dart';
import 'news/news_repository.dart';
import 'radio/radio.dart';
import 'splash_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // In a release build a broken widget would show as a grey box; show nothing instead
  // so one bad story never spoils the list. Errors are still printed to the log.
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const SizedBox.shrink();
  }
  debugPrint('GazaNow: main() started');
  final prefs = await SharedPreferences.getInstance();
  final darkMode = ValueNotifier<bool>(prefs.getBool('dark') ?? false);
  darkMode.addListener(() => prefs.setBool('dark', darkMode.value));
  // Load the intro music now so it plays with the logo, not after it.
  final intro = await prepareIntroSound().timeout(const Duration(seconds: 2), onTimeout: () => null);
  debugPrint('GazaNow: starting (intro sound ${intro == null ? 'off' : 'ready'})');
  final news = NewsRepository(prefs);
  // Start downloading news while the splash animation plays.
  news.refresh();
  runApp(GazaNowApp(darkMode: darkMode, channel: LocalChannelRepository(prefs), news: news, radio: RadioService(), intro: intro));
  // Ads start after the first frame so they never delay the app opening.
  AdService.instance.init();
}

class GazaNowApp extends StatelessWidget {
  final ValueNotifier<bool> darkMode;
  final ChannelRepository channel;
  final NewsRepository news;
  final RadioService radio;
  final AudioPlayer? intro;
  const GazaNowApp({
    super.key,
    required this.darkMode,
    required this.channel,
    required this.news,
    required this.radio,
    this.intro,
  });

  @override
  Widget build(BuildContext context) {
    // NewsScope sits above MaterialApp so every route (and hero flight) can reach it.
    return NewsScope(
      repo: news,
      child: RadioScope(
        radio: radio,
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
          // Respect the phone's text size, but cap it so cards keep their layout.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3)),
              child: child!,
            );
          },
          home: SplashScreen(
            introPlayer: intro,
            next: (_) => AppShell(darkMode: darkMode, channel: channel),
          ),
        ),
        ),
      ),
    );
  }
}
