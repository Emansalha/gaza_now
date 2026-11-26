import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import '../theme.dart';

bool get _adsSupported =>
    AdService.enabled && AppConfig.adsEnabled && !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Starts AdMob after asking for consent where the law requires it (EU/UK).
class AdService {
  AdService._();
  static final instance = AdService._();

  /// Switched off in widget tests (no ads SDK there).
  static bool enabled = true;

  bool _ready = false;
  int _opens = 0;
  DateTime _lastInterstitial = DateTime.fromMillisecondsSinceEpoch(0);
  InterstitialAd? _interstitial;

  Future<void> init() async {
    if (!_adsSupported) return;
    final consentDone = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!consentDone.isCompleted) consentDone.complete();
      }),
      (_) {
        if (!consentDone.isCompleted) consentDone.complete();
      },
    );
    await consentDone.future.timeout(const Duration(seconds: 8), onTimeout: () {});
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    _ready = true;
    _loadInterstitial();
  }

  void _loadInterstitial() {
    if (!_ready) return;
    InterstitialAd.load(
      adUnitId: AppConfig.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Call when the reader opens an article. Shows ad 3 occasionally.
  void onArticleOpened() {
    if (!_ready) return;
    _opens++;
    final ad = _interstitial;
    final gapOk = DateTime.now().difference(_lastInterstitial) >= AppConfig.interstitialMinGap;
    if (ad == null || !gapOk || _opens % AppConfig.interstitialEvery != 0) return;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadInterstitial();
      },
    );
    _interstitial = null;
    _lastInterstitial = DateTime.now();
    ad.show();
  }

  bool get ready => _ready;
}

/// Ad 1 (home) and ad 2 (article): a banner that hides itself if nothing loads.
class BannerAdBox extends StatefulWidget {
  final String adUnitId;
  final AdSize size;
  final String label;
  const BannerAdBox({super.key, required this.adUnitId, this.size = AdSize.banner, this.label = 'إعلان'});

  /// Ad 1: banner shown in the home feed.
  factory BannerAdBox.home() => BannerAdBox(adUnitId: AppConfig.homeBannerId, size: AdSize.largeBanner);

  /// Ad 2: medium rectangle shown under the article text.
  factory BannerAdBox.article() => BannerAdBox(adUnitId: AppConfig.articleAdId, size: AdSize.mediumRectangle);

  @override
  State<BannerAdBox> createState() => _BannerAdBoxState();
}

class _BannerAdBoxState extends State<BannerAdBox> {
  BannerAd? _ad;
  bool _loaded = false;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (!_adsSupported) return;
    if (!AdService.instance.ready) {
      // Ads SDK may still be starting (consent dialog); try again shortly.
      _retry = Timer(const Duration(seconds: 3), _load);
      return;
    }
    _ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      decoration: BoxDecoration(color: context.surfaceCard, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text(widget.label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          width: widget.size.width.toDouble(),
          height: widget.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ]),
    );
  }
}
