import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'news_models.dart';
import 'rss_parser.dart';

/// Loads news from the trusted outlets, caches it for offline use and keeps
/// the reader's saved stories and source choices.
class NewsRepository extends ChangeNotifier {
  final SharedPreferences prefs;
  final http.Client _client;
  NewsRepository(this.prefs, {http.Client? client}) : _client = client ?? http.Client() {
    _restore();
  }

  static const _kCache = 'news_cache_v1';
  static const _kSaved = 'news_saved_v1';
  static const _kEnabled = 'news_sources_enabled_v1';
  static const _kOg = 'news_og_v1';
  static const _headers = {'User-Agent': 'Mozilla/5.0 (Linux; Android 14) GazaNow/1.2'};

  List<Article> _items = [];
  bool loading = false;
  DateTime? lastUpdated;
  Set<String> failedSources = {};
  late Set<String> enabledSources;
  final Map<String, Article> _saved = {};
  final Map<String, String> _ogImages = {};
  final Map<String, Future<String?>> _ogPending = {};

  // ---------- reading ----------
  List<Article> get all => _items.where((a) => enabledSources.contains(a.sourceId)).toList();
  List<Article> get gaza => all.where((a) => a.isGaza).toList();
  List<Article> forGovernorate(String g) => all.where((a) => a.matchesGovernorate(g)).toList();
  List<Article> search(String q) {
    final s = q.trim();
    if (s.isEmpty) return all;
    return all.where((a) => '${a.title} ${a.summary} ${a.source.name}'.contains(s)).toList();
  }

  bool get hasData => _items.isNotEmpty;

  /// Best image we know for [a]: from the feed, or one found on the article page.
  String? imageFor(Article a) => a.imageUrl ?? _ogImages[a.link];

  // ---------- network ----------
  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    final failed = <String>{};

    // 1) Our own API: one fast request, photos already resolved.
    final api = await _fetchOwnApi();
    if (api != null && api.articles.isNotEmpty) {
      _apply(api.articles, api.failed);
      return;
    }

    // 2) Fallback: read every outlet's RSS directly.
    final results = await Future.wait(newsSources.map((s) async {
      try {
        final r = await _client.get(Uri.parse(s.feedUrl), headers: _headers).timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
        final list = parseFeed(utf8.decode(r.bodyBytes, allowMalformed: true), s);
        if (list.isEmpty) throw Exception('empty');
        return list;
      } catch (_) {
        failed.add(s.id);
        return <Article>[];
      }
    }));

    final fresh = results.expand((e) => e).toList();
    if (AppConfig.newsDataApiKey.isNotEmpty) {
      try {
        fresh.addAll(await _fetchNewsData());
      } catch (_) {
        failed.add(apiSource.id);
      }
    }
    _apply(fresh, failed);
  }

  void _apply(List<Article> fresh, Set<String> failed) {
    if (fresh.isNotEmpty) {
      final byLink = <String, Article>{for (final a in fresh) a.link: a};
      // Keep older cached items from sources that failed this time.
      for (final a in _items) {
        if (failed.contains(a.sourceId)) byLink.putIfAbsent(a.link, () => a);
      }
      _items = byLink.values.toList()..sort((a, b) => b.published.compareTo(a.published));
      if (_items.length > 400) _items = _items.sublist(0, 400);
      lastUpdated = DateTime.now();
      _persistCache();
    }
    failedSources = failed;
    loading = false;
    notifyListeners();
  }

  Future<({List<Article> articles, Set<String> failed})?> _fetchOwnApi() async {
    if (AppConfig.newsApiUrl.isEmpty) return null;
    try {
      final r = await _client
          .get(Uri.parse(AppConfig.newsApiUrl), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final generated = DateTime.tryParse(body['generated'] as String? ?? '');
      // Ignore a stale API (e.g. the workflow stopped) and use RSS instead.
      if (generated == null || DateTime.now().toUtc().difference(generated) > const Duration(hours: 6)) return null;
      final list = (body['articles'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Article.fromJson)
          .toList();
      final failed = <String>{
        for (final s in (body['sources'] as List? ?? const []).whereType<Map<String, dynamic>>())
          if (s['ok'] != true) s['id'] as String,
      };
      return (articles: list, failed: failed);
    } catch (_) {
      return null;
    }
  }

  /// News through the NewsData.io REST API (Arabic, with photos).
  Future<List<Article>> _fetchNewsData() async {
    final uri = Uri.https('newsdata.io', '/api/1/latest', {
      'apikey': AppConfig.newsDataApiKey,
      'language': 'ar',
      'q': 'غزة OR فلسطين OR رفح OR خانيونس',
      'removeduplicate': '1',
    });
    final r = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? const [];
    return [
      for (final raw in results.whereType<Map<String, dynamic>>())
        if ((raw['title'] as String?)?.isNotEmpty == true && (raw['link'] as String?)?.startsWith('http') == true)
          Article(
            link: raw['link'] as String,
            title: cleanText(raw['title'] as String),
            summary: cleanText((raw['description'] as String?) ?? ''),
            sourceId: apiSource.id,
            publisher: raw['source_name'] as String? ?? raw['source_id'] as String?,
            imageUrl: (raw['image_url'] as String?)?.startsWith('http') == true ? raw['image_url'] as String : null,
            published: DateTime.tryParse('${raw['pubDate'] ?? ''}Z'.replaceFirst(' ', 'T')) ?? DateTime.now(),
            category: (raw['category'] is List && (raw['category'] as List).isNotEmpty)
                ? '${(raw['category'] as List).first}'
                : null,
          ),
    ];
  }

  /// Sources the reader can choose from (the API appears only when a key is set).
  static List<NewsSource> get availableSources =>
      [...newsSources, if (AppConfig.newsDataApiKey.isNotEmpty) apiSource];

  /// Finds the article's main photo (og:image) when the feed has none.
  Future<String?> resolveImage(Article a) {
    final known = imageFor(a);
    if (known != null) return Future.value(known);
    return _ogPending.putIfAbsent(a.link, () async {
      try {
        final r = await _client.get(Uri.parse(a.link), headers: _headers).timeout(const Duration(seconds: 12));
        if (r.statusCode != 200) return null;
        final html = utf8.decode(r.bodyBytes, allowMalformed: true);
        final m = RegExp(r'''<meta[^>]+property=["']og:image["'][^>]*content=["']([^"']+)["']''').firstMatch(html) ??
            RegExp(r'''<meta[^>]+content=["']([^"']+)["'][^>]*property=["']og:image["']''').firstMatch(html);
        final url = m?.group(1)?.replaceAll('&amp;', '&');
        // Skip generic site-wide share images.
        if (url == null || url.contains('social-preview') || url.contains('logo')) return null;
        _ogImages[a.link] = url;
        _persistOg();
        return url;
      } catch (_) {
        return null;
      }
    });
  }

  // ---------- saved ----------
  bool isSaved(Article a) => _saved.containsKey(a.link);
  List<Article> get saved => _saved.values.toList()..sort((a, b) => b.published.compareTo(a.published));

  void toggleSaved(Article a) {
    if (_saved.remove(a.link) == null) _saved[a.link] = a.copyWith(imageUrl: imageFor(a));
    prefs.setString(_kSaved, jsonEncode(_saved.values.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  // ---------- sources ----------
  void setSourceEnabled(String id, bool on) {
    if (on) {
      enabledSources.add(id);
    } else if (enabledSources.length > 1) {
      enabledSources.remove(id);
    }
    prefs.setStringList(_kEnabled, enabledSources.toList());
    notifyListeners();
  }

  // ---------- persistence ----------
  void _restore() {
    enabledSources = (prefs.getStringList(_kEnabled) ?? availableSources.map((s) => s.id).toList()).toSet();
    // Stories the server pulled from NewsData.io arrive with sourceId "api".
    if (prefs.getStringList(_kEnabled) == null) enabledSources.add(apiSource.id);
    _items = _decodeList(prefs.getString(_kCache));
    for (final a in _decodeList(prefs.getString(_kSaved))) {
      _saved[a.link] = a;
    }
    try {
      final og = prefs.getString(_kOg);
      if (og != null) _ogImages.addAll((jsonDecode(og) as Map).cast<String, String>());
    } catch (_) {}
    final ts = prefs.getString('${_kCache}_ts');
    lastUpdated = ts == null ? null : DateTime.tryParse(ts);
  }

  List<Article> _decodeList(String? raw) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(Article.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  void _persistCache() {
    prefs.setString(_kCache, jsonEncode(_items.take(200).map((e) => e.toJson()).toList()));
    prefs.setString('${_kCache}_ts', DateTime.now().toIso8601String());
  }

  Timer? _ogSave;
  void _persistOg() {
    _ogSave?.cancel();
    _ogSave = Timer(const Duration(seconds: 2), () {
      final entries = _ogImages.entries.toList();
      final keep = entries.length > 300 ? entries.sublist(entries.length - 300) : entries;
      prefs.setString(_kOg, jsonEncode(Map.fromEntries(keep)));
    });
  }
}

/// Makes the repository available to every widget below it.
class NewsScope extends InheritedNotifier<NewsRepository> {
  const NewsScope({super.key, required NewsRepository repo, required super.child}) : super(notifier: repo);

  /// Listens: rebuilds the caller when news changes.
  static NewsRepository of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NewsScope>()!.notifier!;

  /// Reads once without listening (for callbacks).
  static NewsRepository read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NewsScope>()!.notifier!;
}
