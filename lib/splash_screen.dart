import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Loads the intro music before the first frame so it can start with the logo.
/// Returns null if audio is unavailable (it never blocks the app for long).
Future<AudioPlayer?> prepareIntroSound() async {
  AudioPlayer? p;
  Future<AudioPlayer?> load() async {
    p = AudioPlayer(playerId: 'intro-jingle');
    await p!.setReleaseMode(ReleaseMode.stop);
    await p!.setVolume(1.0);
    await p!.setSource(AssetSource('sounds/news_intro.mp3'));
    return p;
  }

  try {
    // Every step together is capped: on some devices the audio plugin never answers,
    // and the app must not wait on the launch screen for it.
    return await load().timeout(const Duration(milliseconds: 1500));
  } catch (e) {
    debugPrint('GazaNow: intro sound not ready ($e), starting without it');
    p?.dispose().catchError((_) {});
    return null;
  }
}

/// Opening screen: the logo spins in with a bounce and a glow, broadcast rings
/// pulse around it, the name slides up with a shine, a red "breaking" bar sweeps
/// in, and a short news jingle plays.
class SplashScreen extends StatefulWidget {
  final WidgetBuilder next;

  /// Off in screenshots/tests, where there is no audio plugin.
  final bool playSound;

  /// The intro music, already loaded before the app appears (see [prepareIntroSound]).
  final AudioPlayer? introPlayer;
  const SplashScreen({super.key, required this.next, this.playSound = true, this.introPlayer});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  /// Light streaks orbiting the logo (start at once, keep going).
  late final AnimationController _orbit =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  /// A band of light that sweeps across the logo after it lands.
  late final AnimationController _sheen =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  Timer? _sheenStart;

  /// The name opens from the centre outwards.
  late final Animation<double> _reveal =
      CurvedAnimation(parent: _intro, curve: const Interval(.5, .85, curve: Curves.easeOutCubic));

  late final AnimationController _shine =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  AudioPlayer? _player;
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
  /// Two full turns around the logo's own vertical axis, slowing to a stop (like a coin).
  late final Animation<double> _spin = Tween(begin: 2.0, end: 0.0)
      .animate(CurvedAnimation(parent: _intro, curve: const Interval(0, .62, curve: Curves.easeOutCubic)));
  late final Animation<Offset> _bar = Tween(begin: const Offset(1.2, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: _intro, curve: const Interval(.7, 1, curve: Curves.easeOutCubic)));

  bool _started = false;
  final DateTime _shownAt = DateTime.now();
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _doneSub;

  @override
  void initState() {
    super.initState();
    final p = widget.introPlayer;
    if (p == null || !widget.playSound) {
      _startAnimations();
      _timer = Timer(const Duration(milliseconds: 4200), _goNext);
      return;
    }
    _player = p;
    // The animation starts the moment the sound really starts, so the hit lands
    // exactly when the logo stops spinning.
    _stateSub = p.onPlayerStateChanged.listen((s) {
      if (s == PlayerState.playing) _startAnimations();
    });
    // Leave the logo only after the music has finished: it never plays over the news.
    _doneSub = p.onPlayerComplete.listen((_) => _goNext());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await p.resume();
      } catch (_) {
        _startAnimations();
      }
    });
    // Safety nets: start anyway if the sound is slow, and never stay longer than 7 s.
    Timer(const Duration(milliseconds: 900), _startAnimations);
    _timer = Timer(const Duration(seconds: 7), _goNext);
  }

  void _startAnimations() {
    if (_started || !mounted) return;
    _started = true;
    _intro.forward();
    _sheenStart = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _sheen.repeat(period: const Duration(milliseconds: 2000));
    });
    _pulseStart = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        _pulse.repeat();
        _shine.repeat();
      }
    });
    // Without sound (or if it never reports completion) move on after the animation.
    if (widget.introPlayer == null) return;
    Timer(const Duration(milliseconds: 5200), _goNext);
  }

  void _goNext() {
    if (_left || !mounted) return;
    // Tapped/finished too early? Keep the logo up for at least 3.5 s.
    final shown = DateTime.now().difference(_shownAt);
    if (shown < const Duration(milliseconds: 3500)) {
      Timer(const Duration(milliseconds: 3500) - shown, _goNext);
      return;
    }
    _left = true;
    _player?.stop();
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
    _orbit.dispose();
    _sheen.dispose();
    _sheenStart?.cancel();
    _stateSub?.cancel();
    _doneSub?.cancel();
    _player?.stop();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C33),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goNext, // tap to skip
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.2),
              radius: 1.1,
              colors: [Color(0xFF103A76), Color(0xFF0A0C33)],
            ),
          ),
          child: SafeArea(
            child: Column(children: [
              const Spacer(flex: 3),
              SizedBox(
                width: 300,
                height: 300,
                child: Stack(alignment: Alignment.center, children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => CustomPaint(
                      size: const Size(300, 300),
                      painter: _RingsPainter(_pulse.isAnimating ? _pulse.value : -1),
                    ),
                  ),
                  FadeTransition(
                    opacity: _logoFade,
                    child: AnimatedBuilder(
                      animation: _orbit,
                      builder: (_, __) => CustomPaint(
                        size: const Size(300, 300),
                        painter: _OrbitPainter(_orbit.value),
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: AnimatedBuilder(
                        animation: _spin,
                        builder: (_, child) => Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012) // perspective
                            ..rotateY(2 * math.pi * _spin.value),
                          child: child,
                        ),
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, child) => Container(
                            width: 190,
                            height: 190,
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(34),
                            child: AnimatedBuilder(
                              animation: _sheen,
                              builder: (_, child) => ShaderMask(
                                blendMode: BlendMode.srcATop,
                                shaderCallback: (r) {
                                  final v = _sheen.value * 1.6 - .3; // travels past both corners
                                  return LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: _sheen.isAnimating ? .45 : 0),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                    stops: [(v - .12).clamp(0.0, 1.0), v.clamp(0.0, 1.0), (v + .12).clamp(0.0, 1.0)],
                                  ).createShader(r);
                                },
                                child: child,
                              ),
                              child: Image.asset('assets/images/splash_logo.png', fit: BoxFit.cover),
                            ),
                          ),
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
                      // Opens from the centre outwards.
                      child: AnimatedBuilder(
                        animation: _reveal,
                        builder: (_, child) => ClipRect(
                          child: Align(alignment: Alignment.center, widthFactor: _reveal.value, child: child),
                        ),
                        child: const Text('غزة الآن',
                            style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    // A light line that draws itself under the name.
                    AnimatedBuilder(
                      animation: _reveal,
                      builder: (_, __) => Container(
                        width: 200 * _reveal.value,
                        height: 3,
                        margin: const EdgeInsets.only(top: 2, bottom: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: const LinearGradient(colors: [
                            Color(0x00E53935),
                            urgent,
                            Colors.white,
                            urgent,
                            Color(0x00E53935),
                          ]),
                        ),
                      ),
                    ),
                    // Letters spread apart as the name settles.
                    AnimatedBuilder(
                      animation: _reveal,
                      builder: (_, __) => Text('GAZA NOW',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .75),
                            letterSpacing: 1 + 8 * _reveal.value,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
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
                          child: Text('أخبار غزة لحظة بلحظة',
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
      final radius = 100 + t * (size.width / 2 - 100);
      final opacity = math.max(0.0, (1 - t)) * .25;
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

/// Two comets of light (blue and red) chasing each other around the logo on a faint track.
class _OrbitPainter extends CustomPainter {
  final double t; // 0..1, one full turn
  _OrbitPainter(this.t);

  void _comet(Canvas canvas, Offset c, double r, double angle, Color color, double width) {
    final rect = Rect.fromCircle(center: c, radius: r);
    // Tail: transparent behind, full colour at the head.
    final tail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0), color.withValues(alpha: 0), color.withValues(alpha: .9)],
        stops: const [0, .62, 1],
        transform: GradientRotation(angle),
      ).createShader(rect);
    canvas.drawArc(rect, angle + 2 * math.pi * .62, 2 * math.pi * .38, false, tail);
    // Glowing head.
    final head = c + Offset(math.cos(angle + 2 * math.pi), math.sin(angle + 2 * math.pi)) * r;
    canvas.drawCircle(head, width * 2.2, Paint()..color = color.withValues(alpha: .35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(head, width * .9, Paint()..color = Colors.white);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      142,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: .12),
    );
    _comet(canvas, c, 142, 2 * math.pi * t, const Color(0xFF6EC6FF), 3);
    _comet(canvas, c, 142, 2 * math.pi * t + math.pi, const Color(0xFFE53935), 3);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}
