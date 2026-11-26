import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Opening screen: the logo spins in with a bounce and a glow, broadcast rings
/// pulse around it, the name slides up with a shine, a red "breaking" bar sweeps
/// in, and a short news jingle plays.
class SplashScreen extends StatefulWidget {
  final WidgetBuilder next;
  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _shine =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  final AudioPlayer _player = AudioPlayer(playerId: 'intro-jingle');
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
  late final Animation<double> _spin = Tween(begin: -0.6, end: 0.0)
      .animate(CurvedAnimation(parent: _intro, curve: const Interval(0, .5, curve: Curves.easeOutBack)));
  late final Animation<Offset> _bar = Tween(begin: const Offset(1.2, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: _intro, curve: const Interval(.7, 1, curve: Curves.easeOutCubic)));

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _pulseStart = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        _pulse.repeat();
        _shine.repeat();
      }
    });
    // Start the sound once the first frame is on screen, so it lines up with the logo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _playJingle());
    _timer = Timer(const Duration(milliseconds: 4200), _goNext);
  }

  Future<void> _playJingle() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
      await _player.setSource(AssetSource('sounds/news_intro.mp3'));
      await _player.resume();
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
    _shine.dispose();
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
                      child: RotationTransition(
                        turns: _spin,
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, child) => Container(
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
                                // Soft glow that breathes with the rings.
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: .10 + .18 * math.sin(math.pi * _pulse.value)),
                                  blurRadius: 40,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: child,
                          ),
                          child: Image.asset('assets/images/logo.png'),
                        ),
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
                    AnimatedBuilder(
                      animation: _shine,
                      builder: (_, child) => ShaderMask(
                        blendMode: BlendMode.srcATop,
                        shaderCallback: (r) => LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: const [Colors.white, Color(0xFFFFE9A8), Colors.white],
                          stops: [
                            (_shine.value - .2).clamp(0.0, 1.0),
                            _shine.value,
                            (_shine.value + .2).clamp(0.0, 1.0),
                          ],
                        ).createShader(r),
                        child: child,
                      ),
                      child: const Text('غزة الآن',
                          style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800)),
                    ),
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
                child: SlideTransition(
                  position: _bar,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        color: urgent,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: const Text('عاجل',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                      const Flexible(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text('أخبار غزة لحظة بلحظة • راديو • بث مباشر',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ]),
                  ),
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
