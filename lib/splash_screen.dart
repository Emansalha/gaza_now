import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Opening screen: the logo pops in with a soft bounce, broadcast rings pulse
/// around it, the name slides up, and a short news jingle plays.
class SplashScreen extends StatefulWidget {
  final WidgetBuilder next;
  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;
  Timer? _pulseStart;
  bool _left = false;

  late final Animation<double> _logoScale =
      CurvedAnimation(parent: _intro, curve: const Interval(0, .55, curve: Curves.elasticOut));
  late final Animation<double> _logoFade =
      CurvedAnimation(parent: _intro, curve: const Interval(0, .2, curve: Curves.easeOut));
  late final Animation<double> _title =
      CurvedAnimation(parent: _intro, curve: const Interval(.42, .78, curve: Curves.easeOutCubic));
  late final Animation<double> _tag =
      CurvedAnimation(parent: _intro, curve: const Interval(.65, 1, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _pulseStart = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _pulse.repeat();
    });
    _playJingle();
    _timer = Timer(const Duration(milliseconds: 3600), _goNext);
  }

  Future<void> _playJingle() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(AssetSource('sounds/news_intro.mp3'), volume: .9);
    } catch (_) {
      // Sound is a nice-to-have; never block the app if audio fails.
    }
  }

  void _goNext() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 650),
      pageBuilder: (c, _, __) => widget.next(c),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseStart?.cancel();
    _intro.dispose();
    _pulse.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ink,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goNext, // tap to skip
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.2),
              radius: 1.1,
              colors: [teal, ink],
            ),
          ),
          child: SafeArea(
            child: Column(children: [
              const Spacer(flex: 3),
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(alignment: Alignment.center, children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => CustomPaint(
                      size: const Size(260, 260),
                      painter: _RingsPainter(_pulse.isAnimating ? _pulse.value : -1),
                    ),
                  ),
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .35),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Image.asset('assets/images/logo.png'),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: _title,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, .5), end: Offset.zero).animate(_title),
                  child: Column(children: [
                    Text('غزة الآن',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            )),
                    const SizedBox(height: 2),
                    const Text('GAZA NOW',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: Colors.white70,
                          letterSpacing: 6,
                          fontWeight: FontWeight.w700,
                        )),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _tag,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: urgent, borderRadius: BorderRadius.circular(30)),
                  child: const Text('أخبار عاجلة • تغطية مباشرة',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const Spacer(flex: 3),
              FadeTransition(
                opacity: _tag,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Expanding "broadcast" rings behind the logo.
class _RingsPainter extends CustomPainter {
  final double progress; // -1 = not started yet
  _RingsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0) return;
    final center = size.center(Offset.zero);
    const rings = 3;
    for (var i = 0; i < rings; i++) {
      final t = (progress + i / rings) % 1.0;
      final radius = 75 + t * (size.width / 2 - 75);
      final opacity = math.max(0.0, (1 - t)) * .45;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.progress != progress;
}
