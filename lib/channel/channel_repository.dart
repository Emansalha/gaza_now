import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'channel_models.dart';

/// Everything the UI needs from the channel. The app ships with a local
/// implementation (works offline, on one device). To make posts reach every
/// subscriber in real time, implement this interface with a backend such as
/// Cloud Firestore (`snapshots()` maps directly to [watchPosts]) and swap it
/// in `main.dart`. See README → "ربط القناة بخادم حقيقي".
abstract class ChannelRepository {
  Stream<List<ChannelPost>> watchPosts();
  List<ChannelPost> get posts;
  Future<void> publish(ChannelPost post);
  Future<void> deletePost(String id);

  bool get subscribed;
  int get subscriberCount;
  Future<void> setSubscribed(bool value);

  bool get muted;
  Future<void> setMuted(bool value);

  Journalist? get journalist;
  Future<void> registerJournalist(Journalist j);
  Future<void> signOutJournalist();
}

class LocalChannelRepository implements ChannelRepository {
  final SharedPreferences prefs;
  final _controller = StreamController<List<ChannelPost>>.broadcast();
  late List<ChannelPost> _posts = _load();

  LocalChannelRepository(this.prefs);

  static const _kPosts = 'channel_posts';
  static const _kSub = 'channel_subscribed';
  static const _kMuted = 'channel_muted';
  static const _kJournalist = 'channel_journalist';
  static const _baseSubscribers = 1240; // illustrative starting count

  List<ChannelPost> _load() {
    final raw = prefs.getString(_kPosts);
    if (raw == null) return _samplePosts();
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(ChannelPost.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return _samplePosts();
    }
  }

  Future<void> _save() async {
    await prefs.setString(_kPosts, jsonEncode(_posts.map((p) => p.toJson()).toList()));
    _controller.add(List.unmodifiable(_posts));
  }

  @override
  List<ChannelPost> get posts => List.unmodifiable(_posts);

  @override
  Stream<List<ChannelPost>> watchPosts() async* {
    yield posts;
    yield* _controller.stream;
  }

  @override
  Future<void> publish(ChannelPost post) async {
    _posts = [post, ..._posts];
    await _save();
  }

  @override
  Future<void> deletePost(String id) async {
    _posts = _posts.where((p) => p.id != id).toList();
    await _save();
  }

  @override
  bool get subscribed => prefs.getBool(_kSub) ?? false;

  @override
  int get subscriberCount => _baseSubscribers + (subscribed ? 1 : 0);

  @override
  Future<void> setSubscribed(bool value) async {
    await prefs.setBool(_kSub, value);
    _controller.add(posts);
  }

  @override
  bool get muted => prefs.getBool(_kMuted) ?? false;

  @override
  Future<void> setMuted(bool value) async {
    await prefs.setBool(_kMuted, value);
    _controller.add(posts);
  }

  @override
  Journalist? get journalist {
    final raw = prefs.getString(_kJournalist);
    if (raw == null) return null;
    try {
      return Journalist.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> registerJournalist(Journalist j) async {
    await prefs.setString(_kJournalist, jsonEncode(j.toJson()));
    _controller.add(posts);
  }

  @override
  Future<void> signOutJournalist() async {
    await prefs.remove(_kJournalist);
    _controller.add(posts);
  }

  static List<ChannelPost> _samplePosts() {
    final now = DateTime.now();
    return [
      ChannelPost(
        id: 's3',
        authorName: 'غرفة الأخبار',
        outlet: 'غزة الآن',
        text: 'مرحباً بكم في قناة غزة الآن 👋\nهنا تُنشر تحديثات المراسلين أولاً بأول. فعّل الإشعارات لتصلك الأخبار العاجلة فور نشرها.',
        region: 'قطاع غزة',
        createdAt: now.subtract(const Duration(minutes: 4)),
        verifiedAuthor: true,
        sample: true,
        views: 860,
      ),
      ChannelPost(
        id: 's2',
        authorName: 'مراسل تجريبي',
        outlet: 'غزة الآن',
        text: '(مثال توضيحي) تحديث ميداني من خانيونس: متابعة أوضاع مراكز الإيواء ونقاط توزيع المياه.',
        region: 'خانيونس',
        createdAt: now.subtract(const Duration(minutes: 26)),
        verifiedAuthor: true,
        sample: true,
        views: 1430,
      ),
      ChannelPost(
        id: 's1',
        authorName: 'مراسل تجريبي',
        outlet: 'غزة الآن',
        text: '(مثال توضيحي) عاجل: تحديث من شمال غزة، التفاصيل تباعاً.',
        region: 'شمال غزة',
        urgent: true,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 5)),
        verifiedAuthor: true,
        sample: true,
        views: 2210,
      ),
    ];
  }

  void dispose() => _controller.close();
}
