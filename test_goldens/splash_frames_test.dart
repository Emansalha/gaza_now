import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaza_now/splash_screen.dart';
import 'package:gaza_now/theme.dart';

Future<void> loadFonts() async {
  final loader = FontLoader('Tajawal');
  for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/Tajawal-$w.ttf'));
  }
  await loader.load();
}

void main() {
  testWidgets('splash frames', (tester) async {
    await tester.runAsync(loadFonts);
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SplashScreen(playSound: false, next: (_) => const SizedBox()),
      ),
    ));
    // Let the logo image decode.
    await tester.runAsync(() async {
      final el = tester.element(find.byType(Image).first);
      await precacheImage(const AssetImage('assets/images/splash_logo.png'), el);
    });
    var now = 0;
    for (final ms in [250, 700, 1200, 1600, 2300, 3200]) {
      await tester.pump(Duration(milliseconds: ms - now));
      now = ms;
      await expectLater(find.byType(SplashScreen), matchesGoldenFile('frames/splash_$ms.png'));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
