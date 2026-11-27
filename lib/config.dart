// No io Platform checks here: they throw in the browser (Chrome), which broke the feed and
// the story page there. defaultTargetPlatform works everywhere.
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

/// Everything you need to change before publishing lives here.
///
/// Values can also be passed at build time, for example:
///   flutter build appbundle \
///     --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/YYYY \
///     --dart-define=NEWSDATA_API_KEY=pub_XXXX
class AppConfig {
  // ---------------------------------------------------------------- Ads
  // Google's official TEST ad units (safe to use while developing).
  // Replace them with your own AdMob units before release, or you will not be paid.
  static const _bannerAndroid = String.fromEnvironment('ADMOB_BANNER_ANDROID',
      defaultValue: 'ca-app-pub-3940256099942544/6300978111');
  static const _bannerIos = String.fromEnvironment('ADMOB_BANNER_IOS',
      defaultValue: 'ca-app-pub-3940256099942544/2934735716');
  static const _articleAndroid = String.fromEnvironment('ADMOB_ARTICLE_ANDROID',
      defaultValue: 'ca-app-pub-3940256099942544/6300978111');
  static const _articleIos = String.fromEnvironment('ADMOB_ARTICLE_IOS',
      defaultValue: 'ca-app-pub-3940256099942544/2934735716');
  static const _interstitialAndroid = String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID',
      defaultValue: 'ca-app-pub-3940256099942544/1033173712');
  static const _interstitialIos = String.fromEnvironment('ADMOB_INTERSTITIAL_IOS',
      defaultValue: 'ca-app-pub-3940256099942544/4411468910');

  /// Ad 1: banner on the home feed.
  static String get homeBannerId => _isIos ? _bannerIos : _bannerAndroid;

  /// Ad 2: medium rectangle under each article.
  static String get articleAdId => _isIos ? _articleIos : _articleAndroid;

  /// Ad 3: full-screen ad, shown at most once every [interstitialEvery] article
  /// opens and never more often than [interstitialMinGap].
  static String get interstitialId => _isIos ? _interstitialIos : _interstitialAndroid;
  static const interstitialEvery = 5;
  static const interstitialMinGap = Duration(minutes: 3);

  static const adsEnabled = bool.fromEnvironment('ADS_ENABLED', defaultValue: true);

  // ---------------------------------------------------------------- News API
  /// The app's own news API: a JSON file rebuilt every 30 minutes by the
  /// "News API" GitHub workflow from the trusted outlets (with photos).
  /// If it can't be reached the app reads the outlets' RSS feeds directly.
  static const newsApiUrl = String.fromEnvironment('NEWS_API_URL',
      defaultValue: 'https://raw.githubusercontent.com/Emansalha/gaza_now/data/news.json');

  /// Free key from https://newsdata.io (Arabic news with photos).
  /// Leave empty to use only the RSS sources.
  static const newsDataApiKey = String.fromEnvironment('NEWSDATA_API_KEY');

  // ---------------------------------------------------------------- About
  static const privacyContactEmail =
      String.fromEnvironment('CONTACT_EMAIL', defaultValue: 'https://github.com/Emansalha/gaza_now/issues');
}
