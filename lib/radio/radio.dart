import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class RadioStation {
  final String id, name, description, url;
  final Color color;
  const RadioStation(this.id, this.name, this.description, this.url, this.color);
}

/// Live news radio streams, each checked to answer with audio (26 Nov 2026).
const radioStations = <RadioStation>[
  RadioStation('aljazeera', 'الجزيرة', 'صوت قناة الجزيرة الإخبارية مباشرة',
      'https://live-hls-audio-web-aja.getaj.net/VOICE-AJA/index.m3u8', Color(0xFFC8962B)),
  RadioStation('bbc', 'بي بي سي عربي', 'إذاعة بي بي سي باللغة العربية',
      'https://stream.live.vc.bbcmedia.co.uk/bbc_arabic_radio', Color(0xFFB80000)),
  RadioStation('mcd', 'مونت كارلو الدولية', 'أخبار وبرامج حوارية من باريس',
      'https://montecarlodoualiya128k.ice.infomaniak.ch/mc-doualiya.mp3', Color(0xFF0A6EB4)),
  RadioStation('alaraby', 'راديو العربي', 'إذاعة التلفزيون العربي الإخبارية',
      'https://l3.itworkscdn.net/alarabyradiolive/alarabyradio_audio/icecast.audio', Color(0xFF8E2C2C)),
  RadioStation('alarabiya', 'العربية FM', 'إذاعة قناة العربية',
      'https://fm.alarabiya.net/fm/myStream/playlist.m3u8', Color(0xFF1B4F9C)),
  RadioStation('raya', 'راية FM', 'إذاعة فلسطينية إخبارية من رام الله',
      'https://rstream.hadara.ps/proxy/raya/stream', Color(0xFF1E7B4F)),
  RadioStation('ajyal', 'أجيال', 'شبكة أجيال الإذاعية الفلسطينية',
      'https://streamer.mada.ps:8208/ajyal', Color(0xFF2B8C8C)),
];

/// Plays one station at a time, keeps playing while the reader moves around the app.
class RadioService extends ChangeNotifier {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _sub;
  Timer? _timeout;

  RadioStation? current;
  bool playing = false;
  bool buffering = false;
  String? error;

  AudioPlayer get _p {
    final p = _player ??= AudioPlayer(playerId: 'news-radio');
    _sub ??= p.onPlayerStateChanged.listen((s) {
      playing = s == PlayerState.playing;
      if (playing) {
        buffering = false;
        _timeout?.cancel();
      }
      notifyListeners();
    });
    return p;
  }

  Future<void> play(RadioStation s) async {
    current = s;
    buffering = true;
    playing = false;
    error = null;
    notifyListeners();
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 25), () {
      if (buffering) _fail(s);
    });
    try {
      final p = _p;
      await p.stop();
      await p.setReleaseMode(ReleaseMode.stop);
      // Always join the live edge of the stream.
      await p.play(UrlSource(s.url));
    } catch (_) {
      _fail(s);
    }
  }

  void _fail(RadioStation s) {
    buffering = false;
    playing = false;
    error = 'تعذّر تشغيل ${s.name}. تحقق من الإنترنت أو جرّب محطة أخرى.';
    notifyListeners();
  }

  Future<void> toggle() async {
    final s = current;
    if (s == null) return;
    if (playing || buffering) {
      buffering = false;
      _timeout?.cancel();
      await _player?.stop();
      playing = false;
      notifyListeners();
    } else {
      await play(s);
    }
  }

  Future<void> close() async {
    _timeout?.cancel();
    await _player?.stop();
    current = null;
    playing = false;
    buffering = false;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _sub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}

class RadioScope extends InheritedNotifier<RadioService> {
  const RadioScope({super.key, required RadioService radio, required super.child}) : super(notifier: radio);
  static RadioService of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RadioScope>()!.notifier!;
}

class RadioPage extends StatelessWidget {
  const RadioPage({super.key});

  @override
  Widget build(BuildContext context) {
    final radio = RadioScope.of(context);
    final cur = radio.current;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cur?.color ?? ink, Color.lerp(cur?.color ?? teal, ink, .6)!],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('راديو الأخبار', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(cur?.name ?? 'اختر محطة',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                cur == null
                    ? 'استمع للأخبار مباشرة أثناء تصفح التطبيق'
                    : radio.buffering
                        ? 'جارٍ الاتصال بالبث…'
                        : radio.playing
                            ? 'على الهواء الآن'
                            : 'متوقف',
                style: const TextStyle(color: Colors.white),
              ),
              if (radio.playing) ...[const SizedBox(height: 12), const Equalizer(color: Colors.white)],
            ]),
          ),
          if (cur != null)
            IconButton.filled(
              iconSize: 40,
              style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: ink),
              onPressed: radio.toggle,
              icon: radio.buffering
                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: ink))
                  : Icon(radio.playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
            ),
        ]),
      ),
      if (radio.error != null) ...[
        const SizedBox(height: 10),
        Text(radio.error!, style: const TextStyle(color: urgent, fontWeight: FontWeight.w700)),
      ],
      const SizedBox(height: 18),
      Text('المحطات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.titleColor)),
      const SizedBox(height: 10),
      for (final s in radioStations)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            onTap: () => cur?.id == s.id ? radio.toggle() : radio.play(s),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: s.color,
              child: const Icon(Icons.radio, color: Colors.white),
            ),
            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            subtitle: Text(s.description),
            trailing: cur?.id == s.id && radio.playing
                ? Equalizer(color: s.color)
                : Icon(Icons.play_circle_fill, color: s.color, size: 34),
          ),
        ),
      const SizedBox(height: 6),
      Text(
        'البث يُشغَّل من الروابط الرسمية العامة لكل محطة. يستمر الصوت أثناء تنقلك داخل التطبيق.',
        style: TextStyle(fontSize: 12, color: context.titleColor.withValues(alpha: .6), height: 1.5),
      ),
    ]);
  }
}

/// Compact player that stays above the bottom bar while a station is on.
class MiniPlayer extends StatelessWidget {
  final VoidCallback onOpen;
  const MiniPlayer({super.key, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final radio = RadioScope.of(context);
    final s = radio.current;
    if (s == null) return const SizedBox.shrink();
    return Material(
      color: Color.lerp(s.color, ink, .35),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            const Icon(Icons.radio, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                Text(
                  radio.buffering ? 'جارٍ الاتصال…' : (radio.playing ? 'مباشر' : (radio.error != null ? 'تعذّر التشغيل' : 'متوقف')),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ]),
            ),
            if (radio.playing) const Padding(padding: EdgeInsets.only(left: 8), child: Equalizer(color: Colors.white)),
            IconButton(
              color: Colors.white,
              onPressed: radio.toggle,
              icon: Icon(radio.playing || radio.buffering ? Icons.stop_rounded : Icons.play_arrow_rounded),
            ),
            IconButton(color: Colors.white70, onPressed: radio.close, icon: const Icon(Icons.close)),
          ]),
        ),
      ),
    );
  }
}

/// Four bouncing bars that show sound is playing.
class Equalizer extends StatefulWidget {
  final Color color;
  const Equalizer({super.key, required this.color});
  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 26,
        height: 20,
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 4,
                  height: 4 + 16 * (0.5 + 0.5 * math.sin(2 * math.pi * (c.value + i * .23))).abs(),
                  decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
                ),
            ],
          ),
        ),
      );
}
