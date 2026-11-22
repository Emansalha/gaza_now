import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'channel/channel_repository.dart';
import 'home.dart';
import 'splash_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final darkMode = ValueNotifier<bool>(prefs.getBool('dark') ?? false);
  darkMode.addListener(() => prefs.setBool('dark', darkMode.value));
  runApp(GazaNowApp(prefs: prefs, darkMode: darkMode, channel: LocalChannelRepository(prefs)));
}

class GazaNowApp extends StatelessWidget {
  final SharedPreferences prefs;
  final ValueNotifier<bool> darkMode;
  final ChannelRepository channel;
  const GazaNowApp({super.key, required this.prefs, required this.darkMode, required this.channel});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkMode,
      builder: (context, dark, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'غزة الآن | Gaza Now',
        // Arabic locale makes every screen (including pushed pages) right-to-left.
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
          next: (_) => HomeShell(prefs: prefs, darkMode: darkMode, channel: channel),
        ),
      ),
    );
  }
}
